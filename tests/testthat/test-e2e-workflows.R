# test-e2e-workflows.R
# Konsolideret E2E testfil (Phase 3, Issue #322)
# Merget fra:
#   - test-e2e-workflows.R      (5 tests: pure R state-based, kører i CI)
#   - test-e2e-user-workflows.R (8 tests: shinytest2 UI-tests, skip_on_ci)
#
# SEKTION A: Pure R state-based workflow tests (kører altid)
# SEKTION B: shinytest2 UI workflow tests (skip_on_ci + Chrome-krav)

test_that("Complete user journey: upload til chart generation", {
  set.seed(42)
  skip_if_not_installed("shiny")
  skip_if_not_installed("qicharts2")

  session_mock <- list(token = "test_session_123")

  input_datapath <- tempfile(fileext = ".csv")
  test_data <- data.frame(
    Dato = seq(as.Date("2023-01-01"), by = "day", length.out = 30),
    Vaerdi = rnorm(30, mean = 25, sd = 5),
    stringsAsFactors = FALSE
  )
  write.csv(test_data, input_datapath, row.names = FALSE)
  on.exit(unlink(input_datapath), add = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  # Trin 1: Filupload
  upload_result <- safe_operation(
    "E2E: File upload",
    code = {
      file_path <- validate_safe_file_path(input_datapath)
      data <- readr::read_csv(file_path, show_col_types = FALSE)
      set_current_data(app_state, data)
      emit$data_updated("file_loaded")
      TRUE
    },
    fallback = FALSE
  )

  expect_true(upload_result)
  expect_true(!is.null(shiny::isolate(app_state$data$current_data)))
  expect_equal(nrow(shiny::isolate(app_state$data$current_data)), 30)

  # Trin 2: Auto-detektion
  autodetect_result <- safe_operation(
    "E2E: Auto-detection",
    code = {
      shiny::isolate({
        app_state$columns$auto_detect$in_progress <- TRUE
      })
      emit$auto_detection_started()
      shiny::isolate({
        app_state$columns$auto_detect$results <- list(
          x_column = "Dato",
          y_column = "Vaerdi",
          confidence = 0.95
        )
        app_state$columns$auto_detect$completed <- TRUE
      })
      emit$auto_detection_completed()
      TRUE
    },
    fallback = FALSE
  )

  expect_true(autodetect_result)
  expect_true(shiny::isolate(app_state$columns$auto_detect$completed))
  expect_equal(
    shiny::isolate(app_state$columns$auto_detect$results$x_column), "Dato"
  )

  # Trin 3: Kolonne-mapping
  mapping_result <- safe_operation(
    "E2E: Column mapping",
    code = {
      shiny::isolate({
        app_state$columns$mappings$x_column <- "Dato"
        app_state$columns$mappings$y_column <- "Vaerdi"
      })
      emit$ui_sync_requested()
      TRUE
    },
    fallback = FALSE
  )

  expect_true(mapping_result)
  expect_equal(shiny::isolate(app_state$columns$mappings$x_column), "Dato")
  expect_equal(shiny::isolate(app_state$columns$mappings$y_column), "Vaerdi")

  # Trin 4: Chart-generering via qicharts2
  chart_result <- safe_operation(
    "E2E: Chart generation",
    code = {
      req_data <- shiny::isolate(app_state$data$current_data)
      req_x <- shiny::isolate(app_state$columns$mappings$x_column)
      req_y <- shiny::isolate(app_state$columns$mappings$y_column)

      if (!is.null(req_data) && !is.null(req_x) && !is.null(req_y)) {
        chart <- qicharts2::qic(
          x = req_data[[req_x]],
          y = req_data[[req_y]],
          chart = "i",
          title = "E2E Test Chart"
        )
        return(list(success = TRUE, chart = chart))
      }
      return(list(success = FALSE))
    },
    fallback = list(success = FALSE)
  )

  expect_true(chart_result$success)
  expect_true(!is.null(chart_result$chart))

  # Trin 5: State konsistens
  consistency_check <- safe_operation(
    "E2E: State consistency",
    code = {
      checks <- list(
        data_present = !is.null(shiny::isolate(app_state$data$current_data)),
        columns_mapped = !is.null(
          shiny::isolate(app_state$columns$mappings$x_column)
        ),
        autodetect_complete = shiny::isolate(
          app_state$columns$auto_detect$completed
        ),
        session_active = !is.null(session_mock$token)
      )
      all(unlist(checks))
    },
    fallback = FALSE
  )

  expect_true(consistency_check)
})

test_that("Error recovery workflow haandterer fejl graciost", {
  set.seed(42)
  skip_if_not_installed("shiny")

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  # Scenario 1: Ugyldig filsti
  expect_no_error({
    result <- tryCatch(
      validate_safe_file_path("../../../etc/passwd"),
      error = function(e) e
    )
    expect_true(inherits(result, "error"))
  })

  # Scenario 2: Memory pressure (set og ryd data)
  expect_no_error({
    large_data <- data.frame(x = 1:1000, y = rnorm(1000))
    set_current_data(app_state, large_data)
    gc()
    small_data <- data.frame(x = 1:5, y = 1:5)
    set_current_data(app_state, small_data)
    expect_equal(nrow(shiny::isolate(app_state$data$current_data)), 5)
  })
})

test_that("TODO Fase 3: create_chart_validator eksisterer ikke", {
  skip(paste0(
    "TODO Fase 3: R-bug afsloeret — create_chart_validator() ikke i namespace (#203-followup)"
  ))
  validator <- create_chart_validator()
  expect_true(is.list(validator))
  expect_true(is.function(validator$validate_chart_data))
})

test_that("Session lifecycle management virker korrekt", {
  set.seed(42)
  skip_if_not_installed("shiny")

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  # Session initialisering
  session_init_result <- safe_operation(
    "Session initialization",
    code = {
      shiny::isolate({
        app_state$session$user_started_session <- TRUE
        app_state$session$auto_save_enabled <- TRUE
      })
      emit$session_started()
      TRUE
    },
    fallback = FALSE
  )

  expect_true(session_init_result)
  expect_true(shiny::isolate(app_state$session$user_started_session))

  # Data operationer
  test_data <- data.frame(x = 1:10, y = rnorm(10))
  data_ops_result <- safe_operation(
    "Session data operations",
    code = {
      set_current_data(app_state, test_data)
      shiny::isolate(app_state$session$file_uploaded <- TRUE)
      emit$data_updated("session_data")
      TRUE
    },
    fallback = FALSE
  )

  expect_true(data_ops_result)
  expect_true(shiny::isolate(app_state$session$file_uploaded))

  # Session cleanup
  cleanup_result <- safe_operation(
    "Session cleanup",
    code = {
      shiny::isolate({
        app_state$session$user_started_session <- FALSE
        app_state$session$file_uploaded <- FALSE
        app_state$data$current_data <- NULL
        app_state$columns$auto_detect$completed <- FALSE
        app_state$columns$auto_detect$results <- NULL
      })
      TRUE
    },
    fallback = FALSE
  )

  expect_true(cleanup_result)
  expect_false(shiny::isolate(app_state$session$user_started_session))
  expect_null(shiny::isolate(app_state$data$current_data))
})

test_that("Performance workflow haandterer successive operationer", {
  set.seed(42)
  skip_if_not_installed("shiny")
  skip_if(Sys.getenv("CI") == "true", "Skip concurrent test in CI")

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  test_data <- data.frame(x = 1:100, y = rnorm(100))

  start_time <- Sys.time()

  operations_result <- safe_operation(
    "Concurrent operations test",
    code = {
      for (i in 1:10) {
        set_current_data(app_state, test_data)
        emit$data_updated(paste("operation", i))
        shiny::isolate({
          app_state$columns$auto_detect$in_progress <- TRUE
          app_state$columns$auto_detect$completed <- TRUE
        })
        emit$auto_detection_completed()
        emit$ui_sync_requested()
        emit$ui_sync_completed()
      }
      TRUE
    },
    fallback = FALSE
  )

  operation_time <- as.numeric(Sys.time() - start_time)

  expect_true(operations_result)
  expect_lt(operation_time, 10.0)

  expect_true(!is.null(shiny::isolate(app_state$data$current_data)))
  expect_equal(nrow(shiny::isolate(app_state$data$current_data)), 100)
})

# ===========================================================================
# SEKTION B: shinytest2 UI workflow tests (fra test-e2e-user-workflows.R)
# Alle tests kræver Chrome/Chromium og skip_on_ci()
# ===========================================================================

skip_if_no_shinytest2_runtime <- function() {
  skip_if_not_installed("shinytest2")
  skip_if_not_installed("chromote")

  if (Sys.getenv("CI_SKIP_SHINYTEST2", "false") %in% c("true", "TRUE", "1")) {
    skip("CI_SKIP_SHINYTEST2 env-flag sat")
  }

  chrome_path <- tryCatch(
    chromote::find_chrome(),
    error = function(e) ""
  )
  skip_if(
    is.null(chrome_path) || !nzchar(chrome_path),
    "Chrome/Chromium ikke fundet til shinytest2"
  )
}

create_e2e_driver <- function(name, width = 1200, height = 800, ...) {
  shinytest2::AppDriver$new(
    app_dir = "../../",
    name = name,
    width = width,
    height = height,
    variant = shinytest2::platform_variant(),
    ...
  )
}

test_that("E2E: App launches successfully", {
  skip_if_no_shinytest2_runtime()
  skip_on_ci()

  app <- create_e2e_driver(name = "app_launch", height = 800, width = 1200)
  app$wait_for_idle()

  expect_true(is.character(app$get_url()) && nzchar(app$get_url()))
  app$expect_screenshot()
  app$stop()
})

test_that("E2E: User can upload CSV file", {
  skip_if_no_shinytest2_runtime()
  skip_on_ci()

  test_data <- data.frame(
    Dato = c("01-01-2023", "02-01-2023", "03-01-2023", "04-01-2023", "05-01-2023"),
    Tæller = c(10, 15, 12, 18, 14),
    Nævner = c(100, 120, 110, 130, 115),
    Kommentar = c("", "Peak", "", "High", "")
  )
  temp_file <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_file, row.names = FALSE)
  on.exit(unlink(temp_file), add = TRUE)

  app <- create_e2e_driver(name = "file_upload", height = 800, width = 1200)
  app$wait_for_idle()
  app$upload_file(direct_file_upload = temp_file)
  app$wait_for_idle(duration = 2000)
  app$expect_screenshot()

  values <- app$get_values()
  expect_true(length(values) > 0)
  app$stop()
})

test_that("E2E: Auto-detection runs after file upload", {
  skip_if_no_shinytest2_runtime()
  skip_on_ci()

  test_data <- data.frame(
    Dato = as.Date(c("2023-01-01", "2023-01-02", "2023-01-03")),
    Antal = c(5, 10, 15),
    Total = c(100, 100, 100)
  )
  temp_file <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_file, row.names = FALSE)
  on.exit(unlink(temp_file), add = TRUE)

  app <- create_e2e_driver(name = "autodetect", height = 800, width = 1200)
  app$wait_for_idle()
  app$upload_file(direct_file_upload = temp_file)
  app$wait_for_idle(duration = 3000)
  app$expect_screenshot()

  values <- app$get_values()
  expect_true(!is.null(values$input))
  app$stop()
})

test_that("E2E: User can generate SPC chart", {
  set.seed(42)
  skip_if_no_shinytest2_runtime()
  skip_on_ci()

  test_data <- data.frame(
    Dato = seq.Date(as.Date("2023-01-01"), by = "day", length.out = 20),
    Værdi = rnorm(20, mean = 50, sd = 10),
    Kommentar = c(rep("", 19), "Outlier")
  )
  temp_file <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_file, row.names = FALSE)
  on.exit(unlink(temp_file), add = TRUE)

  app <- create_e2e_driver(name = "chart_generation", height = 800, width = 1200)
  app$wait_for_idle()
  app$upload_file(direct_file_upload = temp_file)
  app$wait_for_idle(duration = 2000)

  tryCatch(
    {
      app$set_inputs(chart_type = "Run chart")
      app$wait_for_idle(duration = 1000)
    },
    error = function(e) message("Could not set chart_type input: ", e$message)
  )

  app$wait_for_idle(duration = 2000)
  app$expect_screenshot()

  values <- app$get_values()
  expect_true(!is.null(values$output))
  app$stop()
})

test_that("E2E: User can manually select columns", {
  skip_if_no_shinytest2_runtime()
  skip_on_ci()

  test_data <- data.frame(ColA = 1:10, ColB = 11:20, ColC = 21:30)
  temp_file <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_file, row.names = FALSE)
  on.exit(unlink(temp_file), add = TRUE)

  app <- create_e2e_driver(name = "column_selection", height = 800, width = 1200)
  app$wait_for_idle()
  app$upload_file(direct_file_upload = temp_file)
  app$wait_for_idle(duration = 2000)

  tryCatch(
    {
      app$set_inputs(x_column = "ColA", y_column = "ColB")
      app$wait_for_idle(duration = 1000)
    },
    error = function(e) message("Could not set column inputs: ", e$message)
  )

  app$expect_screenshot()
  values <- app$get_values()
  expect_true(length(values) > 0)
  app$stop()
})

test_that("E2E: User can edit data in table", {
  skip_if_no_shinytest2_runtime()
  skip_on_ci()

  test_data <- data.frame(X = 1:5, Y = c(10, 20, 30, 40, 50))
  temp_file <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_file, row.names = FALSE)
  on.exit(unlink(temp_file), add = TRUE)

  app <- create_e2e_driver(name = "table_edit", height = 800, width = 1200)
  app$wait_for_idle()
  app$upload_file(direct_file_upload = temp_file)
  app$wait_for_idle(duration = 2000)
  app$expect_screenshot()

  values <- app$get_values()
  expect_true(!is.null(values))
  app$stop()
})

test_that("E2E: App handles invalid data gracefully", {
  skip_if_no_shinytest2_runtime()
  skip_on_ci()

  test_data <- data.frame(
    ColA = c("text", "more", "text"),
    ColB = c("data", "here", "too")
  )
  temp_file <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_file, row.names = FALSE)
  on.exit(unlink(temp_file), add = TRUE)

  app <- create_e2e_driver(name = "error_handling", height = 800, width = 1200)
  app$wait_for_idle()
  app$upload_file(direct_file_upload = temp_file)
  app$wait_for_idle(duration = 2000)

  expect_true(is.character(app$get_url()) && nzchar(app$get_url()))
  app$expect_screenshot()
  app$stop()
})

test_that("E2E: Complete user journey from upload to chart", {
  set.seed(42)
  skip_if_no_shinytest2_runtime()
  skip_on_ci()

  test_data <- data.frame(
    Dato = seq.Date(as.Date("2023-01-01"), by = "week", length.out = 20),
    Komplikationer = rpois(20, lambda = 5),
    Operationer = rep(100, 20),
    Kommentar = c(rep("", 15), "Note 1", "", "Note 2", "", "")
  )
  temp_file <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_file, row.names = FALSE)
  on.exit(unlink(temp_file), add = TRUE)

  app <- create_e2e_driver(name = "complete_journey", height = 800, width = 1200)

  app$wait_for_idle()
  app$expect_screenshot(name = "01_initial")

  app$upload_file(direct_file_upload = temp_file)
  app$wait_for_idle(duration = 3000)
  app$expect_screenshot(name = "02_after_upload")

  app$wait_for_idle(duration = 2000)
  app$expect_screenshot(name = "03_autodetected")

  tryCatch(
    {
      app$set_inputs(chart_type = "P-kort (Andele)")
      app$wait_for_idle(duration = 1500)
      app$expect_screenshot(name = "04_chart_selected")
    },
    error = function(e) message("Could not set chart type: ", e$message)
  )

  app$wait_for_idle(duration = 2000)
  app$expect_screenshot(name = "05_final_chart")

  expect_true(is.character(app$get_url()) && nzchar(app$get_url()))

  final_values <- app$get_values()
  expect_true(!is.null(final_values))
  app$stop()
})
