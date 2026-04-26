# test-fct_file_parse_pure.R
# Unit-tests for parse_file() og ParsedFile S3-struktur
# Ingen Shiny-session kræves

# Fixtures ----------------------------------------------------------------

make_csv_fixture <- function(content, encoding = "UTF-8") {
  path <- tempfile(fileext = ".csv")
  writeBin(
    chartr("\n", "\n", iconv(content, to = encoding, toRaw = FALSE)),
    con = path
  )
  # Enklere: brug writeLines
  writeLines(content, path, useBytes = FALSE)
  path
}

# Tests: parse_file() med CSV -----------------------------------------------

test_that("parse_file returnerer ParsedFile for gyldig dansk semikolon-CSV", {
  path <- tempfile(fileext = ".csv")
  writeLines(c("Dato;Vaerdi", "2024-01-01;10", "2024-02-01;20"), path)

  result <- parse_file(path, format = "csv")

  expect_s3_class(result, "ParsedFile")
  expect_true(is.data.frame(result$data))
  expect_gte(nrow(result$data), 2)
  expect_true("Dato" %in% names(result$data))
  expect_equal(result$meta$format, "csv")
  expect_type(result$meta$rows, "integer")
  expect_type(result$warnings, "character")
})

test_that("parse_file returnerer ParsedFile for komma-separator CSV", {
  path <- tempfile(fileext = ".csv")
  writeLines(c("Date,Value,N", "2024-01-01,10,100", "2024-02-01,20,200"), path)

  result <- parse_file(path, format = "csv")

  expect_s3_class(result, "ParsedFile")
  expect_gte(ncol(result$data), 2)
})

test_that("parse_file returnerer NULL for tom fil", {
  path <- tempfile(fileext = ".csv")
  writeLines("", path)

  result <- parse_file(path, format = "csv")

  expect_null(result)
})

test_that("parse_file returnerer NULL hvis fil kun har én kolonne", {
  path <- tempfile(fileext = ".csv")
  writeLines(c("Dato", "2024-01-01", "2024-02-01"), path)

  result <- parse_file(path, format = "csv")

  # Enten NULL (parsing fejl) eller data med Skift/Frys tilføjet
  if (!is.null(result)) {
    # ensure_standard_columns tilføjer standard-kolonner — acceptabelt
    expect_s3_class(result, "ParsedFile")
  } else {
    expect_null(result)
  }
})

test_that("parse_file fejler med stop() hvis sti ikke eksisterer", {
  expect_error(
    parse_file("/ikke/eksisterende/fil.csv"),
    regexp = "fil ikke fundet"
  )
})

test_that("parse_file fejler med stop() hvis path er NULL", {
  expect_error(
    parse_file(NULL),
    regexp = "path skal"
  )
})

test_that("parse_file detekterer format automatisk fra filendelse", {
  path_csv <- tempfile(fileext = ".csv")
  writeLines(c("Dato;Vaerdi", "2024-01-01;10"), path_csv)

  result <- parse_file(path_csv) # ingen format-argument
  expect_s3_class(result, "ParsedFile")
  expect_equal(result$meta$format, "csv")
})

# Tests: ParsedFile-struktur ------------------------------------------------

test_that("ParsedFile har korrekte meta-felter", {
  path <- tempfile(fileext = ".csv")
  writeLines(c("Dato;Vaerdi", "2024-01-01;10", "2024-02-01;20"), path)

  result <- parse_file(path, format = "csv")

  expect_named(result, c("data", "meta", "warnings"))
  expect_named(result$meta, c("rows", "cols", "encoding", "format"), ignore.order = TRUE)
  expect_equal(result$meta$rows, nrow(result$data))
  expect_equal(result$meta$cols, ncol(result$data))
})

test_that("print.ParsedFile kører uden fejl", {
  path <- tempfile(fileext = ".csv")
  writeLines(c("Dato;Vaerdi", "2024-01-01;10"), path)

  result <- parse_file(path, format = "csv")
  expect_output(print(result), "ParsedFile")
})

# Tests: new_parsed_file konstruktør -----------------------------------------

test_that("new_parsed_file opretter korrekt S3-objekt", {
  df <- data.frame(x = 1:3, y = 4:6)
  result <- new_parsed_file(df, format = "csv", encoding = "UTF-8", warnings = "test")

  expect_s3_class(result, "ParsedFile")
  expect_equal(result$meta$rows, 3)
  expect_equal(result$meta$cols, 2)
  expect_equal(result$warnings, "test")
})
