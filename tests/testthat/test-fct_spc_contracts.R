test_that("spc_request validates required fields", {
  df <- data.frame(x = 1:5, y = 1:5)

  req <- new_spc_request(df, "x", "y", "run")
  expect_s3_class(req, "spc_request")
  expect_equal(req$chart_type, "run")
  expect_equal(req$x_var, "x")
  expect_equal(req$y_var, "y")
  expect_null(req$n_var)
  expect_equal(req$multiply, 1)
  expect_identical(req$options, list())
})

test_that("spc_request contract validator catches missing fields", {
  not_a_request <- list(data = data.frame(), x_var = "x")
  expect_error(validate_spc_request_contract(not_a_request), "ikke en spc_request")

  bad_req <- structure(list(data = data.frame(), x_var = "x"), class = c("spc_request", "list"))
  expect_error(validate_spc_request_contract(bad_req), "mangler felter")
})

test_that("spc_request contract validator catches bad data type", {
  bad_req <- structure(
    list(data = "not a df", x_var = "x", y_var = "y", chart_type = "run"),
    class = c("spc_request", "list")
  )
  expect_error(validate_spc_request_contract(bad_req), "data.frame")
})

test_that("spc_request contract validator passes valid object", {
  df <- data.frame(x = 1:5, y = 1:5)
  req <- new_spc_request(df, "x", "y", "p", n_var = "n", options = list(target_value = 10))
  expect_silent(validate_spc_request_contract(req))
})

test_that("spc_prepared constructor sets correct fields", {
  df <- data.frame(x = 1:10, y = 1:10)

  prep <- new_spc_prepared(
    data = df,
    x_var = "x",
    y_var = "y",
    chart_type = "run",
    n_rows_original = 12L,
    n_rows_filtered = 10L
  )

  expect_s3_class(prep, "spc_prepared")
  expect_equal(prep$n_rows_original, 12L)
  expect_equal(prep$n_rows_filtered, 10L)
  expect_equal(prep$chart_type, "run")
})

test_that("spc_prepared contract validator passes valid object", {
  df <- data.frame(x = 1:5, y = 1:5)
  prep <- new_spc_prepared(df, "x", "y", "run")
  expect_silent(validate_spc_prepared_contract(prep))
})

test_that("spc_prepared contract validator catches wrong class", {
  not_prep <- list(data = data.frame(), n_rows_original = 5)
  expect_error(validate_spc_prepared_contract(not_prep), "ikke en spc_prepared")
})

test_that("spc_axes constructor sets required fields", {
  axes <- new_spc_axes("count", multiply = 1)
  expect_s3_class(axes, "spc_axes")
  expect_equal(axes$y_axis_unit, "count")
  expect_equal(axes$multiply, 1)
  expect_null(axes$target_value)
  expect_null(axes$target_text)
})

test_that("spc_axes contract validator passes valid object", {
  axes <- new_spc_axes("percent", multiply = 100, target_value = 0.05, target_text = "5%")
  expect_silent(validate_spc_axes_contract(axes))
})

test_that("spc_axes contract validator catches invalid unit", {
  bad_axes <- structure(
    list(y_axis_unit = "banana", multiply = 1),
    class = c("spc_axes", "list")
  )
  expect_error(validate_spc_axes_contract(bad_axes), "ugyldig")
})

test_that("spc_axes contract validator catches non-positive multiply", {
  bad_axes <- structure(
    list(y_axis_unit = "count", multiply = -1),
    class = c("spc_axes", "list")
  )
  expect_error(validate_spc_axes_contract(bad_axes), "positiv")
})

test_that("print methods return object invisibly", {
  df <- data.frame(x = 1:5, y = 1:5)
  req <- new_spc_request(df, "x", "y", "run")
  expect_output(print(req), "spc_request")

  prep <- new_spc_prepared(df, "x", "y", "run")
  expect_output(print(prep), "spc_prepared")

  axes <- new_spc_axes("time", multiply = 1)
  expect_output(print(axes), "spc_axes")
})
