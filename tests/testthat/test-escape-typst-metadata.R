# ==============================================================================
# TEST: ESCAPE_TYPST_METADATA
# ==============================================================================
# FORMAL: Unit tests for escape_typst_metadata() helper.
#         Sikrer at Typst markup-tegn i bruger-input escapes korrekt
#         inden indsaettelse i Typst-template (#427).
#
# TEST COVERAGE:
#   - Typst-markup tegn: #, $, backtick, backslash
#   - NULL og non-character returneres uaendret
#   - Vector-input behandles per element
#   - Kombination af markup-tegn
#
# NOTE om R string-escaping i tests:
#   "\\" i R kode = et backslash-tegn i strengen.
#   Forventede vaerdier er R-strenge -- "\\#" er saaledes to tegn: \ og #.
# ==============================================================================

library(testthat)

# TEST: Typst-injection pattern ================================================

test_that("escape_typst_metadata escaper hash (#)", {
  result <- escape_typst_metadata("#raw(block: true, \"hack\")")
  expect_equal(substr(result, 1L, 2L), "\\#")
  expect_false(startsWith(result, "#"))
})

test_that("escape_typst_metadata escaper dollartegn ($)", {
  result <- escape_typst_metadata("Patient $X")
  # Forventet: "Patient \$X" -- i R-streng = "Patient \\$X"
  expect_equal(result, "Patient \\$X")
  # Sikrer at dollar ikke starter et Typst math-mode
  expect_false(grepl("[^\\]\\$", result))
})

test_that("escape_typst_metadata escaper backtick (`)", {
  result <- escape_typst_metadata("`rm -rf /`")
  # Forventet: "\`rm -rf /\`" -- i R-streng = "\\`rm -rf /\\`"
  expect_equal(result, "\\`rm -rf /\\`")
  # Ingen uescapede backticks
  expect_false(grepl("(?<!\\\\)`", result, perl = TRUE))
})

test_that("escape_typst_metadata escaper backslash (\\)", {
  result <- escape_typst_metadata("C:\\Users\\Patient")
  # Forventet: "C:\\\\Users\\\\Patient" i R (= C:\\Users\\Patient i output-streng)
  expect_equal(result, "C:\\\\Users\\\\Patient")
})

test_that("escape_typst_metadata haandterer kombination af markup-tegn", {
  # Input: #raw(`$hack`)
  result <- escape_typst_metadata("#raw(`$hack`)")
  # Alle tre markup-tegn skal vaere escaped
  expect_true(startsWith(result, "\\#"))
  # Regex-mode: \\\\ matcher en backslash, ` er literal
  expect_true(grepl("\\\\`", result))
  # Regex-mode: \\\\ matcher en backslash, \\$ matcher literal dollar
  expect_true(grepl("\\\\\\$", result))
})

# TEST: Backslash foerst (orden er kritisk) =====================================

test_that("escape_typst_metadata escaper ikke allerede-escaped tegn dobbelt", {
  # Backslash skal kun escapes een gang
  r_single_bs <- escape_typst_metadata("\\") # Input: et backslash
  expect_equal(nchar(r_single_bs), 2L) # Output: to backslashes
  chars <- strsplit(r_single_bs, "")[[1]]
  expect_equal(chars, c("\\", "\\"))
})

# TEST: NULL og non-character ==================================================

test_that("escape_typst_metadata returnerer NULL uaendret", {
  result <- escape_typst_metadata(NULL)
  expect_null(result)
})

test_that("escape_typst_metadata returnerer integer uaendret", {
  result <- escape_typst_metadata(42L)
  expect_identical(result, 42L)
})

test_that("escape_typst_metadata returnerer logical uaendret", {
  result <- escape_typst_metadata(TRUE)
  expect_identical(result, TRUE)
})

test_that("escape_typst_metadata returnerer liste uaendret", {
  val <- list(a = 1, b = "x")
  result <- escape_typst_metadata(val)
  expect_identical(result, val)
})

# TEST: Vector-input ===========================================================

test_that("escape_typst_metadata behandler vector per element", {
  input <- c("#hash", "normal", "$dollar")
  result <- escape_typst_metadata(input)

  expect_length(result, 3L)
  expect_equal(result[[1L]], "\\#hash")
  expect_equal(result[[2L]], "normal")
  expect_equal(result[[3L]], "\\$dollar")
})

test_that("escape_typst_metadata returnerer character vector for character vector input", {
  input <- c("a", "b#c")
  result <- escape_typst_metadata(input)
  expect_type(result, "character")
  expect_length(result, 2L)
})

# TEST: Upaavirkede inputs =====================================================

test_that("escape_typst_metadata beroerer ikke normale strenge", {
  normal_input <- "Bispebjerg og Frederiksberg Hospital"
  result <- escape_typst_metadata(normal_input)
  expect_equal(result, normal_input)
})

test_that("escape_typst_metadata beroerer ikke danske tegn", {
  danish_input <- "æøåÆØÅ"
  result <- escape_typst_metadata(danish_input)
  expect_equal(result, danish_input)
})

test_that("escape_typst_metadata haandterer tom streng", {
  result <- escape_typst_metadata("")
  expect_equal(result, "")
})
