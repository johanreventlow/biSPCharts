# test-utils_local_storage.R
# Direct contract tests for local storage class preservation helpers.

test_that("extract_class_info records column names and rich R classes", {
  require_internal("extract_class_info", mode = "function")

  data <- data.frame(
    count = 1:3,
    value = c(1.5, NA, 3.5),
    label = c("a", "b", "c"),
    flag = c(TRUE, FALSE, NA),
    date = as.Date("2024-01-01") + 0:2,
    group = factor(c("low", "high", "low"), levels = c("low", "high")),
    stringsAsFactors = FALSE
  )
  data$time <- as.POSIXct(
    c("2024-01-01 08:00:00", "2024-01-01 09:00:00", "2024-01-01 10:00:00"),
    tz = "Europe/Copenhagen"
  )

  info <- extract_class_info(data)

  expect_named(info, names(data))
  expect_equal(info$count$primary, "integer")
  expect_equal(info$value$primary, "numeric")
  expect_equal(info$label$primary, "character")
  expect_equal(info$flag$primary, "logical")
  expect_true(info$date$is_date)
  expect_true(info$group$is_factor)
  expect_equal(info$group$levels, c("low", "high"))
  expect_true(info$time$is_posixct)
  expect_equal(info$time$tz, "Europe/Copenhagen")
})

test_that("extract_class_info returns empty metadata for null or empty data", {
  require_internal("extract_class_info", mode = "function")

  expect_identical(extract_class_info(NULL), list())
  expect_identical(extract_class_info(data.frame()), list())
})

test_that("restore_column_class handles JSON NULL list values as typed missing values", {
  require_internal("restore_column_class", mode = "function")

  numeric_values <- list(1.5, NULL, 3.5)
  numeric_result <- restore_column_class(numeric_values, list(primary = "numeric"))
  expect_type(numeric_result, "double")
  expect_equal(numeric_result, c(1.5, NA_real_, 3.5))

  character_values <- list("a", NULL, "c")
  character_result <- restore_column_class(character_values, list(primary = "character"))
  expect_type(character_result, "character")
  expect_equal(character_result, c("a", NA_character_, "c"))
})

test_that("restore_column_class preserves factor levels and POSIXct timezone", {
  require_internal("restore_column_class", mode = "function")

  factor_result <- restore_column_class(
    list("low", NULL, "high"),
    list(primary = "factor", is_factor = TRUE, levels = c("low", "high"))
  )
  expect_s3_class(factor_result, "factor")
  expect_equal(levels(factor_result), c("low", "high"))
  expect_true(is.na(factor_result[2]))

  time_result <- restore_column_class(
    "2024-01-01 08:00:00",
    list(primary = "POSIXct", is_posixct = TRUE, tz = "Europe/Copenhagen")
  )
  expect_s3_class(time_result, "POSIXct")
  expect_equal(attr(time_result, "tzone"), "Europe/Copenhagen")
})
