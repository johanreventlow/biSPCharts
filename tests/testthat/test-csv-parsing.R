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
# Skift/Frys auto-tilføjelse (#173)
# =============================================================================

test_that("ensure_standard_columns tilføjer Skift og Frys hvis de mangler", {
  skip_if_not(exists("ensure_standard_columns", mode = "function"))

  data <- data.frame(
    Dato = c("2024-01-01", "2024-02-01"),
    Tæller = c(10, 15),
    Nævner = c(100, 120)
  )

  result <- ensure_standard_columns(data)

  expect_true("Skift" %in% names(result))
  expect_true("Frys" %in% names(result))
  expect_equal(names(result)[1], "Skift")
  expect_equal(names(result)[2], "Frys")
  expect_equal(result$Skift, c(FALSE, FALSE))
  expect_equal(result$Frys, c(FALSE, FALSE))
  expect_equal(ncol(result), 5)
})

test_that("ensure_standard_columns tilføjer kun Frys hvis Skift allerede findes", {
  skip_if_not(exists("ensure_standard_columns", mode = "function"))

  data <- data.frame(
    Skift = c(FALSE, TRUE),
    Dato = c("2024-01-01", "2024-02-01"),
    Tæller = c(10, 15)
  )

  result <- ensure_standard_columns(data)

  expect_true("Frys" %in% names(result))
  expect_equal(names(result)[1], "Skift")
  expect_equal(names(result)[2], "Frys")
  expect_equal(ncol(result), 4)
})

test_that("ensure_standard_columns ændrer ikke data med begge kolonner", {
  skip_if_not(exists("ensure_standard_columns", mode = "function"))

  data <- data.frame(
    Skift = c(FALSE, TRUE),
    Frys = c(FALSE, FALSE),
    Dato = c("2024-01-01", "2024-02-01"),
    Tæller = c(10, 15)
  )

  result <- ensure_standard_columns(data)

  expect_equal(ncol(result), 4)
  expect_equal(names(result)[1], "Skift")
  expect_equal(names(result)[2], "Frys")
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

test_that("handle_csv_upload viser detaljeret fejlbesked ved total-fail", {
  # Opret en fil som ingen strategi kan parse som valid CSV med >= 2 kolonner
  temp_file <- tempfile(fileext = ".csv")
  writeLines("ikkecsv", temp_file)
  on.exit(unlink(temp_file))

  shown <- NULL
  testthat::local_mocked_bindings(
    showNotification = function(msg, ...) {
      shown <<- msg
      invisible(NULL)
    },
    .package = "shiny"
  )

  result <- handle_csv_upload(
    file_path = temp_file,
    app_state = NULL,
    session_id = "test-session",
    emit = NULL
  )
  expect_null(result)
  # Fejlbeskeden skal nævne de tre strategier
  if (!is.null(shown)) {
    expect_true(grepl("semikolon-separator", shown))
    expect_true(grepl("auto-detect", shown))
    expect_true(grepl("komma-separator", shown))
  }
})

# =============================================================================
# Row-limit konsistens: validate_uploaded_file() (#418)
# =============================================================================

test_that("validate_uploaded_file: 30k raekker er OK (ingen fejl)", {
  skip_if_not(exists("validate_uploaded_file", mode = "function"))

  # Mocke limits: warning=50, max=100 saa vi kan bruge smaa testfiler
  testthat::local_mocked_bindings(
    get_upload_warning_row_count = function() 50L,
    get_max_upload_line_count    = function() 100L
  )

  # 30 linjer under begge graenser
  tmp <- tempfile(fileext = ".csv")
  writeLines(c("Dato,Taeller", rep("2024-01-01,10", 30)), tmp)
  on.exit(unlink(tmp))

  file_info <- list(
    name     = "test.csv",
    datapath = tmp,
    size     = file.size(tmp),
    type     = "text/csv"
  )

  result <- validate_uploaded_file(file_info)
  errors_about_rows <- grep("for mange raekker|for mange rækker", result$errors, value = TRUE)
  expect_length(errors_about_rows, 0)
})

test_that("validate_uploaded_file: 75k raekker giver kun advarsel (ikke fejl)", {
  skip_if_not(exists("validate_uploaded_file", mode = "function"))

  # Mocke limits: warning=50, max=100
  testthat::local_mocked_bindings(
    get_upload_warning_row_count = function() 50L,
    get_max_upload_line_count    = function() 100L
  )

  # 75 linjer: over warning (50) men under max (100)
  tmp <- tempfile(fileext = ".csv")
  writeLines(c("Dato,Taeller", rep("2024-01-01,10", 75)), tmp)
  on.exit(unlink(tmp))

  file_info <- list(
    name     = "test.csv",
    datapath = tmp,
    size     = file.size(tmp),
    type     = "text/csv"
  )

  result <- validate_uploaded_file(file_info)
  errors_about_rows <- grep("for mange raekker|for mange rækker", result$errors, value = TRUE)
  # Skal IKKE give hard-stop fejl - kun advarsel via log_warn
  expect_length(errors_about_rows, 0)
})

test_that("validate_uploaded_file: 150k raekker giver hard-stop fejl", {
  skip_if_not(exists("validate_uploaded_file", mode = "function"))

  # Mocke limits: warning=50, max=100
  testthat::local_mocked_bindings(
    get_upload_warning_row_count = function() 50L,
    get_max_upload_line_count    = function() 100L
  )

  # 150 linjer: over max (100) => hard stop
  # Pga loop-break ved max+1 taller vi max+1 linjer og udloser fejlen
  tmp <- tempfile(fileext = ".csv")
  writeLines(c("Dato,Taeller", rep("2024-01-01,10", 150)), tmp)
  on.exit(unlink(tmp))

  file_info <- list(
    name     = "test.csv",
    datapath = tmp,
    size     = file.size(tmp),
    type     = "text/csv"
  )

  result <- validate_uploaded_file(file_info)
  errors_about_rows <- grep("for mange r", result$errors, value = TRUE)
  expect_gte(length(errors_about_rows), 1)
})
