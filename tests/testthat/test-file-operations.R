# test-file-operations.R
# ==============================================================================
# COMPREHENSIVE TEST SUITE: File Operations (fct_file_operations.R)
# ==============================================================================
#
# FORMÅL: >80% coverage af file operations
# FOKUS: CSV parsing, Excel support, encodings, validation, error handling
#
# STRUKTUR:
#   1. CSV Parsing (various encodings & formats)
#   2. Excel Support (Data sheet, Data+Metadata, error cases)
#   3. File Validation (security, size limits, MIME types)
#   4. Error Handling & Recovery
#   5. Data Preprocessing & Cleaning
#
# SUCCESS CRITERIA:
#   - All encodings tested (UTF-8, ISO-8859-1, ASCII)
#   - Excel Data+Metadata restored correctly
#   - File validation catches security issues
#   - Error messages are helpful
#   - Edge cases handled gracefully
# ==============================================================================

library(shiny)
library(testthat)
library(readr)
library(readxl)

# SETUP HELPERS ================================================================

# Helper til at oprette temporary test files
create_temp_csv <- function(data, encoding = "ISO-8859-1") {
  temp_file <- tempfile(fileext = ".csv")

  # Write with Danish formatting
  readr::write_csv2(
    data,
    temp_file,
    na = ""
  )

  # Convert encoding if needed
  if (encoding != "UTF-8") {
    content <- readLines(temp_file, encoding = "UTF-8")
    writeLines(iconv(content, from = "UTF-8", to = encoding), temp_file)
  }

  return(temp_file)
}

# Helper til at oprette temporary Excel file
create_temp_excel <- function(data) {
  temp_file <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(data, temp_file)
  return(temp_file)
}

# CSV PARSING TESTS ============================================================

describe("CSV Parsing with Various Encodings", {
  it("parses Danish CSV with ISO-8859-1 encoding", {
    data <- data.frame(
      Måned = c("jan", "feb", "mar"),
      Tæller = c(10, 12, 15),
      Nævner = c(100, 100, 100),
      Kommentar = c("Første måned", "Anden måned", "Tredje måned"),
      stringsAsFactors = FALSE
    )

    csv_file <- create_temp_csv(data, encoding = "ISO-8859-1")
    on.exit(unlink(csv_file))

    # Read with Danish locale
    result <- readr::read_csv2(
      csv_file,
      locale = readr::locale(
        decimal_mark = ",",
        grouping_mark = ".",
        encoding = "ISO-8859-1"
      ),
      show_col_types = FALSE
    )

    expect_equal(nrow(result), 3)
    expect_true("Måned" %in% names(result))
    expect_true("Tæller" %in% names(result))
    expect_true("Kommentar" %in% names(result))
  })

  it("handles UTF-8 encoded CSV files", {
    data <- data.frame(
      Date = c("2024-01-01", "2024-01-02", "2024-01-03"),
      Count = c(10, 12, 15),
      Note = c("Note æøå", "Note ÆØÅ", "Note test"),
      stringsAsFactors = FALSE
    )

    csv_file <- create_temp_csv(data, encoding = "UTF-8")
    on.exit(unlink(csv_file))

    result <- readr::read_csv2(
      csv_file,
      locale = readr::locale(encoding = "UTF-8"),
      show_col_types = FALSE
    )

    expect_equal(nrow(result), 3)
    expect_true(any(grepl("æøå", result$Note)))
  })

  it("handles empty CSV files", {
    csv_file <- tempfile(fileext = ".csv")
    writeLines("", csv_file)
    on.exit(unlink(csv_file))

    expect_error(
      readr::read_csv2(csv_file, show_col_types = FALSE),
      NA # Should not error, just return empty data
    )
  })

  it("handles CSV with missing values", {
    csv_content <- "Dato;Tæller;Nævner\n2024-01-01;10;100\n2024-01-02;;100\n2024-01-03;15;"
    csv_file <- tempfile(fileext = ".csv")
    writeLines(csv_content, csv_file)
    on.exit(unlink(csv_file))

    result <- readr::read_csv2(
      csv_file,
      locale = readr::locale(encoding = "UTF-8"),
      show_col_types = FALSE
    )

    expect_equal(nrow(result), 3)
    expect_true(is.na(result$Tæller[2]))
    expect_true(is.na(result$Nævner[3]))
  })
})

# EXCEL SUPPORT TESTS ==========================================================

describe("Excel File Support", {
  it("reads simple Excel file", {
    data <- data.frame(
      Dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 3),
      Tæller = c(10, 12, 15),
      Nævner = c(100, 100, 100),
      stringsAsFactors = FALSE
    )

    excel_file <- create_temp_excel(data)
    on.exit(unlink(excel_file))

    result <- readxl::read_excel(excel_file)

    expect_equal(nrow(result), 3)
    expect_equal(ncol(result), 3)
    expect_true("Dato" %in% names(result))
  })

  it("handles Excel files with multiple sheets", {
    # Create Excel with multiple sheets (but not Data+Metadata)
    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb, "Sheet1")
    openxlsx::writeData(wb, "Sheet1", data.frame(x = 1:5))
    openxlsx::addWorksheet(wb, "Sheet2")
    openxlsx::writeData(wb, "Sheet2", data.frame(y = 1:5))

    temp_file <- tempfile(fileext = ".xlsx")
    openxlsx::saveWorkbook(wb, temp_file, overwrite = TRUE)
    on.exit(unlink(temp_file))

    sheets <- readxl::excel_sheets(temp_file)
    expect_equal(length(sheets), 2)

    # Should read first sheet by default
    result <- readxl::read_excel(temp_file)
    expect_equal(nrow(result), 5)
  })
})

# FILE VALIDATION TESTS ========================================================

describe("File Validation", {
  it("validates file path security", {
    require_internal("validate_safe_file_path", mode = "function")

    # Valid temp file
    temp_file <- tempfile()
    file.create(temp_file)
    on.exit(unlink(temp_file))

    result <- validate_safe_file_path(temp_file)
    expect_true(file.exists(result))
  })

  it("rejects path traversal attempts", {
    require_internal("validate_safe_file_path", mode = "function")

    # Path traversal attempt
    dangerous_path <- "../../../etc/passwd"

    expect_error(
      validate_safe_file_path(dangerous_path),
      "Sikkerhedsfejl"
    )
  })

  it("validates file extension", {
    require_internal("validate_file_extension", mode = "function")

    expect_true(validate_file_extension("csv"))
    expect_true(validate_file_extension("xlsx"))
    expect_true(validate_file_extension("xls"))
    expect_false(validate_file_extension("exe"))
    expect_false(validate_file_extension("sh"))
  })

  it("validates file size limits", {
    require_internal("validate_uploaded_file", mode = "function")

    # Create small test file
    temp_file <- tempfile(fileext = ".csv")
    writeLines("test,data\n1,2", temp_file)
    on.exit(unlink(temp_file))

    file_info <- list(
      name = basename(temp_file),
      size = file.info(temp_file)$size,
      type = "text/csv",
      datapath = temp_file
    )

    result <- validate_uploaded_file(file_info)
    expect_true(result$valid)
  })

  it("rejects files exceeding size limit", {
    require_internal("validate_uploaded_file", mode = "function")

    # Mock file info with excessive size
    file_info <- list(
      name = "large_file.csv",
      size = 100 * 1024 * 1024, # 100 MB
      type = "text/csv",
      datapath = tempfile()
    )

    result <- validate_uploaded_file(file_info)
    expect_false(result$valid)
    expect_true(length(result$errors) > 0)
  })
})

# COLLECT METADATA TESTS =======================================================

describe("Collect Metadata", {
  it("collect_metadata includes frys_column", {
    require_internal("collect_metadata", mode = "function")

    # Mock input med alle felter
    mock_input <- list(
      indicator_title = "Test",
      unit_type = "select",
      unit_select = "med",
      unit_custom = "",
      indicator_description = "Beskrivelse",
      x_column = "Dato",
      y_column = "Værdi",
      n_column = "Nævner",
      skift_column = "Skift",
      frys_column = "Frys",
      kommentar_column = "Kommentar",
      chart_type = "p",
      target_value = ">=90%",
      centerline_value = "68%",
      y_axis_unit = "percent"
    )

    metadata <- collect_metadata(mock_input)

    expect_equal(metadata$frys_column, "Frys")
    expect_equal(metadata$skift_column, "Skift")
    expect_equal(metadata$kommentar_column, "Kommentar")
  })

  it("roundtrips metadata through JSON (lokal session restore)", {
    require_internal("collect_metadata", mode = "function")

    # Simuler komplet metadata fra collect_metadata
    original_metadata <- list(
      x_column = "Dato",
      y_column = "Tæller",
      n_column = "Nævner",
      skift_column = "Skift",
      frys_column = "Frys",
      kommentar_column = "Kommentar",
      chart_type = "P-kort \u2014 andele/procenter (fx infektionsrate)",
      target_value = ">=90%",
      centerline_value = "68%",
      y_axis_unit = "percent"
    )

    # Roundtrip via JSON (som saveDataLocally/restore gør)
    json <- jsonlite::toJSON(original_metadata, auto_unbox = TRUE)
    restored <- jsonlite::fromJSON(json, simplifyVector = FALSE)

    # Alle felter skal overleve roundtrip
    for (field in names(original_metadata)) {
      expect_equal(restored[[field]], original_metadata[[field]],
        info = paste("Felt", field, "skal overleve JSON roundtrip")
      )
    }
  })
})

# DATA PREPROCESSING TESTS =====================================================

describe("Data Preprocessing & Cleaning", {
  it("removes empty rows", {
    require_internal("preprocess_uploaded_data", mode = "function")

    data <- data.frame(
      x = c(1, NA, 3, NA),
      y = c(2, NA, 4, NA),
      stringsAsFactors = FALSE
    )

    file_info <- list(name = "test.csv", size = 100)

    result <- preprocess_uploaded_data(data, file_info)

    # Should remove rows where all values are NA
    expect_lt(nrow(result$data), nrow(data))
    expect_true(!is.null(result$cleaning_log$empty_rows_removed))
  })

  it("cleans column names", {
    require_internal("preprocess_uploaded_data", mode = "function")

    data <- data.frame(
      `Column...1` = c(1, 2, 3),
      `Column..2` = c(4, 5, 6),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )

    file_info <- list(name = "test.csv", size = 100)

    result <- preprocess_uploaded_data(data, file_info)

    # Column names should be cleaned
    expect_true(all(!grepl("\\.\\.", names(result$data))))
  })

  it("preserves data integrity during preprocessing", {
    set.seed(42)
    require_internal("preprocess_uploaded_data", mode = "function")

    data <- data.frame(
      Dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
      Tæller = sample(40:50, 12, replace = TRUE),
      Nævner = rep(50, 12),
      stringsAsFactors = FALSE
    )

    file_info <- list(name = "test.csv", size = 100)

    result <- preprocess_uploaded_data(data, file_info)

    # Should not remove any data (no empty rows)
    expect_equal(nrow(result$data), nrow(data))
    expect_equal(ncol(result$data), ncol(data))
  })
})

# ERROR HANDLING TESTS =========================================================

describe("Error Handling & Recovery", {
  it("handles encoding errors with helpful message", {
    require_internal("handle_upload_error", mode = "function")

    error <- simpleError("invalid multibyte string")
    file_info <- list(
      name = "test.csv",
      size = 1000,
      type = "text/csv"
    )

    result <- handle_upload_error(error, file_info)

    expect_equal(result$error_type, "encoding")
    expect_true(length(result$suggestions) > 0)
  })

  it("handles permission errors with helpful message", {
    require_internal("handle_upload_error", mode = "function")

    error <- simpleError("permission denied")
    file_info <- list(
      name = "test.xlsx",
      size = 1000,
      type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )

    result <- handle_upload_error(error, file_info)

    expect_equal(result$error_type, "permission")
    expect_true(any(grepl("Luk filen", result$suggestions)))
  })

  it("handles corrupted file errors", {
    require_internal("handle_upload_error", mode = "function")

    error <- simpleError("File appears to be corrupted")
    file_info <- list(
      name = "test.xlsx",
      size = 1000,
      type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )

    result <- handle_upload_error(error, file_info)

    expect_equal(result$error_type, "corruption")
    expect_true(any(grepl("gemme filen igen", result$suggestions)))
  })
})

# DATA VALIDATION TESTS ========================================================

describe("Data Validation for Auto-Detection", {
  it("validates suitable data for auto-detection", {
    set.seed(42)
    require_internal("validate_data_for_auto_detect", mode = "function")

    data <- data.frame(
      Dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
      Tæller = sample(40:50, 12, replace = TRUE),
      Nævner = rep(50, 12),
      stringsAsFactors = FALSE
    )

    result <- validate_data_for_auto_detect(data)

    expect_true(result$suitable)
    expect_equal(length(result$issues), 0)
    expect_gte(result$validation_results$potential_date_columns, 1)
    expect_gte(result$validation_results$potential_numeric_columns, 2)
  })

  it("detects insufficient data for auto-detection", {
    require_internal("validate_data_for_auto_detect", mode = "function")

    # Only one row
    data <- data.frame(
      x = 1,
      y = 2,
      stringsAsFactors = FALSE
    )

    result <- validate_data_for_auto_detect(data)

    expect_false(result$suitable)
    expect_true(any(grepl("Too few|For f\u00e5", result$issues)))
  })

  it("detects missing column names", {
    require_internal("validate_data_for_auto_detect", mode = "function")

    data <- data.frame(
      matrix(1:9, ncol = 3)
    )
    names(data) <- c("", "col2", "")

    result <- validate_data_for_auto_detect(data)

    expect_true(result$validation_results$empty_column_names > 0)
  })
})

# EDGE CASES ===================================================================

describe("Edge Cases", {
  it("handles CSV with only headers (no data)", {
    csv_content <- "Dato;Tæller;Nævner"
    csv_file <- tempfile(fileext = ".csv")
    writeLines(csv_content, csv_file)
    on.exit(unlink(csv_file))

    result <- readr::read_csv2(
      csv_file,
      locale = readr::locale(encoding = "UTF-8"),
      show_col_types = FALSE
    )

    expect_equal(nrow(result), 0)
    expect_equal(ncol(result), 3)
  })

  it("handles CSV with inconsistent column counts", {
    csv_content <- "Dato;Tæller;Nævner\n2024-01-01;10\n2024-01-02;12;100;extra"
    csv_file <- tempfile(fileext = ".csv")
    writeLines(csv_content, csv_file)
    on.exit(unlink(csv_file))

    # readr should handle this gracefully -- forventet "parsing issues"
    # warning ved inkonsistente kolonner; vi tester at parser stadig
    # returnerer 2 rækker.
    result <- suppressWarnings(readr::read_csv2(
      csv_file,
      locale = readr::locale(encoding = "UTF-8"),
      show_col_types = FALSE
    ))

    expect_equal(nrow(result), 2)
  })

  it("handles Excel with hidden columns", {
    # Create Excel with hidden column
    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb, "Data")
    data <- data.frame(
      Visible1 = 1:5,
      Hidden = 6:10,
      Visible2 = 11:15
    )
    openxlsx::writeData(wb, "Data", data)
    openxlsx::setColWidths(wb, "Data", cols = 2, widths = 0) # Hide column

    temp_file <- tempfile(fileext = ".xlsx")
    openxlsx::saveWorkbook(wb, temp_file, overwrite = TRUE)
    on.exit(unlink(temp_file))

    # readxl should still read hidden columns
    result <- readxl::read_excel(temp_file)

    expect_equal(ncol(result), 3)
    expect_true("Hidden" %in% names(result))
  })

  it("handles Excel with formulas", {
    # Create Excel with formula
    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb, "Data")
    openxlsx::writeData(wb, "Data", data.frame(A = 1:3, B = 2:4))

    # Add formula column
    openxlsx::writeFormula(wb, "Data", x = "=A1+B1", startCol = 3, startRow = 2)
    openxlsx::writeFormula(wb, "Data", x = "=A2+B2", startCol = 3, startRow = 3)
    openxlsx::writeFormula(wb, "Data", x = "=A3+B3", startCol = 3, startRow = 4)

    temp_file <- tempfile(fileext = ".xlsx")
    openxlsx::saveWorkbook(wb, temp_file, overwrite = TRUE)
    on.exit(unlink(temp_file))

    # readxl reads calculated values, not formulas
    result <- readxl::read_excel(temp_file)

    expect_equal(ncol(result), 3)
  })

  it("handles large CSV files efficiently", {
    set.seed(42)
    skip("Performance test - run manually")

    # Create large CSV
    large_data <- data.frame(
      Dato = rep(seq.Date(as.Date("2020-01-01"), by = "day", length.out = 100), 10),
      Tæller = sample(40:50, 1000, replace = TRUE),
      Nævner = rep(50, 1000)
    )

    csv_file <- create_temp_csv(large_data)
    on.exit(unlink(csv_file))

    start_time <- Sys.time()
    result <- readr::read_csv2(
      csv_file,
      locale = readr::locale(encoding = "ISO-8859-1"),
      show_col_types = FALSE
    )
    end_time <- Sys.time()

    elapsed_ms <- as.numeric(difftime(end_time, start_time, units = "secs")) * 1000

    expect_lt(elapsed_ms, 500) # Should parse in <500ms
  })

  it("handles CSV with special characters in data", {
    data <- data.frame(
      Text = c("Quote: \"test\"", "Comma: ,test", "Semicolon: ;test"),
      Value = c(1, 2, 3),
      stringsAsFactors = FALSE
    )

    csv_file <- create_temp_csv(data)
    on.exit(unlink(csv_file))

    result <- readr::read_csv2(
      csv_file,
      locale = readr::locale(encoding = "ISO-8859-1"),
      show_col_types = FALSE
    )

    expect_equal(nrow(result), 3)
    expect_true(any(grepl("\"test\"", result$Text)))
  })
})

# SECURITY TESTS ===============================================================

describe("Security Hardening", {
  it("sanitizes CSV formula injection attempts", {
    require_internal("sanitize_csv_output", mode = "function")

    malicious_data <- data.frame(
      x = c("=SUM(A1:A10)", "@WEBSERVICE()", "-2+3", "+cmd|'/c calc'!A1"),
      y = c(1, 2, 3, 4),
      stringsAsFactors = FALSE
    )

    result <- sanitize_csv_output(malicious_data)

    # Formulas should be escaped
    expect_true(all(grepl("^'", result$x[grepl("^[=@+-]", malicious_data$x)])))
  })

  it("validates MIME type matches file extension", {
    require_internal("validate_uploaded_file", mode = "function")

    # Create CSV but claim it's Excel
    csv_file <- tempfile(fileext = ".csv")
    writeLines("test,data", csv_file)
    on.exit(unlink(csv_file))

    file_info <- list(
      name = "fake.xlsx", # Wrong extension
      size = file.info(csv_file)$size,
      type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      datapath = csv_file
    )

    result <- validate_uploaded_file(file_info)

    # Should detect mismatch
    expect_false(result$valid)
  })

  it("enforces rate limiting on uploads (#428 Fase 2)", {
    # Rate-limit-logik bor i setup_file_upload() -> observeEvent(input$data_file):
    # naar last_upload_time er sat for nylig, returnerer observeren tidligt
    # (showNotification + return()) *inden* app_state$data$updating_table saettes.
    # Observable: updating_table forbliver FALSE naar rate-limit trigges.
    #
    # Pattern: testServer(server_fn, {test_expr}) — server og test ADSKILT
    # for korrekt fejl-propagation (se test-chart-type-observer-integration.R).
    require_internal("setup_file_upload", mode = "function")
    require_internal("create_app_state", mode = "function")

    # Opret en valid temp-CSV-fil som input$data_file kan pege paa
    tmp_csv <- tempfile(fileext = ".csv")
    writeLines("Dato;Tæller\n2024-01-01;10", tmp_csv)
    on.exit(unlink(tmp_csv), add = TRUE)

    app_state <- create_app_state()
    emit <- create_emit_api(app_state)

    # Server-funktion (registrerer upload-handler)
    server_fn <- function(input, output, session) {
      setup_file_upload(input, output, session, app_state, emit)
    }

    shiny::testServer(
      server_fn,
      {
        # Foer-betingelse: updating_table er FALSE
        expect_false(shiny::isolate(app_state$data$updating_table),
          label = "updating_table skal starte FALSE"
        )

        # Simuler at en upload lige er sket (rate-limit vindue = RATE_LIMITS$file_upload_seconds)
        app_state$session$last_upload_time <- Sys.time()

        # Trigger data_file — rate-limit checker koerer foer req(input$data_file)
        # saa et scalar-vaerdi er nok til at trigge observeEvent
        session$setInputs(data_file = tmp_csv)

        # Rate-limit skal have blokeret: updating_table forbliver FALSE
        expect_false(shiny::isolate(app_state$data$updating_table),
          label = "updating_table forbliver FALSE naar rate-limit blokerer upload"
        )
      }
    )
  })
})
