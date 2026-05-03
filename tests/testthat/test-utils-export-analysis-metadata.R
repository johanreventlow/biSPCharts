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

test_that("build_export_analysis_metadata falls back to qic_data centerline and empty target context", {
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

# ============================================================================
# Regression tests: #470 - centerlinje-afrunding flipper malfortolkning
# ============================================================================
# BFHcharts' summary-lag afrunder kontrolgrænser (jf. utils_qic_summary.R:177).
# resolve_analysis_centerline() skal bruge qic_data$cl (raa qicharts2-vaerdi)
# primaert for at undgaa boundary-cases hvor afrunding flipper "maal opfyldt"-
# vurdering.

make_divergent_bfh_result <- function(raw_cl, summary_cl, y_axis_unit = "percent") {
  # Mock hvor summary er afrundet vs. qic_data raa - illustrerer #470 bug
  result <- list(
    config = list(y_axis_unit = y_axis_unit),
    summary = data.frame(centerlinje = summary_cl),
    qic_data = data.frame(cl = rep(raw_cl, 3))
  )
  class(result) <- "bfh_qic_result"
  result
}

test_that("resolve_analysis_centerline() prefers raw qic_data over rounded summary (#470)", {
  # Rå cl=0.9005, summary afrundet til 0.9000
  result <- make_divergent_bfh_result(raw_cl = 0.9005, summary_cl = 0.9000)
  expect_equal(resolve_analysis_centerline(result), 0.9005)
})

test_that("at_target uses raw centerline so target=0.9003 with cl=0.9005 = TRUE (#470)", {
  # Boundary-case: rå cl >= target opfyldt; summary afrundet ville flippe vurdering
  metadata <- build_export_analysis_metadata(
    bfh_qic_result = make_divergent_bfh_result(raw_cl = 0.9005, summary_cl = 0.9000),
    target_value = 0.9003,
    target_text = ">= 90,03%"
  )
  expect_true(metadata$at_target,
    info = "Raw cl=0.9005 >= target=0.9003 -> mål opfyldt (afrundet 0.9000 ville flippe)"
  )
})

test_that("centerline value falls back to summary when qic_data mangler (#470)", {
  # Degraderet input: kun summary tilgaengelig
  result <- list(
    config = list(y_axis_unit = "count"),
    summary = data.frame(centerlinje = 42),
    qic_data = NULL
  )
  class(result) <- "bfh_qic_result"
  expect_equal(resolve_analysis_centerline(result), 42)
})

test_that("resolve_analysis_centerline returns last row for variable cl (freeze/part)", {
  # Variabel cl ved freeze/part - sidste raekke matcher sidste fase
  result <- list(
    config = list(y_axis_unit = "count"),
    summary = data.frame(centerlinje = c(10, 20)),
    qic_data = data.frame(cl = c(10, 10, 10, 20, 20, 20))
  )
  class(result) <- "bfh_qic_result"
  expect_equal(resolve_analysis_centerline(result), 20)
})
