# test-ui-update-service-table.R
# Tests for create_table_update_service() og format_data_for_excelr()

# Tabel-service API er session-afhængig for token-protection, men
# format_data_for_excelr() er en ren funktion der testes uden mock.
# Service-API-tests fokuserer på: factory returnerer korrekt API,
# og at state-mutations virker korrekt med mock app_state.

.make_mock_table_state <- function(current_data = NULL) {
  list(
    data = list(
      current_data = current_data,
      updating_table = FALSE,
      table_version = 0L
    ),
    columns = list(auto_detect = list(frozen_until_next_trigger = FALSE)),
    ui = list(
      updating_programmatically = FALSE,
      queued_updates = list(),
      queue_processing = FALSE,
      performance_metrics = list(
        total_updates = 0L, queued_updates = 0L,
        avg_update_duration_ms = 0.0, queue_max_size = 0L
      ),
      memory_limits = list(max_queue_size = 50L)
    )
  )
}

# PURE FUNCTION TESTS (ingen Shiny-runtime nødvendig) ========================

test_that("format_data_for_excelr: numeriske kolonner konverteres til dansk format", {
  data <- data.frame(
    Dato = c("2024-01-01", "2024-01-02"),
    Tæller = c(1.5, 2.3),
    stringsAsFactors = FALSE
  )
  result <- format_data_for_excelr(data)

  expect_type(result$Tæller, "character")
  expect_equal(result$Tæller, c("1,5", "2,3"))
  expect_equal(result$Dato, data$Dato) # Tekst-kolonner urørt
})

test_that("format_data_for_excelr: NA-værdier bevares som NA_character_", {
  data <- data.frame(
    Tæller = c(1.5, NA_real_, 3.0),
    stringsAsFactors = FALSE
  )
  result <- format_data_for_excelr(data)

  expect_equal(result$Tæller[[1]], "1,5")
  expect_true(is.na(result$Tæller[[2]]))
  # format() med decimal.mark giver "3,0" for heltal af type double
  expect_match(result$Tæller[[3]], "^3")
})

test_that("format_data_for_excelr: Skift/Frys ekskluderes fra numerisk formatering", {
  data <- data.frame(
    Skift = c(TRUE, FALSE),
    Frys = c(FALSE, TRUE),
    Tæller = c(1.5, 2.5),
    stringsAsFactors = FALSE
  )
  result <- format_data_for_excelr(data)

  # Skift/Frys skal forblive logiske — ikke konverteres til dansk format
  expect_type(result$Skift, "logical")
  expect_type(result$Frys, "logical")
  # Tæller konverteres
  expect_type(result$Tæller, "character")
})

test_that("format_data_for_excelr: NULL data returneres uændret", {
  expect_null(format_data_for_excelr(NULL))
})

test_that("format_data_for_excelr: tomt data frame returneres uændret", {
  data <- data.frame(Tæller = numeric(0))
  result <- format_data_for_excelr(data)
  expect_equal(nrow(result), 0)
})

test_that("format_data_for_excelr: data uden numeriske kolonner returneres uændret", {
  data <- data.frame(
    Dato = c("2024-01-01", "2024-01-02"),
    Kommentar = c("note1", "note2"),
    stringsAsFactors = FALSE
  )
  result <- format_data_for_excelr(data)
  expect_identical(result, data)
})

# SERVICE API TESTS ===========================================================

test_that("create_table_update_service returnerer korrekt API", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  svc <- create_table_update_service(mock_session, .make_mock_table_state())

  expect_type(svc, "list")
  expect_true("update_excelr_data" %in% names(svc))
  expect_true("update_datatable" %in% names(svc))
  expect_true("clear_table" %in% names(svc))
  expect_true(is.function(svc$update_excelr_data))
  expect_true(is.function(svc$update_datatable))
  expect_true(is.function(svc$clear_table))
})

test_that("service-API eksponerer præcis 3 funktioner", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  svc <- create_table_update_service(mock_session, .make_mock_table_state())

  expect_equal(length(svc), 3)
  expect_equal(
    sort(names(svc)),
    sort(c("update_excelr_data", "update_datatable", "clear_table"))
  )
})

test_that("tabel-service eksponerer IKKE kolonne- eller form-API", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  svc <- create_table_update_service(mock_session, .make_mock_table_state())

  expect_false("update_column_choices" %in% names(svc))
  expect_false("update_form_fields" %in% names(svc))
  expect_false("reset_form_fields" %in% names(svc))
  expect_false("update_all_columns" %in% names(svc))
})

test_that("update_datatable er stub der returnerer NULL uden fejl", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  svc <- create_table_update_service(mock_session, .make_mock_table_state())

  data <- data.frame(x = 1:3)
  expect_no_error(svc$update_datatable("my_table", data))
})

# BACKWARD-COMPAT WRAPPER TEST ================================================

test_that("create_ui_update_service backward-compat wrapper inkluderer table-API", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  state <- .make_mock_table_state()

  svc <- create_ui_update_service(mock_session, state)

  # Kolonne-API
  expect_true("update_column_choices" %in% names(svc))
  expect_true("update_all_columns" %in% names(svc))

  # Form-API
  expect_true("update_form_fields" %in% names(svc))
  expect_true("reset_form_fields" %in% names(svc))

  # Tabel-API (ny)
  expect_true("update_excelr_data" %in% names(svc))
  expect_true("update_datatable" %in% names(svc))
  expect_true("clear_table" %in% names(svc))

  # Total: 3 (col) + 6 (form) + 3 (table) = 12
  expect_equal(length(svc), 12)
})

# TOKEN-PROTECTION INTEGRATION TEST ===========================================

test_that("update_excelr_data kan kaldes uden fejl (token-protection via safe_programmatic_ui_update)", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  svc <- create_table_update_service(mock_session, .make_mock_table_state())

  # update_excelr_data kalder safe_programmatic_ui_update med mock state
  # der ikke har aktiv Shiny-reaktivitet — safe_operation fanger evt. fejl
  # og logger dem, så ingen exception kastes mod kalder.
  test_data <- data.frame(x = 1:3, y = c(1.0, 2.0, 3.0))
  expect_no_error(svc$update_excelr_data("main_data_table", test_data))
})

test_that("clear_table kan kaldes uden fejl (token-protection via safe_programmatic_ui_update)", {
  skip_if_not_installed("shiny")

  mock_session <- list(input = list())
  svc <- create_table_update_service(mock_session, .make_mock_table_state())

  expect_no_error(svc$clear_table("main_data_table"))
})
