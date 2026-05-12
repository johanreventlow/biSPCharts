# ==============================================================================
# test-upload-race-state-derived.R
# ==============================================================================
# Regression-tests for upload-race-bug (Cycle 10, 2026-05-12).
#
# Bug: SPC-plot viste empty-state efter ny data-upload indtil bruger åbnede
# "Tildel kolonner"-modal. Race-condition mellem auto-detect (skriver til
# app_state$columns$mappings) og throttled ui_sync (250ms før input$<col>
# opdateres på klient). column_config læste input direkte via manual_config()
# → plot renderede med stale input fra forrige session.
#
# Fix: column_config skifter primær-kilde fra input$<col> til
# app_state$columns$mappings$<col> via chart_config_from_state().
#
# Reference: docs/reviews/10-upload-race.md
# ==============================================================================

library(testthat)

# ============================================================================
# SUITE 1: chart_config_from_state() — pure function kontrakt
# ============================================================================

test_that("state-mappings vinder over stale input-værdier", {
  # Stale input fra forrige session (kolonnenavne ej i nyt data)
  stale_input <- list(
    x_col = "StaleDato",
    y_col = "StaleTal",
    n_col = NULL
  )

  # Frisk autodetect-result (mappings er allerede skrevet via transition)
  state_mappings <- list(
    x_column = "Uge",
    y_column = "Værdi",
    n_column = NULL
  )

  autodetect_result <- structure(
    list(x_col = "Uge", y_col = "Værdi", n_col = NULL),
    class = "AutodetectResult"
  )

  cfg <- chart_config_from_state(
    state_mappings = state_mappings,
    autodetect = autodetect_result,
    chart_type = "run",
    input_overrides = stale_input
  )

  expect_s3_class(cfg, "VisualizationConfig")
  expect_equal(cfg$x_col, "Uge")
  expect_equal(cfg$y_col, "Værdi")
  expect_equal(cfg$source, "manual") # state-mappings sendes som user_overrides
})

test_that("state-mappings overrider input selv når input er ikke-tom", {
  cfg <- chart_config_from_state(
    state_mappings = list(x_column = "Uge", y_column = "Værdi"),
    autodetect = NULL,
    chart_type = "run",
    input_overrides = list(x_col = "Dato", y_col = "Tal")
  )

  expect_equal(cfg$x_col, "Uge")
  expect_equal(cfg$y_col, "Værdi")
})

test_that("autodetect bruges når state-mappings er tomme", {
  cfg <- chart_config_from_state(
    state_mappings = list(x_column = NULL, y_column = NULL, n_column = NULL),
    autodetect = structure(
      list(x_col = "AutoX", y_col = "AutoY", n_col = NULL),
      class = "AutodetectResult"
    ),
    chart_type = "run",
    input_overrides = list()
  )

  expect_equal(cfg$x_col, "AutoX")
  expect_equal(cfg$y_col, "AutoY")
})

test_that("returnerer NULL hvis ingen y_col kan bestemmes", {
  cfg <- chart_config_from_state(
    state_mappings = list(),
    autodetect = NULL,
    chart_type = "run",
    input_overrides = list()
  )

  expect_null(cfg)
})

test_that("tom string i state-mapping falder til autodetect", {
  cfg <- chart_config_from_state(
    state_mappings = list(x_column = "", y_column = "", n_column = ""),
    autodetect = structure(
      list(x_col = "AutoX", y_col = "AutoY", n_col = NULL),
      class = "AutodetectResult"
    ),
    chart_type = "run",
    input_overrides = list()
  )

  # Tomme state-mappings behandles som ikke-sat → autodetect vinder
  expect_equal(cfg$x_col, "AutoX")
  expect_equal(cfg$y_col, "AutoY")
})

test_that("chart_type fra input bevares (orthogonal til kolonne-race)", {
  cfg <- chart_config_from_state(
    state_mappings = list(x_column = "Uge", y_column = "Værdi"),
    autodetect = NULL,
    chart_type = "p",
    input_overrides = list()
  )

  expect_equal(cfg$chart_type, "p")
})

# ============================================================================
# SUITE 2: Race-scenario — full pipeline
# ============================================================================

test_that("race-scenario: ny upload med stale input → state-derived config vinder", {
  # Simulerer pipeline-state lige efter auto-detect men FØR ui_sync flushed
  # input til klient. input bærer stadig forrige session's værdier.

  # Forrige session: x="Dato", y="Tal"
  # Ny upload har kolonner: ["Uge", "Værdi"]
  # Auto-detect har sat app_state$columns$mappings$x_column="Uge", y_column="Værdi"
  # MEN input$x_column / input$y_column er STADIG "Dato"/"Tal" (throttle ej udløbet)

  stale_input <- list(x_col = "Dato", y_col = "Tal", n_col = NULL)
  fresh_state <- list(x_column = "Uge", y_column = "Værdi", n_column = NULL)
  fresh_autodetect <- structure(
    list(x_col = "Uge", y_col = "Værdi", n_col = NULL),
    class = "AutodetectResult"
  )

  cfg <- chart_config_from_state(
    state_mappings = fresh_state,
    autodetect = fresh_autodetect,
    chart_type = "run",
    input_overrides = stale_input # ignored som primary source
  )

  # POST-fix: state vinder → plot renders med "Uge"/"Værdi" (matcher nyt data)
  expect_equal(cfg$x_col, "Uge")
  expect_equal(cfg$y_col, "Værdi")
})

test_that("bruger-edit via dropdown propagerer korrekt via state", {
  # Efter race-fix: bruger-edit skrives til state via handle_column_input.
  # column_config læser state → ny config med bruger-valgt kolonne.

  # Initialt: state har autodetekteret "Uge"/"Værdi"
  # Bruger vælger "Måned" i x_column dropdown
  # handle_column_input skriver app_state$columns$mappings$x_column = "Måned"
  # column_config læser opdateret state

  user_edited_state <- list(
    x_column = "Måned", # bruger-edit
    y_column = "Værdi",
    n_column = NULL
  )

  cfg <- chart_config_from_state(
    state_mappings = user_edited_state,
    autodetect = structure(
      list(x_col = "Uge", y_col = "Værdi", n_col = NULL), # tidligere autodetect
      class = "AutodetectResult"
    ),
    chart_type = "run",
    input_overrides = list(x_col = "Måned", y_col = "Værdi") # input opdateret via dropdown
  )

  # Bruger-edit (i state via handle_column_input) vinder over autodetect
  expect_equal(cfg$x_col, "Måned")
  expect_equal(cfg$y_col, "Værdi")
})
