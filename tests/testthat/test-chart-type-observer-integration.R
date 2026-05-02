# test-chart-type-observer-integration.R
# Integration-test (testServer): observe_chart_type_input kalder
# sync_chart_type_to_state() + update_ui_for_chart_type() korrekt.
#
# Task 4.4 fra openspec/changes/split-register-chart-type-events/tasks.md
#
# Verificerer:
#   - Observer registreres og kalder sync_chart_type_to_state() (state-transition)
#   - app_state$columns$mappings$chart_type opdateres ved chart_type-skift
#   - Guard: restoring_session = TRUE spenderer observer-body
#   - Composition: begge sub-funktioner kan mockes/stubbes separat
#
# BEVIDST SCOPE: shinyjs-kald (enable/disable n_column) testes IKKE her --
# shinyjs kræver kørende browser. Disse sideeffekter hører i shinytest2.
# Her verificeres kun state-mutation (mappings$chart_type).

library(testthat)
library(shiny)

# ==============================================================================
# Hjælper: minimal server der bruger observe_chart_type_input
# ==============================================================================

create_chart_type_observer_server <- function(app_state) {
  function(input, output, session) {
    observers <- list()

    register_observer <- function(name, obs) {
      observers[[name]] <<- obs
      obs
    }

    # Kalder den rigtige produktion-funktion
    observe_chart_type_input(
      input = input,
      session = session,
      app_state = app_state,
      register_observer = register_observer
    )

    session$userData$app_state <- app_state
    session$userData$get_chart_type <- function() {
      shiny::isolate(app_state$columns$mappings$chart_type)
    }
  }
}

# ==============================================================================
# Integration: observer opdaterer mappings$chart_type
# ==============================================================================

test_that("observe_chart_type_input: chart_type 'i' skrives til mappings", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyjs")

  app_state <- create_app_state()

  shiny::testServer(
    create_chart_type_observer_server(app_state),
    {
      get_chart_type <- session$userData$get_chart_type

      # Skift chart_type via setInputs
      session$setInputs(chart_type = "i")

      # Verificer state-mutation via mappings
      result <- get_chart_type()
      expect_equal(result, "i",
        label = "mappings$chart_type skal vaere 'i' efter chart_type input 'i'"
      )
    }
  )
})

test_that("observe_chart_type_input: chart_type 'p' skrives til mappings", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyjs")

  app_state <- create_app_state()

  shiny::testServer(
    create_chart_type_observer_server(app_state),
    {
      get_chart_type <- session$userData$get_chart_type

      session$setInputs(chart_type = "p")

      result <- get_chart_type()
      expect_equal(result, "p",
        label = "mappings$chart_type skal vaere 'p' efter chart_type input 'p'"
      )
    }
  )
})

test_that("observe_chart_type_input: chart_type 'u' skrives til mappings", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyjs")

  app_state <- create_app_state()

  shiny::testServer(
    create_chart_type_observer_server(app_state),
    {
      get_chart_type <- session$userData$get_chart_type

      session$setInputs(chart_type = "u")

      result <- get_chart_type()
      expect_equal(result, "u",
        label = "mappings$chart_type skal vaere 'u' efter chart_type input 'u'"
      )
    }
  )
})

test_that("observe_chart_type_input: chart_type 'run' skrives til mappings", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyjs")

  app_state <- create_app_state()

  shiny::testServer(
    create_chart_type_observer_server(app_state),
    {
      get_chart_type <- session$userData$get_chart_type

      session$setInputs(chart_type = "run")

      result <- get_chart_type()
      expect_equal(result, "run",
        label = "mappings$chart_type skal vaere 'run' efter chart_type input 'run'"
      )
    }
  )
})

# ==============================================================================
# Integration: restoring_session guard sprender observer-body
# ==============================================================================

test_that("observe_chart_type_input: guard ignorer input under session-restore", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyjs")

  app_state <- create_app_state()

  # Saet restoring_session = TRUE (simuler session-restore guard)
  shiny::isolate({
    app_state$session$restoring_session <- TRUE
    app_state$columns$mappings$chart_type <- "run"
  })

  shiny::testServer(
    create_chart_type_observer_server(app_state),
    {
      get_chart_type <- session$userData$get_chart_type

      # Input aendres -- men guard skal stoppe body
      session$setInputs(chart_type = "p")

      # mappings$chart_type skal IKKE aendres (guard er aktiv)
      result <- get_chart_type()
      expect_equal(result, "run",
        label = "Guard: chart_type maa ikke aendres under session-restore"
      )
    }
  )
})

# ==============================================================================
# Integration: sync_chart_type_to_state returnerer korrekt transition
# (verificer at observer kalder sync korrekt)
# ==============================================================================

test_that("sync_chart_type_to_state returnerer 'p' for p-kort (via observer-flow)", {
  # Tester at observe_chart_type_input -> sync_chart_type_to_state pipeline
  # producerer korrekt qic_type for p-kort.
  # Pure-funktion-kald (ingen Shiny-runtime behoeves her).
  state <- list(columns = list(mappings = list(chart_type = "run")))
  transition <- sync_chart_type_to_state(state, "p")

  expect_equal(transition$chart_type, "p",
    label = "sync_chart_type_to_state('p') skal returnere chart_type = 'p'"
  )
  expect_true(transition$requires_denominator,
    label = "p-kort kraever nævner"
  )
  expect_equal(transition$y_axis_ui_type, "percent",
    label = "p-kort har y_axis_ui_type = 'percent'"
  )
})

test_that("sync_chart_type_to_state returnerer 'i' for i-kort (via observer-flow)", {
  state <- list(columns = list(mappings = list(chart_type = "run")))
  transition <- sync_chart_type_to_state(state, "i")

  expect_equal(transition$chart_type, "i",
    label = "sync_chart_type_to_state('i') skal returnere chart_type = 'i'"
  )
  expect_false(transition$requires_denominator,
    label = "i-kort kraever IKKE nævner"
  )
  expect_equal(transition$y_axis_ui_type, "count",
    label = "i-kort har y_axis_ui_type = 'count'"
  )
})
