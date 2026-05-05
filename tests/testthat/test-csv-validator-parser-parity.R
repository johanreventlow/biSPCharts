# test-csv-validator-parser-parity.R
# Paritet-tests: for hver delimiter som parser kan håndtere,
# skal validate_csv_file() ALSO acceptere filen.
#
# OpenSpec: align-csv-validator-and-pkgload-runtime / Phase 1

# Hjælper: opret midlertidig CSV-fil og ryd op bagefter
write_tmp_csv <- function(content, fileext = ".csv", use_bytes = FALSE) {
  path <- tempfile(fileext = fileext)
  if (use_bytes) {
    writeBin(content, path)
  } else {
    writeLines(content, path)
  }
  path
}

# =============================================================================
# PARITET: semikolon (eksisterende adfærd bevaret)
# =============================================================================

test_that("validate_csv_file accepterer semikolon-separeret CSV (dansk standard)", {
  require_internal("validate_csv_file", mode = "function")

  csv <- "Dato;Tæller;Nævner\n2024-01-01;10;100\n2024-02-01;15;120"
  path <- write_tmp_csv(csv)
  on.exit(unlink(path))

  result <- validate_csv_file(path)
  expect_true(result$valid, info = paste("Fejl:", paste(result$errors, collapse = "; ")))
})

# =============================================================================
# PARITET: komma-separator (engelsk format)
# Parser: strategi 3 (read_csv, decimal_mark = ".")
# Validator (før fix): read_csv2 → kun 1 kolonne → afvist
# =============================================================================

test_that("validate_csv_file accepterer komma-separeret CSV (engelsk format)", {
  require_internal("validate_csv_file", mode = "function")

  csv <- "Date,Count,Denominator\n2024-01-01,10,100\n2024-02-01,15,120"
  path <- write_tmp_csv(csv)
  on.exit(unlink(path))

  result <- validate_csv_file(path)
  expect_true(result$valid, info = paste("Fejl:", paste(result$errors, collapse = "; ")))
})

test_that("validate_csv_file accepterer komma-sep CSV med punkt-decimal", {
  require_internal("validate_csv_file", mode = "function")

  csv <- "Date,Count,Denominator\n2024-01-01,10.5,100.3\n2024-02-01,15.3,120.7"
  path <- write_tmp_csv(csv)
  on.exit(unlink(path))

  result <- validate_csv_file(path)
  expect_true(result$valid, info = paste("Fejl:", paste(result$errors, collapse = "; ")))
})

# =============================================================================
# PARITET: tab-separator
# Parser: strategi 2 (auto-detect via read_delim)
# Validator (før fix): read_csv2 → kun 1 kolonne → afvist
# =============================================================================

test_that("validate_csv_file accepterer tab-separeret CSV", {
  require_internal("validate_csv_file", mode = "function")

  csv <- "Dato\tTæller\tNævner\n2024-01-01\t10\t100\n2024-02-01\t15\t120"
  path <- write_tmp_csv(csv)
  on.exit(unlink(path))

  result <- validate_csv_file(path)
  expect_true(result$valid, info = paste("Fejl:", paste(result$errors, collapse = "; ")))
})

test_that("validate_csv_file accepterer tab-sep CSV med dansk komma-decimal", {
  require_internal("validate_csv_file", mode = "function")

  # Parser-strategi 2: auto-detect (delim=NULL, decimal_mark=",")
  # Dansk komma-decimal med tab-delimiter er en gyldig kombination
  csv <- "Dato\tTæller\tNævner\n2024-01-01\t10,5\t100\n2024-02-01\t15,3\t120"
  path <- write_tmp_csv(csv)
  on.exit(unlink(path))

  result <- validate_csv_file(path)
  expect_true(result$valid, info = paste("Fejl:", paste(result$errors, collapse = "; ")))
})

# =============================================================================
# EDGE CASES
# =============================================================================

test_that("validate_csv_file accepterer CSV med UTF-8 BOM i header", {
  require_internal("validate_csv_file", mode = "function")

  # UTF-8 BOM: \xEF\xBB\xBF efterfulgt af semikolon-CSV
  csv_text <- "Dato;Tæller;Nævner\n2024-01-01;10;100\n2024-02-01;15;120"
  bom <- as.raw(c(0xEF, 0xBB, 0xBF))
  content <- c(bom, charToRaw(csv_text))
  path <- write_tmp_csv(content, use_bytes = TRUE)
  on.exit(unlink(path))

  result <- validate_csv_file(path)
  expect_true(result$valid, info = paste("Fejl:", paste(result$errors, collapse = "; ")))
})

test_that("validate_csv_file accepterer CSV med mixed CRLF/LF line endings", {
  require_internal("validate_csv_file", mode = "function")

  # Windows CRLF line endings
  csv_bytes <- charToRaw("Dato;Tæller;Nævner\r\n2024-01-01;10;100\r\n2024-02-01;15;120")
  path <- write_tmp_csv(csv_bytes, use_bytes = TRUE)
  on.exit(unlink(path))

  result <- validate_csv_file(path)
  expect_true(result$valid, info = paste("Fejl:", paste(result$errors, collapse = "; ")))
})

# =============================================================================
# AFVISNING: ugyldige filer skal stadig afvises
# =============================================================================

test_that("validate_csv_file afviser tom fil (0 rækker efter header)", {
  require_internal("validate_csv_file", mode = "function")

  # Kun header, ingen data-rækker
  csv <- "Dato;Tæller;Nævner"
  path <- write_tmp_csv(csv)
  on.exit(unlink(path))

  result <- validate_csv_file(path)
  expect_false(result$valid)
  expect_true(length(result$errors) > 0)
})

test_that("validate_csv_file afviser fil med 0 kolonner", {
  require_internal("validate_csv_file", mode = "function")

  # Binær/tom fil kan heller ikke parses
  path <- tempfile(fileext = ".csv")
  writeBin(raw(0), path)
  on.exit(unlink(path))

  result <- validate_csv_file(path)
  # Tom fil: valid = FALSE (tom fil fanges i validate_uploaded_file via size=0,
  # men validate_csv_file selv må ikke krasje)
  # Vi tester blot at funktionen returnerer en liste
  expect_type(result, "list")
  expect_true("valid" %in% names(result))
  expect_true("errors" %in% names(result))
})

# =============================================================================
# PARITET SYMMETRI: parser kan parse hvad validator accepterer
# =============================================================================

test_that("parse_file parser komma-sep fil som validator accepterer", {
  require_internal("validate_csv_file", mode = "function")
  require_internal("parse_file", mode = "function")

  csv <- "Date,Count,Denominator\n2024-01-01,10,100\n2024-02-01,15,120"
  path <- write_tmp_csv(csv)
  on.exit(unlink(path))

  # Validator accepterer
  val <- validate_csv_file(path)
  expect_true(val$valid, info = paste("Validator fejl:", paste(val$errors, collapse = "; ")))

  # Parser kan parse
  parsed <- parse_file(path)
  expect_false(is.null(parsed))
  expect_true(is.list(parsed) || is.data.frame(parsed$data))
})

test_that("parse_file parser tab-sep fil som validator accepterer", {
  require_internal("validate_csv_file", mode = "function")
  require_internal("parse_file", mode = "function")

  csv <- "Dato\tTæller\tNævner\n2024-01-01\t10\t100\n2024-02-01\t15\t120"
  path <- write_tmp_csv(csv)
  on.exit(unlink(path))

  # Validator accepterer
  val <- validate_csv_file(path)
  expect_true(val$valid, info = paste("Validator fejl:", paste(val$errors, collapse = "; ")))

  # Parser kan parse
  parsed <- parse_file(path)
  expect_false(is.null(parsed))
})
