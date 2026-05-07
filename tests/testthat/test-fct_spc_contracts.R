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


test_that("spc_axes constructor sets required fields", {
  axes <- new_spc_axes("count", multiply = 1)
  expect_s3_class(axes, "spc_axes")
  expect_equal(axes$y_axis_unit, "count")
  expect_equal(axes$multiply, 1)
  expect_null(axes$target_value)
  expect_null(axes$target_text)
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
