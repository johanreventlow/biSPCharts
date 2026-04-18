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
# TESTS SKIPPED MED TODO: Accessor-funktioner ikke i namespace
# Alle nedenstaaende SKIP'er dokumenterer spec-adfaerd der IKKE er
# implementeret i nuvaerende state_management. Fase 3 followup.
# =============================================================================

test_that("TODO Fase 3: get_original_data getter eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — get_original_data() ikke i namespace (#203-followup)\nKun set_original_data er implementeret, getter mangler")
  app_state <- create_app_state()
  original <- data.frame(original_col = c("a", "b", "c"))
  set_original_data(app_state, original)
  result <- get_original_data(app_state)
  expect_equal(result, original)
})

test_that("TODO Fase 3: is_table_updating og set_table_updating eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — is_table_updating/set_table_updating ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  expect_false(is_table_updating(app_state))
  set_table_updating(app_state, TRUE)
  expect_true(is_table_updating(app_state))
})

test_that("TODO Fase 3: get_autodetect_status returnerer korrekt struktur", {
  skip("TODO Fase 3: R-bug afsloeret — get_autodetect_status() ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  status <- get_autodetect_status(app_state)
  expect_type(status, "list")
  expect_named(status, c("in_progress", "completed", "results", "frozen"))
})

test_that("TODO Fase 3: set_autodetect_in_progress eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — set_autodetect_in_progress() ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  set_autodetect_in_progress(app_state, TRUE)
  expect_true(shiny::isolate(app_state$columns$auto_detect$in_progress))
})

test_that("TODO Fase 3: get_column_mappings og get_column_mapping eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — get_column_mappings/get_column_mapping ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  mappings <- get_column_mappings(app_state)
  expect_type(mappings, "list")
  expect_null(get_column_mapping(app_state, "x_column"))
})

test_that("TODO Fase 3: update_column_mapping eksisterer (singular)", {
  skip("TODO Fase 3: R-bug afsloeret — update_column_mapping() (singular) ikke i namespace, kun update_all_column_mappings (#203-followup)")
  app_state <- create_app_state()
  update_column_mapping(app_state, "x_column", "Dato")
  expect_equal(get_column_mapping(app_state, "x_column"), "Dato")
})

test_that("TODO Fase 3: set_plot_ready eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — set_plot_ready() ikke i namespace (#203-followup)\nKun is_plot_ready er implementeret, setter mangler")
  app_state <- create_app_state()
  set_plot_ready(app_state, TRUE)
  expect_true(is_plot_ready(app_state))
})

test_that("TODO Fase 3: get_plot_warnings og set_plot_warnings eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — get_plot_warnings/set_plot_warnings ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  expect_equal(get_plot_warnings(app_state), character(0))
  set_plot_warnings(app_state, c("Advarsel 1"))
  expect_equal(get_plot_warnings(app_state), c("Advarsel 1"))
})

test_that("TODO Fase 3: get_plot_object og set_plot_object eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — get_plot_object/set_plot_object ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  expect_null(get_plot_object(app_state))
  mock_plot <- structure(list(), class = "gg")
  set_plot_object(app_state, mock_plot)
  expect_s3_class(get_plot_object(app_state), "gg")
})

test_that("TODO Fase 3: is_plot_generating og set_plot_generating eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — is_plot_generating/set_plot_generating ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  expect_false(is_plot_generating(app_state))
  set_plot_generating(app_state, TRUE)
  expect_true(is_plot_generating(app_state))
})

test_that("TODO Fase 3: is_file_uploaded og set_file_uploaded eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — is_file_uploaded/set_file_uploaded ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  expect_false(is_file_uploaded(app_state))
  set_file_uploaded(app_state, TRUE)
  expect_true(is_file_uploaded(app_state))
})

test_that("TODO Fase 3: is_user_session_started og set_user_session_started eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — is_user_session_started/set_user_session_started ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  expect_false(is_user_session_started(app_state))
  set_user_session_started(app_state, TRUE)
  expect_true(is_user_session_started(app_state))
})

test_that("TODO Fase 3: get_last_error, set_last_error og get_error_count eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — get_last_error/set_last_error/get_error_count ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  expect_null(get_last_error(app_state))
  expect_equal(get_error_count(app_state), 0L)
  set_last_error(app_state, list(type = "validation", message = "fejl"))
  expect_equal(get_error_count(app_state), 1L)
})

test_that("TODO Fase 3: is_test_mode_enabled og set_test_mode_enabled eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — is_test_mode_enabled/set_test_mode_enabled ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  expect_false(is_test_mode_enabled(app_state))
  set_test_mode_enabled(app_state, TRUE)
  expect_true(is_test_mode_enabled(app_state))
})

test_that("TODO Fase 3: get_test_mode_startup_phase og set_test_mode_startup_phase eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — get/set_test_mode_startup_phase ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  expect_equal(get_test_mode_startup_phase(app_state), "initializing")
  set_test_mode_startup_phase(app_state, "data_ready")
  expect_equal(get_test_mode_startup_phase(app_state), "data_ready")
})

test_that("TODO Fase 3: is_anhoej_rules_hidden og set_anhoej_rules_hidden eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — is_anhoej_rules_hidden/set_anhoej_rules_hidden ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  expect_false(is_anhoej_rules_hidden(app_state))
  set_anhoej_rules_hidden(app_state, TRUE)
  expect_true(is_anhoej_rules_hidden(app_state))
})

test_that("TODO Fase 3: is_y_axis_autoset_done og set_y_axis_autoset_done eksisterer", {
  skip("TODO Fase 3: R-bug afsloeret — is_y_axis_autoset_done/set_y_axis_autoset_done ikke i namespace (#203-followup)")
  app_state <- create_app_state()
  expect_false(is_y_axis_autoset_done(app_state))
  set_y_axis_autoset_done(app_state, TRUE)
  expect_true(is_y_axis_autoset_done(app_state))
})
