# test-csv-formula-injection.R
# Tests: sanitize_csv_output() blokerer Excel formula injection (Phase 3)

test_that("sanitize_csv_output() prefix-escaper = med enkelt-quote", {
  skip_if(
    !exists("sanitize_csv_output",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "sanitize_csv_output ikke tilgængelig"
  )

  data <- data.frame(val = "=SUM(A1:A10)", stringsAsFactors = FALSE)
  result <- biSPCharts:::sanitize_csv_output(data)
  expect_equal(result$val, "'=SUM(A1:A10)")
})

test_that("sanitize_csv_output() prefix-escaper + prefix", {
  skip_if(
    !exists("sanitize_csv_output",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "sanitize_csv_output ikke tilgængelig"
  )

  data <- data.frame(val = "+1234", stringsAsFactors = FALSE)
  result <- biSPCharts:::sanitize_csv_output(data)
  expect_equal(result$val, "'+1234")
})

test_that("sanitize_csv_output() prefix-escaper - prefix", {
  skip_if(
    !exists("sanitize_csv_output",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "sanitize_csv_output ikke tilgængelig"
  )

  data <- data.frame(val = "-1234", stringsAsFactors = FALSE)
  result <- biSPCharts:::sanitize_csv_output(data)
  expect_equal(result$val, "'-1234")
})

test_that("sanitize_csv_output() prefix-escaper @ prefix", {
  skip_if(
    !exists("sanitize_csv_output",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "sanitize_csv_output ikke tilgængelig"
  )

  data <- data.frame(val = "@WEBSERVICE('evil.com')", stringsAsFactors = FALSE)
  result <- biSPCharts:::sanitize_csv_output(data)
  expect_equal(result$val, "'@WEBSERVICE('evil.com')")
})

test_that("sanitize_csv_output() prefix-escaper tab prefix", {
  skip_if(
    !exists("sanitize_csv_output",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "sanitize_csv_output ikke tilgængelig"
  )

  data <- data.frame(val = "\tcmd", stringsAsFactors = FALSE)
  result <- biSPCharts:::sanitize_csv_output(data)
  expect_equal(result$val, "'\tcmd")
})

test_that("sanitize_csv_output() berører ikke normale værdier", {
  skip_if(
    !exists("sanitize_csv_output",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "sanitize_csv_output ikke tilgængelig"
  )

  data <- data.frame(
    normal = c("Hej verden", "12345", "SPC data"),
    antal = c(1L, 2L, 3L),
    stringsAsFactors = FALSE
  )
  result <- biSPCharts:::sanitize_csv_output(data)
  expect_equal(result$normal, data$normal)
  expect_equal(result$antal, data$antal)
})

test_that("sanitize_csv_output() håndterer NA i string-kolonner", {
  skip_if(
    !exists("sanitize_csv_output",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "sanitize_csv_output ikke tilgængelig"
  )

  data <- data.frame(
    val = c("=FORMULA", NA_character_, "normal"),
    stringsAsFactors = FALSE
  )
  result <- biSPCharts:::sanitize_csv_output(data)
  expect_equal(result$val[1], "'=FORMULA")
  expect_true(is.na(result$val[2]))
  expect_equal(result$val[3], "normal")
})

test_that("sanitize_csv_output() fejler på non-data.frame input", {
  skip_if(
    !exists("sanitize_csv_output",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "sanitize_csv_output ikke tilgængelig"
  )

  expect_error(biSPCharts:::sanitize_csv_output("ikke en data.frame"))
  expect_error(biSPCharts:::sanitize_csv_output(c("a", "b")))
})

# Integration-tests for #484: SPC-analyse-arket sanitiseres. Tidligere skrev
# .write_spc_analysis_sheet() raa user-input direkte via openxlsx::writeData,
# mens Data- og Indstillinger-arkene allerede kaldte sanitize_csv_output.
test_that("SPC-analyse-arket sanitiserer kommentar-vaerdier mod formula injection (#484)", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("readxl")
  skip_if(
    !exists(".write_spc_analysis_sheet",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    ".write_spc_analysis_sheet ikke tilgængelig"
  )

  sections <- list(
    overview = data.frame(
      felt = c("chart_title", "department"),
      vaerdi = c("=HYPERLINK(\"http://x\", \"klik\")", "+1234"),
      stringsAsFactors = FALSE
    ),
    per_part = data.frame(
      part = "1",
      kommentar = "@WEBSERVICE('evil.com')",
      stringsAsFactors = FALSE
    ),
    anhoej = data.frame(
      part = "1",
      regel = "-1234 (negativ)",
      stringsAsFactors = FALSE
    ),
    special_cause = data.frame(
      x = "2024-01-01",
      kommentar = "=SUM(A1:A10)",
      stringsAsFactors = FALSE
    )
  )

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  wb <- openxlsx::createWorkbook()
  biSPCharts:::.write_spc_analysis_sheet(wb, sections)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  raw <- readxl::read_excel(tmp,
    sheet = biSPCharts:::SPC_ANALYSIS_SHEET_NAME,
    col_names = FALSE,
    col_types = "text"
  )

  cells <- unlist(raw, use.names = FALSE)
  cells <- cells[!is.na(cells)]

  # Ingen raa formel-prefixed-tekst i output
  expect_false(any(grepl("^=HYPERLINK", cells)))
  expect_false(any(grepl("^\\+1234$", cells)))
  expect_false(any(grepl("^@WEBSERVICE", cells)))
  expect_false(any(grepl("^=SUM\\(", cells)))
  # Sektion B har "-1234 (negativ)" i regel-kolonnen — bekraeft escaped
  expect_false(any(grepl("^-1234 ", cells)))

  # Sanitize-prefix ' tilstede paa hver injection-vector
  expect_true(any(grepl("^'=HYPERLINK", cells)))
  expect_true(any(grepl("^'\\+1234$", cells)))
  expect_true(any(grepl("^'@WEBSERVICE", cells)))
  expect_true(any(grepl("^'=SUM\\(", cells)))
  expect_true(any(grepl("^'-1234 ", cells)))
})
