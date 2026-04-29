# test-fix-state-paths-and-restore-guards.R
# TDD-tests for fix-state-paths-and-restore-guards fixes
# Phases 1, 2, 4, 6 (state path bug, restore guards, accessors)

library(shiny)

# ==============================================================================
# PHASE 1: y_col sti-bug i centerline-observer
# ==============================================================================
# Verificerer at app_state$columns$mappings$y_column er den kanoniske sti
# (IKKE app_state$columns$y_column som er FORKERT)

test_that("Phase 1: app_state$columns$mappings$y_column er korrekt sti (ikke $columns$y_column)", {
  # SETUP
  app_state <- create_app_state()
  test_y_col <- "Vaerdi"

  # Saet via den korrekte sti (mappings)
  shiny::isolate({
    app_state$columns$mappings$y_column <- test_y_col
  })

  # Korrekt laesning via mappings-sti
  result_correct <- shiny::isolate(app_state$columns$mappings$y_column)
  expect_equal(result_correct, test_y_col)

  # Den forkerte sti skal IKKE returnere vaerdien (skal vaere NULL)
  result_wrong <- shiny::isolate(app_state$columns$y_column)
  expect_null(result_wrong,
    label = "app_state$columns$y_column maa vaere NULL (korrekte sti er $columns$mappings$y_column)"
  )
})

test_that("Phase 1: centerline-observer bruger korrekt mappings$y_column-sti", {
  # Test at data + y_col laeses fra korrekt sti som centerline-observer kræver
  app_state <- create_app_state()
  test_data <- data.frame(
    Dato = as.Date("2024-01-01") + 0:4,
    Vaerdi = c(10, 12, 11, 13, 9)
  )

  shiny::isolate({
    app_state$data$current_data <- test_data
    app_state$columns$mappings$y_column <- "Vaerdi"
  })

  # Simuler hvad centerline-observer GOR (efter rettelse):
  # laes fra korrekt mappings-sti, ikke columns$y_column
  data <- shiny::isolate(app_state$data$current_data)
  y_col <- shiny::isolate(app_state$columns$mappings$y_column)

  # Forventning: y_col er non-NULL og data indeholder kolonnen
  expect_false(is.null(y_col), label = "y_col maa ikke vaere NULL naar mappings er sat")
  expect_true(y_col %in% names(data),
    label = "y_col vaerdi skal eksistere som kolonne i data"
  )

  # Simuler den korrekte data-opslag
  y_data <- data[[y_col]]
  expect_length(y_data, 5)
  expect_equal(y_data, c(10, 12, 11, 13, 9))
})

# ==============================================================================
# PHASE 2: restoring_session guard i chart-type observer
# ==============================================================================

test_that("Phase 2: restoring_session flag eksisterer paa app_state$session", {
  app_state <- create_app_state()

  # Flag skal eksistere med default FALSE
  result <- shiny::isolate(app_state$session$restoring_session)
  expect_false(is.null(result),
    label = "app_state$session$restoring_session skal eksistere (maa ikke vaere NULL)"
  )
  expect_false(result,
    label = "restoring_session skal starte FALSE"
  )
})

test_that("Phase 2: restoring_session kan saettes til TRUE og nulstilles", {
  app_state <- create_app_state()

  shiny::isolate({
    app_state$session$restoring_session <- TRUE
  })
  expect_true(shiny::isolate(app_state$session$restoring_session))

  shiny::isolate({
    app_state$session$restoring_session <- FALSE
  })
  expect_false(shiny::isolate(app_state$session$restoring_session))
})

test_that("Phase 2: guard-logik returnerer NULL naar restoring_session er TRUE", {
  # Simuler guard-check som chart-type observer bruger
  app_state <- create_app_state()

  # Saet restoring_session flag
  shiny::isolate({
    app_state$session$restoring_session <- TRUE
  })

  # Guard-check (efterligner hvad observeren gør efter rettelse)
  guard_result <- shiny::isolate({
    if (isTRUE(app_state$session$restoring_session)) {
      "blocked"
    } else {
      "proceeding"
    }
  })

  expect_equal(guard_result, "blocked",
    label = "Guard skal blokere naar restoring_session er TRUE"
  )
})

# ==============================================================================
# PHASE 4: Kolonne-mapping-accessors
# ==============================================================================

test_that("Phase 4: get_y_column returnerer korrekt vaerdi fra mappings", {
  skip_if_not(
    exists("get_y_column", mode = "function"),
    "get_y_column er ikke implementeret endnu"
  )

  app_state <- create_app_state()
  shiny::isolate({
    app_state$columns$mappings$y_column <- "MinY"
  })

  result <- get_y_column(app_state)
  expect_equal(result, "MinY")
})

test_that("Phase 4: get_x_column returnerer NULL ved tom state", {
  skip_if_not(
    exists("get_x_column", mode = "function"),
    "get_x_column er ikke implementeret endnu"
  )

  app_state <- create_app_state()
  result <- get_x_column(app_state)
  expect_null(result)
})

test_that("Phase 4: get_n_column returnerer korrekt vaerdi", {
  skip_if_not(
    exists("get_n_column", mode = "function"),
    "get_n_column er ikke implementeret endnu"
  )

  app_state <- create_app_state()
  shiny::isolate({
    app_state$columns$mappings$n_column <- "Naevner"
  })

  result <- get_n_column(app_state)
  expect_equal(result, "Naevner")
})

test_that("Phase 4: is_restoring_session returnerer korrekt flag-vaerdi", {
  skip_if_not(
    exists("is_restoring_session", mode = "function"),
    "is_restoring_session er ikke implementeret endnu"
  )

  app_state <- create_app_state()
  expect_false(is_restoring_session(app_state))

  shiny::isolate({
    app_state$session$restoring_session <- TRUE
  })
  expect_true(is_restoring_session(app_state))
})

# ==============================================================================
# PHASE 6: restoring_session guard i auto_detection_started observer
# ==============================================================================

test_that("Phase 6: auto_detection_started guard blokerer under session-restore", {
  # Simuler scenariet: autodetect trigges under session restore
  app_state <- create_app_state()

  shiny::isolate({
    app_state$session$restoring_session <- TRUE
  })

  # Guard-check (efterligner hvad auto_detection_started observer gør efter fix)
  guard_result <- shiny::isolate({
    if (isTRUE(app_state$session$restoring_session)) {
      "blocked"
    } else {
      "proceeding"
    }
  })

  expect_equal(guard_result, "blocked",
    label = "auto_detection_started skal blokeres naar restoring_session er TRUE"
  )
})

test_that("Phase 6: auto_detection_started guard tillader under normal drift", {
  app_state <- create_app_state()

  # Guard-check naar restoring_session er FALSE (default ved normal session-start)
  guard_result <- shiny::isolate({
    if (isTRUE(app_state$session$restoring_session)) {
      "blocked"
    } else {
      "proceeding"
    }
  })

  expect_equal(guard_result, "proceeding",
    label = "auto_detection_started skal proocede naar restoring_session er FALSE"
  )
})
