# test-fct_spc_bfh_invocation.R
# Direct contract tests for the BFHcharts invocation boundary.

minimal_bfh_params <- function() {
  list(
    data = data.frame(Date = as.Date("2024-01-01") + 0:2, Count = c(10, 11, 12)),
    x = "Date",
    y = "Count",
    chart_type = "run"
  )
}

capture_error <- function(expr) {
  tryCatch(
    {
      force(expr)
      NULL
    },
    error = identity
  )
}

test_that("call_bfh_chart rejects null or non-list parameters with typed render error", {
  require_internal("call_bfh_chart", mode = "function")

  expect_error(call_bfh_chart(NULL), class = "spc_render_error")
  expect_error(call_bfh_chart("not a list"), class = "spc_render_error")
})

test_that("call_bfh_chart reports missing required parameters", {
  require_internal("call_bfh_chart", mode = "function")

  err <- capture_error(call_bfh_chart(list(data = data.frame(x = 1), x = "x")))

  expect_s3_class(err, "spc_render_error")
  expect_match(conditionMessage(err), "Missing required parameters")
  expect_equal(err$details$missing_keys, c("y", "chart_type"))
})

test_that("call_bfh_chart filters unsupported fields before BFHcharts invocation", {
  skip_if_not_installed("BFHcharts")
  require_internal("call_bfh_chart", mode = "function")

  captured <- NULL
  params <- c(
    minimal_bfh_params(),
    list(
      n = NULL,
      target_value = 12,
      y_axis_unit = "count",
      width = 10,
      height = 6,
      unsupported_field = "do not pass",
      plot_context = list(width_px = 1200)
    )
  )

  with_mocked_bindings(
    bfh_qic = function(...) {
      captured <<- list(...)
      structure(list(qic_data = data.frame(x = 1), plot = NULL), class = "bfh_qic_result")
    },
    is_bfh_qic_result = function(x) inherits(x, "bfh_qic_result"),
    .package = "BFHcharts",
    code = {
      result <- call_bfh_chart(params)
    }
  )

  expect_s3_class(result, "bfh_qic_result")
  expect_true("target_value" %in% names(captured))
  expect_true("y_axis_unit" %in% names(captured))
  expect_true("width" %in% names(captured))
  expect_false("unsupported_field" %in% names(captured))
  expect_false("plot_context" %in% names(captured))
})

test_that("call_bfh_chart wraps non-spc BFHcharts errors as typed render errors", {
  skip_if_not_installed("BFHcharts")
  require_internal("call_bfh_chart", mode = "function")

  with_mocked_bindings(
    bfh_qic = function(...) stop("low-level BFH failure", call. = FALSE),
    .package = "BFHcharts",
    code = {
      err <- capture_error(call_bfh_chart(minimal_bfh_params()))
    }
  )

  expect_s3_class(err, "spc_render_error")
  expect_match(conditionMessage(err), "BFHcharts rendering fejlede")
  expect_equal(err$details$original_class, "simpleError")
  expect_equal(err$details$chart_type, "run")
})
