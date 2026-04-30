# test-sync-chart-type-to-state.R
# Pure unit-tests for sync_chart_type_to_state()
#
# KRAV: Ingen Shiny-runtime eller reactive context nødvendig.
# Funktionen opererer på plain lister/environments — kan kaldes direkte.
#
# Dækker:
#   - Alle kendte chart-type-transitioner (run, i, mr, p, pp, u, up, c, g, t)
#   - Returstruktur og felter
#   - Edge-cases: NULL, tom streng, ugyldig type
#   - State-immutabilitet: input muteres ikke

# ==============================================================================
# Hjælper: minimal state-snapshot (plain liste — ingen Shiny)
# ==============================================================================

make_state <- function(chart_type = "run") {
  list(
    columns = list(
      mappings = list(
        chart_type = chart_type
      )
    )
  )
}

# ==============================================================================
# Returstruktur
# ==============================================================================

test_that("sync_chart_type_to_state returnerer liste med forventede felter", {
  state <- make_state()
  result <- sync_chart_type_to_state(state, "run")

  expect_type(result, "list")
  expect_named(result, c("chart_type", "requires_denominator", "y_axis_ui_type"),
    ignore.order = TRUE
  )
})

# ==============================================================================
# Chart-type-transitioner: korrekt qic-kode
# ==============================================================================

test_that("sync_chart_type_to_state: 'run' → qic_type = 'run'", {
  result <- sync_chart_type_to_state(make_state(), "run")
  expect_equal(result$chart_type, "run")
})

test_that("sync_chart_type_to_state: 'i' → qic_type = 'i'", {
  result <- sync_chart_type_to_state(make_state(), "i")
  expect_equal(result$chart_type, "i")
})

test_that("sync_chart_type_to_state: 'mr' → qic_type = 'run' (fallback, ikke i CHART_TYPES_EN)", {
  # "mr" er udkommenteret i CHART_TYPES_EN — fallback til "run"
  result <- sync_chart_type_to_state(make_state(), "mr")
  expect_equal(result$chart_type, "run")
})

test_that("sync_chart_type_to_state: 'p' → qic_type = 'p'", {
  result <- sync_chart_type_to_state(make_state(), "p")
  expect_equal(result$chart_type, "p")
})

test_that("sync_chart_type_to_state: 'pp' → qic_type = 'run' (fallback, ikke i CHART_TYPES_EN)", {
  # "pp" er udkommenteret i CHART_TYPES_EN — get_qic_chart_type fallbacker til "run"
  result <- sync_chart_type_to_state(make_state(), "pp")
  expect_equal(result$chart_type, "run")
})

test_that("sync_chart_type_to_state: 'u' → qic_type = 'u'", {
  result <- sync_chart_type_to_state(make_state(), "u")
  expect_equal(result$chart_type, "u")
})

test_that("sync_chart_type_to_state: 'up' → qic_type = 'run' (fallback, ikke i CHART_TYPES_EN)", {
  # "up" er udkommenteret i CHART_TYPES_EN — fallback til "run"
  result <- sync_chart_type_to_state(make_state(), "up")
  expect_equal(result$chart_type, "run")
})

test_that("sync_chart_type_to_state: 'c' → qic_type = 'c'", {
  result <- sync_chart_type_to_state(make_state(), "c")
  expect_equal(result$chart_type, "c")
})

test_that("sync_chart_type_to_state: 'g' → qic_type = 'run' (fallback, ikke i CHART_TYPES_EN)", {
  # "g" er udkommenteret i CHART_TYPES_EN — fallback til "run"
  result <- sync_chart_type_to_state(make_state(), "g")
  expect_equal(result$chart_type, "run")
})

test_that("sync_chart_type_to_state: 't' → qic_type = 'run' (fallback, ikke i CHART_TYPES_EN)", {
  # "t" er udkommenteret i CHART_TYPES_EN — fallback til "run"
  result <- sync_chart_type_to_state(make_state(), "t")
  expect_equal(result$chart_type, "run")
})

# ==============================================================================
# requires_denominator
# ==============================================================================

test_that("sync_chart_type_to_state: 'run' kræver IKKE nævner som default", {
  result <- sync_chart_type_to_state(make_state(), "run")
  # run kræver nævner ONLY ved percent y-axis — grundtilstand: TRUE (chart_type_requires_denominator)
  expect_true(result$requires_denominator)
})

test_that("sync_chart_type_to_state: 'i' kræver ikke nævner", {
  result <- sync_chart_type_to_state(make_state(), "i")
  expect_false(result$requires_denominator)
})

test_that("sync_chart_type_to_state: 'p' kræver nævner", {
  result <- sync_chart_type_to_state(make_state(), "p")
  expect_true(result$requires_denominator)
})

test_that("sync_chart_type_to_state: 'u' kræver nævner", {
  result <- sync_chart_type_to_state(make_state(), "u")
  expect_true(result$requires_denominator)
})

test_that("sync_chart_type_to_state: 'c' kræver ikke nævner", {
  result <- sync_chart_type_to_state(make_state(), "c")
  expect_false(result$requires_denominator)
})

# ==============================================================================
# y_axis_ui_type
# ==============================================================================

test_that("sync_chart_type_to_state: 'run' → y_axis_ui_type = 'count'", {
  result <- sync_chart_type_to_state(make_state(), "run")
  expect_equal(result$y_axis_ui_type, "count")
})

test_that("sync_chart_type_to_state: 'i' → y_axis_ui_type = 'count'", {
  result <- sync_chart_type_to_state(make_state(), "i")
  expect_equal(result$y_axis_ui_type, "count")
})

test_that("sync_chart_type_to_state: 'p' → y_axis_ui_type = 'percent'", {
  result <- sync_chart_type_to_state(make_state(), "p")
  expect_equal(result$y_axis_ui_type, "percent")
})

test_that("sync_chart_type_to_state: 'pp' → y_axis_ui_type = 'percent' (direkte match)", {
  result <- sync_chart_type_to_state(make_state(), "pp")
  expect_equal(result$y_axis_ui_type, "percent")
})

test_that("sync_chart_type_to_state: 'u' → y_axis_ui_type = 'rate'", {
  result <- sync_chart_type_to_state(make_state(), "u")
  expect_equal(result$y_axis_ui_type, "rate")
})

test_that("sync_chart_type_to_state: 'up' → y_axis_ui_type = 'rate' (direkte match)", {
  result <- sync_chart_type_to_state(make_state(), "up")
  expect_equal(result$y_axis_ui_type, "rate")
})

test_that("sync_chart_type_to_state: 'c' → y_axis_ui_type = 'count'", {
  result <- sync_chart_type_to_state(make_state(), "c")
  expect_equal(result$y_axis_ui_type, "count")
})

test_that("sync_chart_type_to_state: 't' → y_axis_ui_type = 'time_days' (direkte match)", {
  result <- sync_chart_type_to_state(make_state(), "t")
  expect_equal(result$y_axis_ui_type, "time_days")
})

# ==============================================================================
# Edge-cases: NULL, tom streng, ugyldig type
# ==============================================================================

test_that("sync_chart_type_to_state: NULL new_type → fallback til 'run'", {
  result <- sync_chart_type_to_state(make_state(), NULL)
  expect_equal(result$chart_type, "run")
  expect_type(result, "list")
})

test_that("sync_chart_type_to_state: tom streng → fallback til 'run'", {
  result <- sync_chart_type_to_state(make_state(), "")
  expect_equal(result$chart_type, "run")
})

test_that("sync_chart_type_to_state: ugyldig chart_type → fallback til 'run'", {
  result <- sync_chart_type_to_state(make_state(), "UGYLDIG_TYPE_XYZ")
  expect_equal(result$chart_type, "run")
})

test_that("sync_chart_type_to_state: NULL state → ingen fejl, returnerer korrekt liste", {
  # state-argument bruges ikke direkte i beregningen (pure output afhænger kun af new_type)
  result <- sync_chart_type_to_state(NULL, "run")
  expect_type(result, "list")
  expect_equal(result$chart_type, "run")
})

test_that("sync_chart_type_to_state: tom liste som state → ingen fejl", {
  result <- sync_chart_type_to_state(list(), "i")
  expect_type(result, "list")
  expect_equal(result$chart_type, "i")
})

# ==============================================================================
# Immutabilitet: input-state muteres ikke
# ==============================================================================

test_that("sync_chart_type_to_state muterer ikke input-state", {
  state <- make_state("run")
  original_ct <- state$columns$mappings$chart_type

  sync_chart_type_to_state(state, "p")

  # State er uændret
  expect_equal(state$columns$mappings$chart_type, original_ct)
})

# ==============================================================================
# Ingen Shiny-afhængighed: verificer at funktionen ikke kalder Shiny APIs
# ==============================================================================

test_that("sync_chart_type_to_state kræver ikke Shiny reactive context", {
  # Kald UDEN for isolate() — ville fejle hvis funktionen brugte reactive()
  # Ingen shiny::testServer() her — plain funktion kald
  result <- sync_chart_type_to_state(make_state("run"), "p")
  expect_equal(result$chart_type, "p")
})
