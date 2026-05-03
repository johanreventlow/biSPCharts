library(testthat)

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

if (!exists("build_export_analysis_metadata", mode = "function")) {
  skip("build_export_analysis_metadata ikke tilgaengelig — skip i R CMD check miljo")
}

make_mock_bfh_qic_result <- function(centerline = 50,
                                     y_axis_unit = "count",
                                     include_summary = TRUE) {
  result <- list(
    config = list(y_axis_unit = y_axis_unit),
    summary = if (isTRUE(include_summary)) {
      data.frame(centerlinje = centerline)
    } else {
      NULL
    },
    qic_data = data.frame(cl = rep(centerline, 3))
  )

  class(result) <- "bfh_qic_result"
  result
}

test_that("build_export_analysis_metadata enriches context with BFHddl-like fields", {
  metadata <- build_export_analysis_metadata(
    bfh_qic_result = make_mock_bfh_qic_result(centerline = 12.4),
    target_value = 10,
    target_text = "< 10",
    data_definition = "Ventetid til operation",
    chart_title = "Ventetid 2026",
    department = "Ortopædkirurgi"
  )

  expect_equal(metadata$data_definition, "Ventetid til operation")
  expect_equal(metadata$target, 10)
  expect_equal(metadata$chart_title, "Ventetid 2026")
  expect_equal(metadata$department, "Ortopædkirurgi")
  expect_equal(metadata$centerline, "12,4")
  expect_false(metadata$at_target)
  expect_equal(metadata$target_direction, "< 10")
})

test_that("build_export_analysis_metadata formats percent centerline and directional targets", {
  metadata <- build_export_analysis_metadata(
    bfh_qic_result = make_mock_bfh_qic_result(centerline = 0.82, y_axis_unit = "percent"),
    target_value = 0.8,
    target_text = "> 80%"
  )

  expect_equal(metadata$centerline, "82%")
  expect_true(metadata$at_target)
  expect_equal(metadata$target_direction, "> 80%")
})

test_that("build_export_analysis_metadata uses qic_data centerline when summary missing", {
  metadata <- build_export_analysis_metadata(
    bfh_qic_result = make_mock_bfh_qic_result(centerline = 7, include_summary = FALSE),
    department = "Akut"
  )

  expect_equal(metadata$centerline, "7")
  expect_false(metadata$at_target)
  expect_equal(metadata$target_direction, "")
  expect_equal(metadata$department, "Akut")
  expect_null(metadata$target)
})

test_that("resolve_analysis_centerline prefers raw qic_data over rounded summary (#470)", {
  # Regression: BFHcharts $summary er afrundet til 4 decimaler (publicerings-
  # format). Brug rå qic_data$cl som beregningskilde — undgå at afrunding
  # forplanter sig til mål-vurdering og analyse-metadata.
  bfh_qic_result <- list(
    config = list(y_axis_unit = "percent"),
    summary = data.frame(centerlinje = 0.9000),
    qic_data = data.frame(cl = rep(0.90054321, 3))
  )

  centerline <- resolve_analysis_centerline(bfh_qic_result)
  expect_equal(centerline, 0.90054321)
  expect_false(identical(centerline, 0.9000))
})

test_that("resolve_analysis_centerline returns last row for time series with varying cl", {
  # qic_data$cl kan variere over tid (fx ved frozen baseline). Brug sidste
  # række (samme konvention som summary), ikke første.
  bfh_qic_result <- list(
    qic_data = data.frame(cl = c(10, 12, 15))
  )

  expect_equal(resolve_analysis_centerline(bfh_qic_result), 15)
})
