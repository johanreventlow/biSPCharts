helper_decorate_inputs <- function(n = 15L, chart_type = "run") {
  df <- data.frame(
    dato = seq(as.Date("2023-01-01"), by = "week", length.out = n),
    vaerdi = as.numeric(seq_len(n))
  )
  req <- new_spc_request(df, "dato", "vaerdi", chart_type)
  prepared <- prepare_spc_data(req)
  axes <- resolve_axis_units(prepared)
  params <- build_bfh_args(prepared, axes, list())
  standardized <- execute_bfh_request(params, prepared)
  list(standardized = standardized, prepared = prepared)
}

test_that("decorate_plot_for_display returnerer list med backend-flag", {
  inputs <- helper_decorate_inputs()
  result <- decorate_plot_for_display(inputs$standardized, inputs$prepared)
  expect_equal(result$metadata$backend, "bfhcharts")
})

test_that("decorate_plot_for_display bevarer eksisterende plot og qic_data", {
  inputs <- helper_decorate_inputs()
  original_nrow <- nrow(inputs$standardized$qic_data)
  result <- decorate_plot_for_display(inputs$standardized, inputs$prepared)
  expect_equal(nrow(result$qic_data), original_nrow)
  expect_true(!is.null(result$plot))
})

test_that("decorate_plot_for_display udløser ikke Anhøj-fallback når anhoej_rules er til stede", {
  inputs <- helper_decorate_inputs()
  # Sæt anhoej_rules manuelt til at verificere ingen overskrivning
  inputs$standardized$metadata$anhoej_rules <- list(
    runs_detected = FALSE,
    crossings_detected = FALSE,
    longest_run = 2L,
    n_crossings = 5L,
    n_crossings_min = 3L
  )
  result <- decorate_plot_for_display(inputs$standardized, inputs$prepared)
  # Eksisterende anhoej_rules skal bevares
  expect_false(result$metadata$anhoej_rules$runs_detected)
  expect_equal(result$metadata$anhoej_rules$longest_run, 2L)
})

test_that("decorate_plot_for_display metadata indeholder signals_detected", {
  inputs <- helper_decorate_inputs()
  result <- decorate_plot_for_display(inputs$standardized, inputs$prepared)
  expect_true("signals_detected" %in% names(result$metadata))
})
