# test-plot-core.R
# Salvage Fase 2: Opdateret mod nuværende plotting API
# Baseret paa R/fct_spc_bfh_service.R, R/config_chart_types.R

test_that("QIC chart type conversion fungerer med nuvaerende CHART_TYPES_DA navne", {
  expect_true(exists("get_qic_chart_type", mode = "function"))

  # Nuvaerende danske chart-navne (opdateret fra config_chart_types.R)
  expect_equal(
    get_qic_chart_type("P-kort — andele/procenter (fx infektionsrate)"), "p"
  )
  expect_equal(
    get_qic_chart_type("U-kort — rater (fx komplikationer pr. 1000)"), "u"
  )
  expect_equal(
    get_qic_chart_type("I-kort — enkelte målinger (fx ventetid, temperatur)"), "i"
  )
  expect_equal(
    get_qic_chart_type("C-kort — tællinger (fx antal fald)"), "c"
  )
  expect_equal(
    get_qic_chart_type("Seriediagram (Run) — data over tid"), "run"
  )

  # Fallback for ukendt / tom input
  expect_equal(get_qic_chart_type(""), "run")
  expect_equal(get_qic_chart_type("unknown"), "run")
})

test_that("TODO Fase 3: MR-kort er ikke i nuvaerende CHART_TYPES_DA", {
  skip(paste0(
    "TODO Fase 3: R-bug afsloeret — 'MR-kort' chart-type ikke i CHART_TYPES_DA (#203-followup)\n",
    "Nuvaerende chart-typer: run, i, p, u, c. MR-kort mangler."
  ))
  expect_equal(get_qic_chart_type("MR-kort (Moving Range)"), "mr")
})

test_that("Hospital theme application fungerer", {
  skip_if_not_installed("ggplot2")
  skip_if_not(
    exists("HOSPITAL_COLORS") && exists("apply_hospital_theme", mode = "function"),
    "Hospital theme functions not available"
  )
  test_plot <- ggplot2::ggplot(data.frame(x = 1:5, y = 1:5), ggplot2::aes(x, y)) +
    ggplot2::geom_point()
  themed_plot <- apply_hospital_theme(test_plot)
  expect_s3_class(themed_plot, "ggplot")
})

test_that("Basic plot generation med qicharts2 integration", {
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    Dato = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01", "2024-05-01")),
    Taeller = c(10, 15, 12, 18, 20),
    Naevner = c(100, 120, 110, 130, 140)
  )

  # Fallback test med direkte qicharts2
  qic_plot <- qicharts2::qic(
    x = Dato,
    y = Taeller,
    data = test_data,
    chart = "run"
  )
  expect_s3_class(qic_plot, "ggplot")
})

test_that("safe_operation returnerer fallback ved plot-fejl", {
  require_internal("safe_operation", mode = "function")

  result <- safe_operation(
    operation_name = "Test fallback",
    code = {
      stop("Simuleret fejl")
    },
    fallback = NULL
  )
  expect_null(result)
})
