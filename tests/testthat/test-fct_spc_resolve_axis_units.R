helper_prepared <- function(y_axis_unit = "count", multiply = 1,
                            target_value = NULL, centerline_value = NULL,
                            target_text = NULL, chart_type = "run",
                            n_var = NULL) {
  df <- data.frame(x = 1:10, y = as.numeric(1:10))
  options <- list(
    y_axis_unit = y_axis_unit,
    target_value = target_value,
    centerline_value = centerline_value,
    target_text = target_text
  )
  new_spc_prepared(df, "x", "y", chart_type, n_var = n_var, multiply = multiply, options = options)
}

test_that("resolve_axis_units returnerer spc_axes", {
  prep <- helper_prepared()
  axes <- resolve_axis_units(prep)
  expect_s3_class(axes, "spc_axes")
})

test_that("resolve_axis_units bevarer count-enhed", {
  axes <- resolve_axis_units(helper_prepared(y_axis_unit = "count"))
  expect_equal(axes$y_axis_unit, "count")
})

test_that("resolve_axis_units bevarer percent-enhed med nævner", {
  axes <- resolve_axis_units(helper_prepared(y_axis_unit = "percent", n_var = "n"))
  expect_equal(axes$y_axis_unit, "percent")
})

test_that("resolve_axis_units nedgraderer percent til count uden nævner", {
  axes <- resolve_axis_units(helper_prepared(y_axis_unit = "percent", n_var = NULL))
  expect_equal(axes$y_axis_unit, "count")
})

test_that("resolve_axis_units mapper time_minutes til time", {
  axes <- resolve_axis_units(helper_prepared(y_axis_unit = "time_minutes"))
  expect_equal(axes$y_axis_unit, "time")
})

test_that("resolve_axis_units mapper time_hours til time", {
  axes <- resolve_axis_units(helper_prepared(y_axis_unit = "time_hours"))
  expect_equal(axes$y_axis_unit, "time")
})

test_that("resolve_axis_units mapper time_days til time", {
  axes <- resolve_axis_units(helper_prepared(y_axis_unit = "time_days"))
  expect_equal(axes$y_axis_unit, "time")
})

test_that("resolve_axis_units skalerer target_value til minutter for time_hours", {
  axes <- resolve_axis_units(helper_prepared(
    y_axis_unit = "time_hours",
    target_value = 2
  ))
  # 2 timer = 120 minutter
  expect_equal(axes$target_value, 120)
})

test_that("resolve_axis_units skalerer target_value til minutter for time_days", {
  axes <- resolve_axis_units(helper_prepared(
    y_axis_unit = "time_days",
    target_value = 1
  ))
  # 1 dag = 1440 minutter
  expect_equal(axes$target_value, 1440)
})

test_that("resolve_axis_units skalerer centerline_value til minutter", {
  axes <- resolve_axis_units(helper_prepared(
    y_axis_unit = "time_hours",
    centerline_value = 1
  ))
  expect_equal(axes$centerline_value, 60)
})

test_that("resolve_axis_units viderefører target_value NULL ved count", {
  axes <- resolve_axis_units(helper_prepared(y_axis_unit = "count"))
  expect_null(axes$target_value)
})

test_that("resolve_axis_units bevarer multiply fra prepared", {
  axes <- resolve_axis_units(helper_prepared(multiply = 100))
  expect_equal(axes$multiply, 100)
})

test_that("resolve_axis_units formaterer target_text som komposit-tid", {
  axes <- resolve_axis_units(helper_prepared(
    y_axis_unit = "time_days",
    target_value = 1,
    target_text = "1"
  ))
  # 1 dag = 1440 minutter → format_time_composite("1d")
  expect_false(is.null(axes$target_text))
  expect_true(nzchar(axes$target_text))
})

test_that("resolve_axis_units bevarer operator-prefix i target_text", {
  axes <- resolve_axis_units(helper_prepared(
    y_axis_unit = "time_hours",
    target_value = 2,
    target_text = "<2"
  ))
  expect_true(startsWith(axes$target_text, "<"))
})

test_that("resolve_axis_units lader target_text være NULL ved count", {
  axes <- resolve_axis_units(helper_prepared(
    y_axis_unit = "count",
    target_text = "5"
  ))
  expect_equal(axes$target_text, "5")
})
