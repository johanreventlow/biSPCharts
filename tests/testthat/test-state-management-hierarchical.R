# test-state-management-hierarchical.R
# Comprehensive tests for hierarchical state management system
# Tests the new app_state architecture with reactive values and event systems
# Foundation for all other functionality - critical path testing

test_that("create_app_state basic functionality works", {
  # TEST: Core app_state creation and structure

  # Skip if create_app_state function not available
  require_internal("create_app_state", mode = "function")

  # SETUP: Create app state
  app_state <- create_app_state()

  # Verify basic structure
  expect_true(is.environment(app_state))
  expect_true("events" %in% names(app_state))
  expect_true("data" %in% names(app_state))
  expect_true("columns" %in% names(app_state))

  # Verify reactive values structure
  expect_s3_class(app_state$events, "reactivevalues")
  expect_s3_class(app_state$data, "reactivevalues")
  expect_s3_class(app_state$columns, "reactivevalues")

  # Verify hierarchical column structure (nested reactive values kræver isolate)
  expect_s3_class(isolate(app_state$columns$auto_detect), "reactivevalues")
  expect_s3_class(isolate(app_state$columns$mappings), "reactivevalues")
  expect_s3_class(isolate(app_state$columns$ui_sync), "reactivevalues")
})

test_that("app_state event system works correctly", {
  # TEST: Event bus functionality and triggering

  # SETUP: Create app state
  app_state <- create_app_state()

  # TEST: Initial event values
  # data_updated er det konsoliderede event (erstatter data_loaded, data_changed)
  expect_equal(isolate(app_state$events$data_updated), 0L)
  expect_equal(isolate(app_state$events$auto_detection_started), 0L)
  # ui_sync_requested er det aktuelle navn (erstatter ui_sync_needed)
  expect_equal(isolate(app_state$events$ui_sync_requested), 0L)

  # TEST: Event triggering
  app_state$events$data_updated <- isolate(app_state$events$data_updated) + 1L
  expect_equal(isolate(app_state$events$data_updated), 1L)

  # TEST: Multiple event types
  app_state$events$auto_detection_completed <- 1L
  app_state$events$ui_sync_requested <- 1L

  expect_equal(isolate(app_state$events$auto_detection_completed), 1L)
  expect_equal(isolate(app_state$events$ui_sync_requested), 1L)

  # TEST: Event independence
  expect_equal(isolate(app_state$events$data_updated), 1L) # Should remain unchanged
})

test_that("app_state data management works", {
  # TEST: Data management reactive values

  # SETUP: Create app state
  app_state <- create_app_state()

  # TEST: Initial data state
  expect_null(isolate(app_state$data$current_data))
  expect_null(isolate(app_state$data$original_data))
  expect_false(isolate(app_state$data$updating_table))
  expect_equal(isolate(app_state$data$table_version), 0)

  # TEST: Data assignment
  test_data <- data.frame(
    Dato = c("01-01-2024", "01-02-2024"),
    Værdi = c(45, 43),
    stringsAsFactors = FALSE
  )

  app_state$data$current_data <- test_data
  app_state$data$original_data <- test_data

  expect_equal(nrow(isolate(app_state$data$current_data)), 2)
  expect_equal(nrow(isolate(app_state$data$original_data)), 2)
  expect_true(all(names(isolate(app_state$data$current_data)) == c("Dato", "Værdi")))

  # TEST: Table operation flags
  app_state$data$updating_table <- TRUE
  app_state$data$table_version <- 1

  expect_true(isolate(app_state$data$updating_table))
  expect_equal(isolate(app_state$data$table_version), 1)

  # TEST: File metadata
  app_state$data$file_info <- list(name = "test.csv", size = 1024)
  app_state$data$file_path <- "/path/to/test.csv"

  expect_equal(isolate(app_state$data$file_info)$name, "test.csv")
  expect_equal(isolate(app_state$data$file_path), "/path/to/test.csv")
})

test_that("app_state environment-based sharing works", {
  # TEST: Environment-based by-reference sharing

  # SETUP: Create app state
  app_state <- create_app_state()

  # TEST: Function that modifies state by reference
  # (nested reactive values kræver isolate for at sætte)
  modify_state <- function(state) {
    state$data$current_data <- data.frame(test = "modified")
    m <- isolate(state$columns$mappings)
    m$x_column <- "modified_column"
    state$events$data_updated <- 99L
  }

  # Modify state through function
  modify_state(app_state)

  # Verify changes persist (environment passed by reference)
  expect_equal(isolate(app_state$data$current_data)$test, "modified")
  # columns$mappings er nested reactive - kræver isolate(isolate(...))
  m <- isolate(app_state$columns$mappings)
  expect_equal(isolate(m$x_column), "modified_column")
  expect_equal(isolate(app_state$events$data_updated), 99L)

  # TEST: Multiple references to same environment
  app_state_ref1 <- app_state
  app_state_ref2 <- app_state

  app_state_ref1$data$table_version <- 100

  # Both references should see the change
  expect_equal(isolate(app_state_ref2$data$table_version), 100)
  expect_equal(isolate(app_state$data$table_version), 100)
})

test_that("app_state session management works", {
  # TEST: Session-related state management

  # SETUP: Create app state with session components
  app_state <- create_app_state()

  # Verify session structure exists if defined
  if ("session" %in% names(app_state)) {
    # TEST: Session state initial values
    expect_true(isolate(app_state$session$auto_save_enabled) %||% TRUE)
    expect_false(isolate(app_state$session$restoring_session) %||% FALSE)
    expect_false(isolate(app_state$session$file_uploaded) %||% FALSE)

    # TEST: Session state updates
    app_state$session$file_uploaded <- TRUE
    app_state$session$user_started_session <- TRUE
    app_state$session$file_name <- "test_data.csv"

    expect_true(isolate(app_state$session$file_uploaded))
    expect_true(isolate(app_state$session$user_started_session))
    expect_equal(isolate(app_state$session$file_name), "test_data.csv")
  }
})

test_that("app_state error handling and recovery works", {
  # TEST: Error states and recovery mechanisms

  # SETUP: Create app state
  app_state <- create_app_state()

  # TEST: Error event handling
  # error_occurred er det konsoliderede event (validation_error og processing_error er ikke separate)
  expect_equal(isolate(app_state$events$error_occurred), 0L)

  # validation_error og processing_error er ikke egne events længere
  # de er konsolideret til error_occurred med context
  # Trigger the consolidated error event
  app_state$events$error_occurred <- 1L
  expect_equal(isolate(app_state$events$error_occurred), 1L)

  # TEST: Recovery workflow
  app_state$events$recovery_completed <- 1L
  expect_equal(isolate(app_state$events$recovery_completed), 1L)
})

test_that("app_state performance and memory management works", {
  set.seed(42)
  # TEST: Performance considerations and memory usage

  # SETUP: Create app state
  app_state <- create_app_state()

  # TEST: Large data handling
  large_data <- data.frame(
    x = 1:1000,
    y = sample(1:100, 1000, replace = TRUE),
    z = runif(1000)
  )

  # Measure memory impact
  start_time <- Sys.time()
  app_state$data$current_data <- large_data
  assignment_time <- as.numeric(Sys.time() - start_time)

  # Should handle large data efficiently
  expect_lt(assignment_time, 1.0) # Should complete in under 1 second
  expect_equal(nrow(isolate(app_state$data$current_data)), 1000)

  # TEST: State cleanup
  app_state$data$current_data <- NULL
  app_state$data$original_data <- NULL

  expect_null(isolate(app_state$data$current_data))
  expect_null(isolate(app_state$data$original_data))
})

# ==============================================================================
# Niveau B: Hierarkisk column management (create_app_state + isolate, ingen reaktiv kæde)
# ==============================================================================

test_that("app_state hierarchical column management works", {
  # TEST: Hierarkisk kolonne-struktur og mappings

  # SETUP: Opret app state
  app_state <- create_app_state()

  # TEST: Auto-detection sub-system (nested reactive values kræver isolate)
  expect_false(isolate(isolate(app_state$columns$auto_detect)$in_progress))
  expect_false(isolate(isolate(app_state$columns$auto_detect)$completed))
  expect_null(isolate(isolate(app_state$columns$auto_detect)$results))

  # Opdater auto-detection state via nested isolate
  ad <- isolate(app_state$columns$auto_detect)
  ad$in_progress <- TRUE
  ad$results <- list(x_col = "Dato", y_col = "Værdi")

  expect_true(isolate(ad$in_progress))
  expect_equal(isolate(ad$results)$x_col, "Dato")

  # TEST: Column mappings sub-system
  m <- isolate(app_state$columns$mappings)
  expect_null(isolate(m$x_column))
  expect_null(isolate(m$y_column))
  expect_null(isolate(m$n_column))

  # Opdater column mappings
  shiny::isolate({
    app_state$columns$mappings$x_column <- "Dato"
    app_state$columns$mappings$y_column <- "Tæller"
    app_state$columns$mappings$n_column <- "Nævner"
    app_state$columns$mappings$cl_column <- "Control_Limit"
    app_state$columns$mappings$skift_column <- "Skift"
    app_state$columns$mappings$frys_column <- "Frys"
    app_state$columns$mappings$kommentar_column <- "Kommentar"
  })

  expect_equal(isolate(app_state$columns$mappings$x_column), "Dato")
  expect_equal(isolate(app_state$columns$mappings$y_column), "Tæller")
  expect_equal(isolate(app_state$columns$mappings$n_column), "Nævner")
  expect_equal(isolate(app_state$columns$mappings$cl_column), "Control_Limit")
  expect_equal(isolate(app_state$columns$mappings$skift_column), "Skift")
  expect_equal(isolate(app_state$columns$mappings$frys_column), "Frys")
  expect_equal(isolate(app_state$columns$mappings$kommentar_column), "Kommentar")

  # TEST: UI synchronization sub-system
  expect_false(isolate(isolate(app_state$columns$ui_sync)$needed))
  expect_null(isolate(isolate(app_state$columns$ui_sync)$last_sync_time))

  shiny::isolate({
    app_state$columns$ui_sync$needed <- TRUE
    app_state$columns$ui_sync$last_sync_time <- Sys.time()
  })

  expect_true(isolate(isolate(app_state$columns$ui_sync)$needed))
  expect_true(inherits(isolate(isolate(app_state$columns$ui_sync)$last_sync_time), c("POSIXct", "POSIXt")))
})

test_that("app_state complex state transitions work", {
  # TEST: Komplekse state-transition scenarier
  # Opdateret: data_loaded → data_updated, ui_sync_needed → ui_sync_requested

  # SETUP: Opret app state
  app_state <- create_app_state()

  # Step 1: Data upload starter
  app_state$data$updating_table <- TRUE
  app_state$events$data_updated <- 1L

  expect_true(isolate(app_state$data$updating_table))
  expect_equal(isolate(app_state$events$data_updated), 1L)

  # Step 2: Data processeret
  test_data <- data.frame(
    Dato = c("01-01-2024", "01-02-2024", "01-03-2024"),
    Tæller = c(45, 43, 48),
    Nævner = c(50, 50, 50)
  )
  app_state$data$current_data <- test_data
  app_state$data$original_data <- test_data

  # Step 3: Auto-detection trigget
  app_state$events$auto_detection_started <- 1L
  ad <- shiny::isolate(app_state$columns$auto_detect)
  ad$in_progress <- TRUE

  # Step 4: Auto-detection fuldført
  shiny::isolate({
    app_state$columns$mappings$x_column <- "Dato"
    app_state$columns$mappings$y_column <- "Tæller"
    app_state$columns$mappings$n_column <- "Nævner"
    app_state$columns$auto_detect$completed <- TRUE
    app_state$columns$auto_detect$frozen_until_next_trigger <- TRUE
  })
  app_state$events$auto_detection_completed <- 1L

  # Step 5: UI sync requested (erstatter ui_sync_needed)
  app_state$events$ui_sync_requested <- 1L
  us <- shiny::isolate(app_state$columns$ui_sync)
  us$needed <- TRUE

  # Step 6: Workflow fuldført
  app_state$data$updating_table <- FALSE
  app_state$events$ui_sync_completed <- 1L
  us$needed <- FALSE

  # Verificér final state
  expect_false(isolate(app_state$data$updating_table))
  expect_true(isolate(isolate(app_state$columns$auto_detect)$completed))
  expect_true(isolate(isolate(app_state$columns$auto_detect)$frozen_until_next_trigger))
  expect_false(isolate(isolate(app_state$columns$ui_sync)$needed))
  expect_equal(isolate(app_state$columns$mappings$x_column), "Dato")
  expect_equal(isolate(app_state$columns$mappings$y_column), "Tæller")
  expect_equal(isolate(app_state$columns$mappings$n_column), "Nævner")
})

test_that("app_state backward compatibility works", {
  # TEST: Moderne hierarkisk adgang til kolonne-state

  # SETUP: Opret app state
  app_state <- create_app_state()

  # TEST: Moderne hierarkisk adgang
  shiny::isolate({
    app_state$columns$mappings$x_column <- "modern_x"
  })
  expect_equal(isolate(app_state$columns$mappings$x_column), "modern_x")

  # TEST: Migration helper (hvis eksisterer)
  if (exists("migrate_legacy_state", mode = "function")) {
    legacy_state <- list(
      x_column = "old_x",
      y_column = "old_y",
      auto_detected_columns = list(x = "detected_x")
    )

    migrated_state <- migrate_legacy_state(legacy_state, app_state)

    expect_equal(isolate(migrated_state$columns$mappings$x_column), "old_x")
    expect_equal(isolate(migrated_state$columns$mappings$y_column), "old_y")
  } else {
    # Funktion ikke implementeret - men hierarkisk adgang virker
    expect_equal(isolate(app_state$columns$mappings$x_column), "modern_x")
  }
})

test_that("app_state Danish clinical workflow works", {
  # TEST: Komplet dansk klinisk data workflow
  # Opdateret: data_loaded → data_updated, ui_sync_needed → ui_sync_requested

  # SETUP: Opret app state
  app_state <- create_app_state()

  # TEST: Dansk klinisk data simulation
  danish_data <- data.frame(
    Måned = c("Jan 2024", "Feb 2024", "Mar 2024"),
    Genindlæggelser = c(12, 8, 15),
    `Samlede indlæggelser` = c(150, 145, 160),
    Målestatus = c("Standard", "Under mål", "Over mål"),
    Faseændring = c(FALSE, FALSE, TRUE),
    `Frys baseline` = c(FALSE, FALSE, TRUE),
    `Klinisk kommentar` = c("", "Ferieperiode", "Ny procedure"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # 1. Data upload
  app_state$data$current_data <- danish_data
  app_state$data$original_data <- danish_data
  app_state$events$data_updated <- 1L # Erstattet data_loaded → data_updated

  # 2. Auto-detection
  shiny::isolate({
    app_state$columns$mappings$x_column <- "Måned"
    app_state$columns$mappings$y_column <- "Genindlæggelser"
    app_state$columns$mappings$n_column <- "Samlede indlæggelser"
    app_state$columns$mappings$skift_column <- "Faseændring"
    app_state$columns$mappings$frys_column <- "Frys baseline"
    app_state$columns$mappings$kommentar_column <- "Klinisk kommentar"
  })
  app_state$events$auto_detection_completed <- 1L

  # 3. UI sync
  app_state$events$ui_sync_requested <- 1L # Erstattet ui_sync_needed → ui_sync_requested
  us <- shiny::isolate(app_state$columns$ui_sync)
  us$needed <- TRUE

  # Verificér dansk workflow state
  expect_equal(nrow(isolate(app_state$data$current_data)), 3)
  expect_equal(isolate(app_state$columns$mappings$x_column), "Måned")
  expect_equal(isolate(app_state$columns$mappings$y_column), "Genindlæggelser")
  expect_equal(isolate(app_state$columns$mappings$n_column), "Samlede indlæggelser")
  expect_equal(isolate(app_state$columns$mappings$skift_column), "Faseændring")
  expect_equal(isolate(app_state$columns$mappings$frys_column), "Frys baseline")
  expect_equal(isolate(app_state$columns$mappings$kommentar_column), "Klinisk kommentar")

  # Verificér dansk tegn-støtte i data
  expect_true(all(grepl("æ|ø|å", c("Måned", "Genindlæggelser", "Samlede indlæggelser"))))
})

# ==============================================================================
# Niveau C: testServer-baserede reaktive kæde-tests
# ==============================================================================

test_that("app_state reactive chains work correctly", {
  # TEST: Reaktive kæder i testServer-kontekst
  # Verificerer at data_summary reactive virker korrekt efter data er sat.
  skip_if_not_installed("shiny")

  create_server <- function() {
    function(input, output, session) {
      app_state <- create_app_state()
      session$userData$app_state <- app_state

      # Reaktivt udtryk afhængigt af state
      data_summary <- shiny::reactive({
        shiny::req(app_state$data$current_data)
        data <- shiny::isolate(app_state$data$current_data)
        list(
          rows = nrow(data),
          cols = ncol(data),
          names = names(data)
        )
      })

      session$userData$data_summary <- data_summary
      session$userData$emit <- create_emit_api(app_state)

      # Output til at drive reaktiviteten
      output$summary_rows <- shiny::renderText({
        s <- data_summary()
        as.character(s$rows)
      })
    }
  }

  shiny::testServer(create_server(), {
    app_state <- session$userData$app_state

    # Sæt data og flush
    app_state$data$current_data <- data.frame(A = 1:3, B = 4:6, C = 7:9)
    session$flushReact()

    # Verificér reaktiv state via output
    expect_equal(output$summary_rows, "3")
  })
})

test_that("app_state event-driven workflows work", {
  # TEST: Event-driven state updates i testServer-kontekst
  # Verificerer at emit-funktioner opdaterer app_state korrekt.
  skip_if_not_installed("shiny")

  create_server <- function() {
    function(input, output, session) {
      app_state <- create_app_state()
      emit <- create_emit_api(app_state)
      session$userData$app_state <- app_state
      session$userData$emit <- emit
    }
  }

  shiny::testServer(create_server(), {
    app_state <- session$userData$app_state
    emit <- session$userData$emit

    # TEST: emit$data_updated inkrementerer event-counter
    initial_data_updated <- shiny::isolate(app_state$events$data_updated)
    emit$data_updated(context = "file_upload")
    expect_equal(
      shiny::isolate(app_state$events$data_updated),
      initial_data_updated + 1L
    )

    # TEST: emit$auto_detection_started inkrementerer counter
    initial_auto <- shiny::isolate(app_state$events$auto_detection_started)
    emit$auto_detection_started()
    expect_equal(
      shiny::isolate(app_state$events$auto_detection_started),
      initial_auto + 1L
    )

    # TEST: emit$auto_detection_completed inkrementerer counter
    initial_completed <- shiny::isolate(app_state$events$auto_detection_completed)
    emit$auto_detection_completed()
    expect_equal(
      shiny::isolate(app_state$events$auto_detection_completed),
      initial_completed + 1L
    )

    # TEST: State kan opdateres direkte i testServer
    shiny::isolate({
      app_state$columns$mappings$x_column <- "detected_x"
    })
    expect_equal(
      shiny::isolate(app_state$columns$mappings$x_column),
      "detected_x"
    )
  })
})
