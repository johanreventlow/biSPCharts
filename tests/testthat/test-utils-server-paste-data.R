# test-utils-server-paste-data.R
# Edge-case tests for paste-data utilities.
# excel_data_to_paste_text: type-bevarelse, NULL/tom-data, NA-håndtering.
# build_excel_sheet_dropdown_items: NULL/tom input, empty_flags-mismatch.

# EXCEL_DATA_TO_PASTE_TEXT ====================================================

test_that("excel_data_to_paste_text returnerer tom streng for NULL data", {
  skip_if_not(exists("excel_data_to_paste_text", mode = "function"))

  result <- excel_data_to_paste_text(NULL)
  expect_equal(result, "")
})

test_that("excel_data_to_paste_text returnerer kun header for 0-raekker data", {
  skip_if_not(exists("excel_data_to_paste_text", mode = "function"))

  data <- data.frame(Dato = character(0), Vaerdi = numeric(0))
  result <- excel_data_to_paste_text(data)
  expect_equal(result, "Dato\tVaerdi")
})

test_that("excel_data_to_paste_text formaterer numeriske vaerdier med komma-decimal", {
  skip_if_not(exists("excel_data_to_paste_text", mode = "function"))

  data <- data.frame(x = c(1.5, 2.75, 3.0))
  result <- excel_data_to_paste_text(data)
  lines <- strsplit(result, "\n")[[1]]

  # Header
  expect_equal(lines[1], "x")

  # Numeriske: komma-decimal (dansk format)
  expect_true(grepl(",", lines[2], fixed = TRUE) || lines[2] == "1,5")
  expect_equal(lines[2], "1,5")
  expect_equal(lines[3], "2,75")
})

test_that("excel_data_to_paste_text konverterer datoer til ISO 8601", {
  skip_if_not(exists("excel_data_to_paste_text", mode = "function"))

  data <- data.frame(Dato = as.Date(c("2023-01-15", "2023-12-31")))
  result <- excel_data_to_paste_text(data)
  lines <- strsplit(result, "\n")[[1]]

  expect_equal(lines[2], "2023-01-15")
  expect_equal(lines[3], "2023-12-31")
})

test_that("excel_data_to_paste_text konverterer NA til tom streng", {
  skip_if_not(exists("excel_data_to_paste_text", mode = "function"))

  data <- data.frame(x = c(1.0, NA, 3.0))
  result <- excel_data_to_paste_text(data)
  lines <- strsplit(result, "\n")[[1]]

  expect_equal(lines[3], "")
})

test_that("excel_data_to_paste_text haandterer data.frame med 0 kolonner", {
  skip_if_not(exists("excel_data_to_paste_text", mode = "function"))

  data <- data.frame()
  result <- excel_data_to_paste_text(data)
  expect_equal(result, "")
})

test_that("excel_data_to_paste_text bevarer tab-separator mellem kolonner", {
  skip_if_not(exists("excel_data_to_paste_text", mode = "function"))

  data <- data.frame(A = c("foo"), B = c("bar"), C = c("baz"))
  result <- excel_data_to_paste_text(data)
  lines <- strsplit(result, "\n")[[1]]

  # Header: 2 tabs (3 kolonner)
  expect_equal(lengths(regmatches(lines[1], gregexpr("\t", lines[1]))), 2)
  # Data: 2 tabs
  expect_equal(lengths(regmatches(lines[2], gregexpr("\t", lines[2]))), 2)
})

# BUILD_EXCEL_SHEET_DROPDOWN_ITEMS ============================================

test_that("build_excel_sheet_dropdown_items returnerer NULL for NULL input", {
  skip_if_not(exists("build_excel_sheet_dropdown_items", mode = "function"))

  result <- build_excel_sheet_dropdown_items(NULL)
  expect_null(result)
})

test_that("build_excel_sheet_dropdown_items returnerer NULL for tom vector", {
  skip_if_not(exists("build_excel_sheet_dropdown_items", mode = "function"))

  result <- build_excel_sheet_dropdown_items(character(0))
  expect_null(result)
})

test_that("build_excel_sheet_dropdown_items returnerer tagList med korrekt struktur", {
  skip_if_not(exists("build_excel_sheet_dropdown_items", mode = "function"))

  sheets <- c("Data", "Indstillinger", "SPC-analyse")
  result <- build_excel_sheet_dropdown_items(sheets)

  expect_false(is.null(result))
  # tagList er ikke-NULL og har shiny.tag.list klasse
  expect_s3_class(result, "shiny.tag.list")
  # HTML indeholder alle ark-navne
  html <- as.character(result)
  for (sheet in sheets) {
    expect_true(grepl(sheet, html, fixed = TRUE))
  }
})

test_that("build_excel_sheet_dropdown_items haandterer empty_flags-laengdemismatch", {
  # Hvis empty_flags har forkert laengde, bruges FALSE for alle ark
  skip_if_not(exists("build_excel_sheet_dropdown_items", mode = "function"))

  sheets <- c("Data", "Indstillinger")
  # 3 flags til 2 ark — skal degradere gracefully
  result <- build_excel_sheet_dropdown_items(sheets, empty_flags = c(TRUE, FALSE, TRUE))

  expect_false(is.null(result))
  expect_equal(length(result), 2)
})

test_that("build_excel_sheet_dropdown_items markerer tomme ark korrekt", {
  skip_if_not(exists("build_excel_sheet_dropdown_items", mode = "function"))

  sheets <- c("Data", "Tomt ark")
  empty_flags <- c(FALSE, TRUE)
  result <- build_excel_sheet_dropdown_items(sheets, empty_flags = empty_flags)

  html <- as.character(result)
  # Tom ark skal have --empty klasse
  expect_true(grepl("excel-sheet-item--empty", html))
})
