# Integration: y-akse-grænser (ylim) gennem compute_spc_results_bfh +
# cache-key-invalidering. ylim videreføres til BFHcharts' coord_cartesian.

ylim_test_data <- function() {
  data.frame(
    maaned = seq.Date(as.Date("2023-01-01"), by = "month", length.out = 12),
    # Punkt #12 = 50 ligger uden for ylim c(0, 20) -> må IKKE droppes (zoom).
    vaerdi = c(10, 12, 11, 13, 10, 14, 11, 12, 10, 13, 11, 50)
  )
}

test_that("build_cache_key invaliderer ved ændring af y_axis_min/max", {
  df <- data.frame(x = 1:10, y = as.numeric(1:10))
  base <- build_cache_key(df, "run", "x", "y", NULL, extra_params = list())
  with_min <- build_cache_key(df, "run", "x", "y", NULL,
    extra_params = list(y_axis_min = 0)
  )
  with_max <- build_cache_key(df, "run", "x", "y", NULL,
    extra_params = list(y_axis_min = 0, y_axis_max = 100)
  )
  expect_false(identical(base, with_min))
  expect_false(identical(with_min, with_max))
})

test_that("compute_spc_results_bfh sætter ylim + dropper ikke data", {
  df <- ylim_test_data()
  res_lim <- compute_spc_results_bfh(df,
    x_var = "maaned", y_var = "vaerdi", chart_type = "i",
    y_axis_min = 0, y_axis_max = 20, use_cache = FALSE
  )
  res_free <- compute_spc_results_bfh(df,
    x_var = "maaned", y_var = "vaerdi", chart_type = "i",
    use_cache = FALSE
  )

  expect_equal(res_lim$plot$coordinates$limits$y, c(0, 20))
  # coord_cartesian zoomer, dropper ikke -> samme antal rækker som uden ylim.
  expect_equal(nrow(res_lim$qic_data), nrow(res_free$qic_data))
})

test_that("compute_spc_results_bfh understøtter partiel ylim c(min, NA)", {
  df <- ylim_test_data()
  res <- compute_spc_results_bfh(df,
    x_var = "maaned", y_var = "vaerdi", chart_type = "i",
    y_axis_min = 0, use_cache = FALSE
  )
  expect_equal(res$plot$coordinates$limits$y, c(0, NA))
})

test_that("compute_spc_results_bfh uden grænser lader y datadrevet", {
  df <- ylim_test_data()
  res <- compute_spc_results_bfh(df,
    x_var = "maaned", y_var = "vaerdi", chart_type = "i",
    use_cache = FALSE
  )
  expect_null(res$plot$coordinates$limits$y)
})
