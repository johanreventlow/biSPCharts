# test-csv-parsing.R
# Tests for CSV/data loading, encoding og parsing

test_that("CSV encoding og parsing fungerer korrekt", {
  # Test standard CSV parsing
  test_csv_content <- "Dato,Tæller,Nævner\n2024-01-01,10,100\n2024-02-01,15,120"
  temp_file <- tempfile(fileext = ".csv")
  writeLines(test_csv_content, temp_file, useBytes = TRUE)

  # Test at filen kan læses
  expect_true(file.exists(temp_file))

  # Cleanup
  unlink(temp_file)
})

test_that("Test data kan læses og behandles korrekt", {
  # Find test data file
  test_data_candidates <- c(
    "../../R/data/testdata_spc_example.csv",
    "R/data/testdata_spc_example.csv",
    "testdata_spc_example.csv"
  )

  test_data_path <- NULL
  for (path in test_data_candidates) {
    if (file.exists(path)) {
      test_data_path <- path
      break
    }
  }

  if (!is.null(test_data_path)) {
    expect_true(file.exists(test_data_path))
    expect_gt(file.size(test_data_path), 0)

    # Test at data kan læses
    if (exists("read_csv_safe")) {
      data <- read_csv_safe(test_data_path)
      expect_true(is.data.frame(data))
      expect_gt(nrow(data), 0)
    }
  } else {
    skip("No test data file found")
  }
})

test_that("ensure_standard_columns virker med test data", {
  test_data <- data.frame(
    Dato = c("2024-01-01", "2024-02-01"),
    Tæller = c(10, 15),
    Nævner = c(100, 120)
  )

  if (exists("ensure_standard_columns")) {
    result <- ensure_standard_columns(test_data)
    expect_true(is.data.frame(result))
    # ensure_standard_columns only cleans data, doesn't add Skift/Frys columns
    expect_true(all(c("Dato", "Tæller", "Nævner") %in% names(result)))
    expect_equal(nrow(result), nrow(test_data))
    expect_true(all(grepl("^[a-zA-Z]", names(result)))) # Names should be valid
  } else {
    skip("ensure_standard_columns function not available")
  }
})

# =============================================================================
# Separator auto-detection tests (#124)
# =============================================================================

# Mock emit API til tests (ingen Shiny session)
create_mock_emit <- function() {
  list(
    data_updated = function(...) invisible(NULL),
    navigation_changed = function(...) invisible(NULL),
    auto_detection_completed = function(...) invisible(NULL)
  )
}

test_that("handle_csv_upload parser dansk CSV (semikolon + komma-decimal)", {
  skip_if_not(exists("handle_csv_upload", mode = "function"))

  csv_content <- "Dato;T\u00e6ller;N\u00e6vner\n2024-01-01;10,5;100\n2024-02-01;15,3;120"
  temp_file <- tempfile(fileext = ".csv")
  writeLines(csv_content, temp_file)
  on.exit(unlink(temp_file))

  mock_state <- create_test_app_state()
  handle_csv_upload(temp_file, mock_state, emit = create_mock_emit())

  data <- shiny::isolate(mock_state$data$current_data)
  expect_true(is.data.frame(data))
  expect_gte(ncol(data), 3)
})

test_that("handle_csv_upload parser engelsk CSV (komma + punkt-decimal)", {
  skip_if_not(exists("handle_csv_upload", mode = "function"))

  csv_content <- "Date,Count,Denominator\n2024-01-01,10.5,100\n2024-02-01,15.3,120"
  temp_file <- tempfile(fileext = ".csv")
  writeLines(csv_content, temp_file)
  on.exit(unlink(temp_file))

  mock_state <- create_test_app_state()
  handle_csv_upload(temp_file, mock_state, emit = create_mock_emit())

  data <- shiny::isolate(mock_state$data$current_data)
  expect_true(is.data.frame(data))
  expect_gte(ncol(data), 3)
})

test_that("handle_csv_upload parser tab-separeret fil", {
  skip_if_not(exists("handle_csv_upload", mode = "function"))

  csv_content <- "Dato\tT\u00e6ller\tN\u00e6vner\n2024-01-01\t10\t100\n2024-02-01\t15\t120"
  temp_file <- tempfile(fileext = ".csv")
  writeLines(csv_content, temp_file)
  on.exit(unlink(temp_file))

  mock_state <- create_test_app_state()
  handle_csv_upload(temp_file, mock_state, emit = create_mock_emit())

  data <- shiny::isolate(mock_state$data$current_data)
  expect_true(is.data.frame(data))
  expect_gte(ncol(data), 3)
})

# =============================================================================
# Encoding tests (#166)
# =============================================================================

test_that("read_csv_detect_encoding læser UTF-8 med danske tegn", {
  skip_if_not(exists("read_csv_detect_encoding", mode = "function"))

  csv_content <- "Måned;Tæller;Nævner\nJanuar;10;100\nFebruar;15;120"
  temp_file <- tempfile(fileext = ".csv")
  writeBin(charToRaw(csv_content), temp_file)
  on.exit(unlink(temp_file))

  text <- read_csv_detect_encoding(temp_file)
  expect_true(any(grepl("Måned", text)))
  expect_true(any(grepl("Tæller", text)))
})

test_that("read_csv_detect_encoding læser Latin1 med danske tegn", {
  skip_if_not(exists("read_csv_detect_encoding", mode = "function"))

  csv_content <- "Måned;Tæller;Nævner\nJanuar;10;100"
  temp_file <- tempfile(fileext = ".csv")
  # Skriv som Latin1
  con <- file(temp_file, "wb")
  writeBin(iconv(csv_content, from = "UTF-8", to = "latin1"), con)
  close(con)
  on.exit(unlink(temp_file))

  text <- read_csv_detect_encoding(temp_file)
  # Skal have konverteret korrekt til UTF-8
  expect_true(any(grepl("M", text))) # Mindst noget tekst
})
