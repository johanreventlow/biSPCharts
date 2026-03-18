# Tests for utils_input_sanitization.R

# validate_file_extension() ---------------------------------------------------

test_that("validate_file_extension accepterer gyldige extensions", {
  expect_true(validate_file_extension("csv"))
  expect_true(validate_file_extension("xlsx"))
  expect_true(validate_file_extension("xls"))
})

test_that("validate_file_extension håndterer dots og case", {
  expect_true(validate_file_extension(".csv"))
  expect_true(validate_file_extension(".XLSX"))
  expect_true(validate_file_extension("CSV"))
})

test_that("validate_file_extension afviser ugyldige extensions", {
  expect_false(validate_file_extension("exe"))
  expect_false(validate_file_extension("sh"))
  expect_false(validate_file_extension("bat"))
  expect_false(validate_file_extension("php"))
})

test_that("validate_file_extension håndterer edge cases", {
  expect_false(validate_file_extension(NULL))
  expect_false(validate_file_extension(character(0)))
  # For lang extension
  expect_false(validate_file_extension("verylongextension"))
})

test_that("validate_file_extension accepterer custom whitelist", {
  expect_true(validate_file_extension("pdf", allowed_extensions = c("pdf", "docx")))
  expect_false(validate_file_extension("csv", allowed_extensions = c("pdf", "docx")))
})

# sanitize_csv_output() -------------------------------------------------------

test_that("sanitize_csv_output escaper formula injection", {
  df <- data.frame(
    safe = c("normal", "data"),
    dangerous = c("=SUM(A1:A10)", "@WEBSERVICE('evil')"),
    stringsAsFactors = FALSE
  )

  result <- sanitize_csv_output(df)
  expect_equal(result$dangerous[1], "'=SUM(A1:A10)")
  expect_equal(result$dangerous[2], "'@WEBSERVICE('evil')")
  # Sikre værdier uændret
  expect_equal(result$safe[1], "normal")
  expect_equal(result$safe[2], "data")
})

test_that("sanitize_csv_output håndterer plus og minus prefix", {
  df <- data.frame(
    col = c("+cmd", "-cmd", "normal"),
    stringsAsFactors = FALSE
  )
  result <- sanitize_csv_output(df)
  expect_equal(result$col[1], "'+cmd")
  expect_equal(result$col[2], "'-cmd")
  expect_equal(result$col[3], "normal")
})

test_that("sanitize_csv_output bevarer numeriske kolonner", {
  df <- data.frame(
    numbers = c(1.5, 2.3, -3.1),
    text = c("ok", "=bad", "fine"),
    stringsAsFactors = FALSE
  )
  result <- sanitize_csv_output(df)
  expect_equal(result$numbers, c(1.5, 2.3, -3.1))
  expect_equal(result$text[2], "'=bad")
})

test_that("sanitize_csv_output håndterer NA korrekt", {
  df <- data.frame(
    col = c(NA, "=formula", "safe"),
    stringsAsFactors = FALSE
  )
  result <- sanitize_csv_output(df)
  expect_true(is.na(result$col[1]))
  expect_equal(result$col[2], "'=formula")
})

test_that("sanitize_csv_output fejler for non-data.frame", {
  expect_error(sanitize_csv_output("not a data frame"))
  expect_error(sanitize_csv_output(list(a = 1)))
})

# create_security_warning() ---------------------------------------------------

test_that("create_security_warning genererer korrekte beskeder", {
  msg <- create_security_warning("Kolonne", "invalid_chars")
  expect_true(grepl("ikke-tilladte karakterer", msg))

  msg <- create_security_warning("Fil", "too_long")
  expect_true(grepl("for langt", msg))

  msg <- create_security_warning("Input", "invalid_format")
  expect_true(grepl("ugyldigt format", msg))
})

test_that("create_security_warning tilføjer additional info", {
  msg <- create_security_warning("Fil", "too_long", "Max 100 tegn")
  expect_true(grepl("for langt", msg))
  expect_true(grepl("Max 100 tegn", msg))
})

test_that("create_security_warning bruger fallback for ukendt type", {
  msg <- create_security_warning("Felt", "unknown_type")
  expect_true(grepl("Validation fejl", msg))
})
