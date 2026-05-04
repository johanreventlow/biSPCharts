# test-utils-state-accessors.R
# Rewrite Fase 2: TDD mod nuværende state accessor API
# Baseret paa R/state_management.R
#
# NOTE: Mange accessor-funktioner fra original spec eksisterer ikke i
# nuvaerende namespace. Disse er markeret SKIP med TODO pga. manglende
# implementation. Se Issue #203 for Fase 3 followup.

# =============================================================================
# KENDTE BEGRAENSNINGER I NUVAERENDE IMPLEMENTATION (dokumenteret):
#
# Kun foelgende accessor-funktioner er implementeret i namespace:
#   - create_app_state()
#   - get_current_data(app_state)
#   - set_current_data(app_state, value)
#   - set_original_data(app_state, value) [kun setter, ingen getter]
#   - update_all_column_mappings(app_state, mappings)
#   - is_plot_ready(app_state)
#
# Manglende accessors (ca. 30 funktioner) dokumenteret nedenfor.
# =============================================================================

# =============================================================================
# DATA ACCESSORS — Implementerede
# =============================================================================

test_that("create_app_state opretter valid state-struktur", {
  app_state <- create_app_state()
  # create_app_state returnerer et environment med reactiveValues-grene
  expect_true(is.environment(app_state))
  expect_true(shiny::is.reactivevalues(app_state$data))
  expect_true(shiny::is.reactivevalues(app_state$visualization))
})

test_that("get_current_data returnerer NULL ved tom state", {
  app_state <- create_app_state()
  result <- get_current_data(app_state)
  expect_null(result)
})

test_that("set_current_data og get_current_data arbejder korrekt", {
  app_state <- create_app_state()
  test_data <- data.frame(x = 1:3, y = 4:6)

  set_current_data(app_state, test_data)
  result <- get_current_data(app_state)
  expect_equal(result, test_data)
  expect_equal(nrow(result), 3)
})

test_that("set_current_data accepterer NULL", {
  app_state <- create_app_state()
  test_data <- data.frame(a = 1:5)

  set_current_data(app_state, test_data)
  set_current_data(app_state, NULL)
  expect_null(get_current_data(app_state))
})

test_that("set_original_data gemmer data i state", {
  app_state <- create_app_state()
  original <- data.frame(original_col = c("a", "b", "c"))

  set_original_data(app_state, original)
  result <- shiny::isolate(app_state$data$original_data)
  expect_equal(result, original)
})

test_that("is_plot_ready returnerer FALSE ved tom state", {
  app_state <- create_app_state()
  expect_false(is_plot_ready(app_state))
})

test_that("is_plot_ready returnerer TRUE naar visualization$plot_ready er sat", {
  app_state <- create_app_state()
  # is_plot_ready checker app_state$visualization$plot_ready, ikke data
  shiny::isolate(app_state$visualization$plot_ready <- TRUE)
  expect_true(is_plot_ready(app_state))
})

test_that("update_all_column_mappings opdaterer mappings i state", {
  app_state <- create_app_state()

  mappings <- list(
    x_column = "Dato",
    y_column = "Vaerdi"
  )

  # Maa ikke kaste fejl
  expect_no_error(update_all_column_mappings(app_state, mappings))
})

test_that("accessors kan kaldes uden fejl udenfor reaktiv kontekst", {
  app_state <- create_app_state()
  test_data <- data.frame(x = 1:5)

  expect_silent({
    set_current_data(app_state, test_data)
    result <- get_current_data(app_state)
  })
  expect_equal(result, test_data)
})

# =============================================================================
# DATA ACCESSORS — Fase 3 implementerede (skip fjernet)
# =============================================================================

test_that("get_original_data getter eksisterer", {
  app_state <- create_app_state()
  original <- data.frame(original_col = c("a", "b", "c"))
  set_original_data(app_state, original)
  result <- get_original_data(app_state)
  expect_equal(result, original)
})

test_that("is_table_updating og set_table_updating eksisterer", {
  app_state <- create_app_state()
  expect_false(is_table_updating(app_state))
  set_table_updating(app_state, TRUE)
  expect_true(is_table_updating(app_state))
})

test_that("get_autodetect_status returnerer korrekt struktur", {
  app_state <- create_app_state()
  status <- get_autodetect_status(app_state)
  expect_type(status, "list")
  expect_named(status, c("in_progress", "completed", "results", "frozen"))
})

test_that("set_autodetect_in_progress eksisterer", {
  app_state <- create_app_state()
  set_autodetect_in_progress(app_state, TRUE)
  expect_true(shiny::isolate(app_state$columns$auto_detect$in_progress))
})

test_that("get_column_mappings og get_column_mapping eksisterer", {
  app_state <- create_app_state()
  mappings <- get_column_mappings(app_state)
  expect_type(mappings, "list")
  expect_null(get_column_mapping(app_state, "x_column"))
})

test_that("update_column_mapping eksisterer (singular)", {
  app_state <- create_app_state()
  update_column_mapping(app_state, "x_column", "Dato")
  expect_equal(get_column_mapping(app_state, "x_column"), "Dato")
})

test_that("set_plot_ready eksisterer", {
  app_state <- create_app_state()
  set_plot_ready(app_state, TRUE)
  expect_true(is_plot_ready(app_state))
})

test_that("get_plot_warnings og set_plot_warnings eksisterer", {
  app_state <- create_app_state()
  expect_equal(get_plot_warnings(app_state), character(0))
  set_plot_warnings(app_state, c("Advarsel 1"))
  expect_equal(get_plot_warnings(app_state), c("Advarsel 1"))
})

test_that("get_plot_object og set_plot_object eksisterer", {
  app_state <- create_app_state()
  expect_null(get_plot_object(app_state))
  mock_plot <- structure(list(), class = "gg")
  set_plot_object(app_state, mock_plot)
  expect_s3_class(get_plot_object(app_state), "gg")
})

test_that("is_plot_generating og set_plot_generating eksisterer", {
  app_state <- create_app_state()
  expect_false(is_plot_generating(app_state))
  set_plot_generating(app_state, TRUE)
  expect_true(is_plot_generating(app_state))
})

test_that("is_file_uploaded og set_file_uploaded eksisterer", {
  app_state <- create_app_state()
  expect_false(is_file_uploaded(app_state))
  set_file_uploaded(app_state, TRUE)
  expect_true(is_file_uploaded(app_state))
})

test_that("is_user_session_started og set_user_session_started eksisterer", {
  app_state <- create_app_state()
  expect_false(is_user_session_started(app_state))
  set_user_session_started(app_state, TRUE)
  expect_true(is_user_session_started(app_state))
})

test_that("get_last_error, set_last_error og get_error_count eksisterer", {
  app_state <- create_app_state()
  expect_null(get_last_error(app_state))
  expect_equal(get_error_count(app_state), 0L)
  err1 <- list(type = "validation", message = "fejl")
  set_last_error(app_state, err1)
  expect_equal(get_error_count(app_state), 1L)
  expect_equal(get_last_error(app_state), err1)
})

test_that("set_last_error fylder error_history med FIFO-cap (max 10)", {
  app_state <- create_app_state()
  expect_equal(length(get_error_history(app_state)), 0L)

  for (i in seq_len(12)) {
    set_last_error(app_state, list(type = "test", index = i))
  }

  history <- get_error_history(app_state)
  expect_equal(length(history), 10L)
  # Oldest two evicted (i=1 og i=2), nyeste = i=12
  expect_equal(history[[1]]$index, 3L)
  expect_equal(history[[10]]$index, 12L)
  expect_equal(get_error_count(app_state), 12L)
  expect_equal(get_last_error(app_state)$index, 12L)
})

test_that("H1: nye session-accessors (#447) eksisterer og returnerer defaults", {
  app_state <- create_app_state()

  # autogen_active
  expect_false(is_autogen_active(app_state))
  set_autogen_active(app_state, TRUE)
  expect_true(is_autogen_active(app_state))
  set_autogen_active(app_state, FALSE)
  expect_false(is_autogen_active(app_state))

  # has_data_status
  expect_equal(get_has_data_status(app_state), "false")
  set_has_data_status(app_state, "true")
  expect_equal(get_has_data_status(app_state), "true")

  # last_save_time
  expect_null(get_last_save_time(app_state))
  fixed_time <- as.POSIXct("2026-05-03 09:00:00", tz = "UTC")
  set_last_save_time(app_state, fixed_time)
  expect_equal(get_last_save_time(app_state), fixed_time)

  # auto_save_enabled (default TRUE)
  expect_true(is_auto_save_enabled(app_state))
  set_auto_save_enabled(app_state, FALSE)
  expect_false(is_auto_save_enabled(app_state))

  # last_upload_time
  expect_null(get_last_upload_time(app_state))
  set_last_upload_time(app_state, fixed_time)
  expect_equal(get_last_upload_time(app_state), fixed_time)
})

test_that("H1: set_module_data_cache (#447) opdaterer atomisk", {
  app_state <- create_app_state()
  test_data <- data.frame(x = 1:3, y = 4:6)

  set_module_data_cache(app_state, test_data)
  expect_equal(shiny::isolate(app_state$visualization$module_data_cache), test_data)
  expect_equal(shiny::isolate(app_state$visualization$module_cached_data), test_data)

  set_module_data_cache(app_state, NULL)
  expect_null(shiny::isolate(app_state$visualization$module_data_cache))
  expect_null(shiny::isolate(app_state$visualization$module_cached_data))
})

test_that("H1: set_table_op_cleanup_needed (#447) eksisterer", {
  app_state <- create_app_state()
  set_table_op_cleanup_needed(app_state, TRUE)
  expect_true(shiny::isolate(app_state$data$table_operation_cleanup_needed))
  set_table_op_cleanup_needed(app_state, FALSE)
  expect_false(shiny::isolate(app_state$data$table_operation_cleanup_needed))
})

test_that("recovery-attempts og last_recovery_time accessors eksisterer", {
  app_state <- create_app_state()
  expect_equal(get_recovery_attempts(app_state), 0L)
  expect_null(get_last_recovery_time(app_state))

  increment_recovery_attempts(app_state)
  increment_recovery_attempts(app_state)
  expect_equal(get_recovery_attempts(app_state), 2L)

  fixed_time <- as.POSIXct("2026-05-03 12:00:00", tz = "UTC")
  set_last_recovery_time(app_state, fixed_time)
  expect_equal(get_last_recovery_time(app_state), fixed_time)
})

test_that("is_test_mode_enabled og set_test_mode_enabled eksisterer", {
  app_state <- create_app_state()
  expect_false(is_test_mode_enabled(app_state))
  set_test_mode_enabled(app_state, TRUE)
  expect_true(is_test_mode_enabled(app_state))
})

test_that("get_test_mode_startup_phase og set_test_mode_startup_phase eksisterer", {
  app_state <- create_app_state()
  expect_equal(get_test_mode_startup_phase(app_state), "initializing")
  set_test_mode_startup_phase(app_state, "data_ready")
  expect_equal(get_test_mode_startup_phase(app_state), "data_ready")
})

test_that("is_anhoej_rules_hidden og set_anhoej_rules_hidden eksisterer", {
  app_state <- create_app_state()
  expect_false(is_anhoej_rules_hidden(app_state))
  set_anhoej_rules_hidden(app_state, TRUE)
  expect_true(is_anhoej_rules_hidden(app_state))
})

test_that("is_y_axis_autoset_done og set_y_axis_autoset_done eksisterer", {
  app_state <- create_app_state()
  expect_false(is_y_axis_autoset_done(app_state))
  set_y_axis_autoset_done(app_state, TRUE)
  expect_true(is_y_axis_autoset_done(app_state))
})
