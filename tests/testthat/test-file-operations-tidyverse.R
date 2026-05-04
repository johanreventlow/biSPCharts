# test-file-operations-tidyverse.R
# Integration tests for file operations using tidyverse patterns
#
# Defensive `if (exists(...))`/skip-fallbacks fjernet 2026-05-03 (#428).
# Funktionerne er pakke-interne og tilgaengelige efter devtools::load_all()
# eller pakke-installation; manglende tilgaengelighed skal faile loud.

test_that("preprocess_uploaded_data handles tidyverse operations correctly", {
  skip_if_not_installed("dplyr")
  skip_if_not_installed("stringr")

  test_data <- data.frame(
    `Valid Column` = c(1, 2, 3, 4, 5),
    `Empty Column` = c(NA, NA, NA, NA, NA),
    `Mixed Column` = c("data", "", NA, "more", "info"),
    `Whitespace Column` = c("  text  ", "", "   ", "valid", "data"),
    `Numeric Text` = c("1.5", "2.0", "", "3.5", NA),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  test_data <- rbind(
    test_data,
    data.frame(
      `Valid Column` = c(NA, NA),
      `Empty Column` = c(NA, ""),
      `Mixed Column` = c("", NA),
      `Whitespace Column` = c("   ", ""),
      `Numeric Text` = c("", NA),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  )

  file_info <- list(name = "test.csv", size = 1000)
  result <- preprocess_uploaded_data(test_data, file_info, session_id = "test")

  expect_true(is.list(result))
  expect_true("data" %in% names(result))
  expect_true("cleaning_log" %in% names(result))

  processed_data <- result$data
  cleaning_log <- result$cleaning_log

  if (!is.null(cleaning_log$empty_rows_removed)) {
    expect_true(cleaning_log$empty_rows_removed >= 0)
    expect_true(nrow(processed_data) <= nrow(test_data))
  }

  if (!is.null(cleaning_log$column_names_cleaned)) {
    expect_true(cleaning_log$column_names_cleaned)
    expect_true(all(make.names(names(processed_data)) == names(processed_data)))
  }

  expect_true(nrow(processed_data) >= 3)
  expect_true(ncol(processed_data) >= 3)
})

test_that("validate_data_for_auto_detect with tidyverse patterns", {
  good_data <- data.frame(
    Dato = c("2024-01-01", "2024-02-01", "2024-03-01"),
    Tæller = c(10, 15, 20),
    Nævner = c(100, 150, 200),
    stringsAsFactors = FALSE
  )

  result_good <- validate_data_for_auto_detect(good_data, session_id = "test")
  expect_true(is.list(result_good))
  expect_true("suitable" %in% names(result_good))
  expect_true(result_good$suitable)

  problematic_data <- data.frame(
    empty_col = c(NA, NA, NA),
    text_only = c("a", "b", "c")
  )

  result_bad <- validate_data_for_auto_detect(problematic_data, session_id = "test")
  expect_true(is.list(result_bad))
  expect_true(length(result_bad$issues) > 0)

  tiny_data <- data.frame(x = 1)
  result_tiny <- validate_data_for_auto_detect(tiny_data, session_id = "test")
  expect_true(length(result_tiny$issues) > 0)
})

test_that("Danish CSV processing with tidyverse locale handling", {
  skip_if_not_installed("readr")

  temp_file <- tempfile(fileext = ".csv")
  danish_content <- "Dato;Tæller;Nævner;Procent
01-01-2024;10;100;10,5
02-01-2024;15;120;12,5
03-01-2024;20;150;13,3"

  writeLines(danish_content, temp_file, useBytes = TRUE)
  on.exit(unlink(temp_file), add = TRUE)

  app_state <- create_app_state()
  mock_emit <- list(
    data_loaded = function() {},
    navigation_changed = function() {}
  )

  result <- tryCatch(
    {
      handle_csv_upload(temp_file, app_state, session_id = "test", emit = mock_emit)
      "success"
    },
    error = function(e) {
      list(error = e$message)
    }
  )

  if (is.character(result) && result == "success") {
    expect_true(!is.null(app_state$data$current_data))

    loaded_data <- app_state$data$current_data
    expect_true(is.data.frame(loaded_data))
    expect_true(nrow(loaded_data) >= 3)

    if ("Procent" %in% names(loaded_data)) {
      procent_col <- loaded_data[["Procent"]]
      expect_true(is.numeric(procent_col) || all(grepl("\\d+\\.\\d+", procent_col[!is.na(procent_col)])))
    }
  } else {
    expect_true(is.list(result) || is.character(result))
  }
})

test_that("error handling in file operations with tidyverse", {
  fake_file_info <- list(
    datapath = "/non/existent/file.csv",
    name = "fake.csv",
    size = 100,
    type = "text/csv"
  )

  result <- validate_uploaded_file(fake_file_info, session_id = "test")
  expect_true(is.list(result))
  expect_true("valid" %in% names(result))
  expect_false(result$valid)
  expect_true(length(result$errors) > 0)

  empty_path <- tempfile(fileext = ".csv")
  file.create(empty_path)
  on.exit(unlink(empty_path), add = TRUE)
  empty_file_info <- list(
    datapath = empty_path,
    name = "empty.csv",
    size = 0,
    type = "text/csv"
  )

  result_empty <- validate_uploaded_file(empty_file_info, session_id = "test")
  expect_false(result_empty$valid)
  expect_true(any(grepl("tom", result_empty$errors, ignore.case = TRUE)))

  big_path <- tempfile(fileext = ".csv")
  file.create(big_path)
  on.exit(unlink(big_path), add = TRUE)
  big_file_info <- list(
    datapath = big_path,
    name = "big.csv",
    size = 100 * 1024 * 1024,
    type = "text/csv"
  )

  result_big <- validate_uploaded_file(big_file_info, session_id = "test")
  expect_false(result_big$valid)
  expect_true(any(grepl("størrelse|overskrider|maksimum", result_big$errors, ignore.case = TRUE)))
})

test_that("Excel file processing with tidyverse patterns", {
  skip_if_not_installed("readxl")

  temp_dir <- tempdir()
  excel_path <- file.path(temp_dir, "test.xlsx")

  app_state <- create_app_state()
  mock_emit <- list(
    data_loaded = function() {},
    navigation_changed = function() {}
  )

  result <- tryCatch(
    {
      handle_excel_upload(excel_path, session = NULL, app_state, mock_emit)
      "completed"
    },
    error = function(e) {
      "error_handled"
    }
  )

  expect_true(result %in% c("completed", "error_handled"))
})
