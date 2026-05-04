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

# Edge-case-tests for #488 — udvider dækning omkring #470:
# (a) operator <=, (b) ingen direction, (c) tom qic_data fallback,
# (d) NULL input, (e) NA i sidste cl-raekke.

test_that("at_target med <=-target og raw cl flipper ej ved boundary (#470/#488)", {
  # Rå cl=0.0995, target<=0.0997 -> opfyldt; summary 0.1000 ville flippe
  metadata <- build_export_analysis_metadata(
    bfh_qic_result = make_divergent_bfh_result(raw_cl = 0.0995, summary_cl = 0.1000),
    target_value = 0.0997,
    target_text = "<= 9,97%"
  )
  expect_true(metadata$at_target,
    info = "Raw cl=0.0995 <= target=0.0997 -> opfyldt (afrundet 0.1000 ville flippe)"
  )
})

test_that("at_target uden retning bruger tolerance-baseret close_enough (#488)", {
  # Ingen >/< prefix -> tolerance check (max(abs(target)*0.05, 0.01))
  result <- make_divergent_bfh_result(raw_cl = 0.85, summary_cl = 0.85)
  metadata <- build_export_analysis_metadata(
    bfh_qic_result = result,
    target_value = 0.86,
    target_text = "0,86"
  )
  # tolerance = max(0.86*0.05, 0.01) = 0.043; |0.85-0.86|=0.01 -> indenfor
  expect_true(metadata$at_target)

  # Klart udenfor tolerance
  result2 <- make_divergent_bfh_result(raw_cl = 0.50, summary_cl = 0.50)
  metadata2 <- build_export_analysis_metadata(
    bfh_qic_result = result2,
    target_value = 0.86,
    target_text = "0,86"
  )
  expect_false(metadata2$at_target)
})

test_that("resolve_analysis_centerline fallbacker til summary ved tom qic_data (#488)", {
  # qic_data er ikke-NULL men har 0 raekker -> fald tilbage til summary
  result <- list(
    config = list(y_axis_unit = "count"),
    summary = data.frame(centerlinje = 12.5),
    qic_data = data.frame(cl = numeric(0))
  )
  class(result) <- "bfh_qic_result"
  expect_equal(resolve_analysis_centerline(result), 12.5)
})

test_that("resolve_analysis_centerline returnerer NULL ved fuldt tomt input (#488)", {
  expect_null(resolve_analysis_centerline(NULL))

  empty <- list(config = list(), summary = NULL, qic_data = NULL)
  class(empty) <- "bfh_qic_result"
  expect_null(resolve_analysis_centerline(empty))
})

test_that("resolve_analysis_centerline returnerer NA hvis sidste cl-raekke er NA (#488)", {
  # NA i sidste raekke skal propageres ej silently coerced til 0
  result <- list(
    config = list(y_axis_unit = "count"),
    summary = data.frame(centerlinje = 10),
    qic_data = data.frame(cl = c(10, 10, NA_real_))
  )
  class(result) <- "bfh_qic_result"
  cl <- resolve_analysis_centerline(result)
  expect_true(is.na(cl))
})

# ============================================================================
# BFHddl-pipeline-paritet (#175) - berig metadata med y_axis_unit, target_display,
# action_text, baseline_analysis, signal_examples
# ============================================================================

make_bfh_result_with_anhoej <- function(centerline = 50,
                                        y_axis_unit = "count",
                                        runs_detected = FALSE,
                                        crossings_detected = FALSE) {
  result <- list(
    config = list(y_axis_unit = y_axis_unit),
    summary = data.frame(centerlinje = centerline),
    qic_data = data.frame(cl = rep(centerline, 3)),
    metadata = list(
      anhoej_rules = list(
        runs_detected = runs_detected,
        crossings_detected = crossings_detected
      )
    )
  )
  class(result) <- "bfh_qic_result"
  result
}

test_that("build_export_analysis_metadata exposes y_axis_unit + target_display (#175)", {
  metadata <- build_export_analysis_metadata(
    bfh_qic_result = make_bfh_result_with_anhoej(centerline = 0.85, y_axis_unit = "percent"),
    target_value = 0.9,
    target_text = ">= 90%"
  )

  expect_equal(metadata$y_axis_unit, "percent")
  expect_equal(metadata$target_display, "90%")
  expect_equal(metadata$centerline, "85%")
})

test_that("build_export_analysis_metadata returns action_text matching BFHddl 6-case logic (#175)", {
  # Stable + target + at target -> "fortsæt"
  m1 <- build_export_analysis_metadata(
    bfh_qic_result = make_bfh_result_with_anhoej(centerline = 90, y_axis_unit = "count"),
    target_value = 90,
    target_text = ">= 90"
  )
  expect_match(m1$action_text, "Fortsæt den nuværende praksis")

  # Stable + target + not at target -> "bevidst ændring"
  m2 <- build_export_analysis_metadata(
    bfh_qic_result = make_bfh_result_with_anhoej(centerline = 70, y_axis_unit = "count"),
    target_value = 90,
    target_text = ">= 90"
  )
  expect_match(m2$action_text, "stabil men når ikke målet")

  # Stable + no target -> "fastsæt et mål"
  m3 <- build_export_analysis_metadata(
    bfh_qic_result = make_bfh_result_with_anhoej(centerline = 50, y_axis_unit = "count")
  )
  expect_match(m3$action_text, "fastsætte et mål")

  # Unstable + target + at target -> "ustabil men opfyldt"
  m4 <- build_export_analysis_metadata(
    bfh_qic_result = make_bfh_result_with_anhoej(
      centerline = 90, y_axis_unit = "count", runs_detected = TRUE
    ),
    target_value = 90,
    target_text = ">= 90"
  )
  expect_match(m4$action_text, "målet aktuelt er opfyldt, er processen ustabil")

  # Unstable + target + not at target -> "fjern særlige årsager"
  m5 <- build_export_analysis_metadata(
    bfh_qic_result = make_bfh_result_with_anhoej(
      centerline = 70, y_axis_unit = "count", crossings_detected = TRUE
    ),
    target_value = 90,
    target_text = ">= 90"
  )
  expect_match(m5$action_text, "Prioritér at identificere og fjerne")

  # Unstable + no target -> "undersøg årsager"
  m6 <- build_export_analysis_metadata(
    bfh_qic_result = make_bfh_result_with_anhoej(
      centerline = 50, y_axis_unit = "count", runs_detected = TRUE
    )
  )
  expect_match(m6$action_text, "undersøg årsagerne til den")
})

test_that("build_export_analysis_metadata accepter optional baseline_analysis + signal_examples (#175)", {
  metadata <- build_export_analysis_metadata(
    bfh_qic_result = make_bfh_result_with_anhoej(centerline = 50, y_axis_unit = "count"),
    baseline_analysis = "Processen er stabil omkring 50 enheder.",
    signal_examples = "2024-Q1: kortvarig stigning"
  )

  expect_equal(metadata$baseline_analysis, "Processen er stabil omkring 50 enheder.")
  expect_equal(metadata$signal_examples, "2024-Q1: kortvarig stigning")
})

test_that("build_export_analysis_metadata defaulter baseline_analysis + signal_examples til tom string (#175)", {
  metadata <- build_export_analysis_metadata(
    bfh_qic_result = make_bfh_result_with_anhoej(centerline = 50, y_axis_unit = "count")
  )

  expect_equal(metadata$baseline_analysis, "")
  expect_equal(metadata$signal_examples, "")
})
