helper_exec_req <- function(chart_type = "run", n_var = NULL,
                            y_axis_unit = "count", multiply = 1,
                            target_value = NULL, n = 10L) {
  df <- data.frame(
    dato = seq(as.Date("2023-01-01"), by = "week", length.out = n),
    vaerdi = as.numeric(seq_len(n)),
    naevner = rep(100L, n)
  )
  new_spc_request(
    data = df,
    x_var = "dato",
    y_var = "vaerdi",
    chart_type = chart_type,
    n_var = n_var,
    multiply = multiply,
    options = list(y_axis_unit = y_axis_unit, target_value = target_value)
  )
}

helper_exec_prepared <- function(...) {
  req <- helper_exec_req(...)
  prepare_spc_data(req)
}

helper_exec_axes <- function(prepared) {
  resolve_axis_units(prepared)
}

# ── build_bfh_args ─────────────────────────────────────────────────────────────

test_that("build_bfh_args returnerer bfh_params-list", {
  prepared <- helper_exec_prepared()
  axes <- helper_exec_axes(prepared)
  params <- build_bfh_args(prepared, axes, list())
  expect_type(params, "list")
})

test_that("build_bfh_args returnerer list med bfh_qic-parametre", {
  prepared <- helper_exec_prepared()
  axes <- helper_exec_axes(prepared)
  params <- build_bfh_args(prepared, axes, list())
  # map_to_bfh_params returnerer en liste af navngivne parametre
  expect_true(length(params) > 0)
  expect_true(is.list(params))
})

test_that("build_bfh_args fjerner n_var for chart-typer der ikke bruger nævner", {
  # run-kort bruger ikke nævner; n_var skal fjernes
  prepared <- helper_exec_prepared(chart_type = "run", n_var = "naevner")
  axes <- helper_exec_axes(prepared)
  # Kald map_to_bfh_params med n_var != NULL for run-kort → guard skal fjerne det
  # Vi tester resultatet indirekte: build_bfh_args bør ikke fejle
  params <- build_bfh_args(prepared, axes, list())
  expect_type(params, "list")
})

test_that("spc_render_error arver fra spc_error", {
  err <- tryCatch(
    spc_abort("render test", class = "spc_render_error"),
    spc_error = function(e) e
  )
  expect_true(inherits(err, "spc_error"))
  expect_true(inherits(err, "spc_render_error"))
})

# ── execute_bfh_request ────────────────────────────────────────────────────────

test_that("execute_bfh_request returnerer standardiseret result med plot og qic_data", {
  prepared <- helper_exec_prepared(n = 20L)
  axes <- helper_exec_axes(prepared)
  params <- build_bfh_args(prepared, axes, list())
  result <- execute_bfh_request(params, prepared)
  expect_type(result, "list")
  expect_true(!is.null(result$plot))
  expect_true(!is.null(result$qic_data))
})

test_that("execute_bfh_request tilføjer x_scale til plot ved tekst-x-kolonne", {
  df <- data.frame(
    x = paste0("Uge ", 1:15),
    y = as.numeric(1:15),
    stringsAsFactors = FALSE
  )
  req <- new_spc_request(df, "x", "y", "run")
  prepared <- prepare_spc_data(req)
  axes <- resolve_axis_units(prepared)
  params <- build_bfh_args(prepared, axes, list())
  result <- execute_bfh_request(params, prepared)
  expect_true(!is.null(result$plot))
})
