# test-export-run-count-ignores-denominator.R
#
# Regression: analyse-stien (mod_spc_chart_inputs.R) dropper n_col for run
# chart + "Tal" (count), men build_export_plot sendte mappings$n_column
# uaendret videre. Eksport-fanen viste derfor y/n (fx antal/Uge ~ 1,00)
# mens analyse-fanen viste raa taeller-vaerdier.

skip_if_not_installed("mockery")
skip_if_not_installed("shiny")

make_export_app_state_n <- function(y_axis_unit, chart_type = "run") {
  shiny::reactiveValues(
    data = shiny::reactiveValues(
      current_data = data.frame(
        Uge = 1:3,
        antal = c(10, 20, 30),
        stringsAsFactors = FALSE
      )
    ),
    columns = shiny::reactiveValues(
      mappings = shiny::reactiveValues(
        x_column = "Uge",
        y_column = "antal",
        n_column = "Uge",
        y_axis_unit = y_axis_unit,
        chart_type = chart_type
      ),
      auto_detect = shiny::reactiveValues(
        results = list(x_col = "Uge", y_col = "antal")
      )
    ),
    visualization = shiny::reactiveValues(
      last_valid_config = list(chart_type = chart_type)
    ),
    cache = list(qic = NULL)
  )
}

capture_export_config <- function(app_state) {
  captured <- new.env(parent = emptyenv())
  mockery::stub(build_export_plot, "generateSPCPlot", function(...) {
    args <- list(...)
    captured$config <- args$config
    captured$y_axis_unit <- args$y_axis_unit
    list(plot = "sentinel-plot", bfh_qic_result = list(plot = "sentinel-plot"))
  })
  shiny::isolate(build_export_plot(
    app_state = app_state,
    title_input = "Test",
    dept_input = "Dept",
    plot_context = "export_pdf"
  ))
  captured
}

test_that("build_export_plot dropper naevner for run chart + count (som analyse-stien)", {
  skip_if_not(exists("build_export_plot", mode = "function"))
  withr::local_options(shiny.reactiveConsole = TRUE)

  captured <- capture_export_config(make_export_app_state_n(y_axis_unit = "count"))
  expect_null(captured$config$n_col)
  expect_equal(captured$config$y_col, "antal")
  expect_equal(captured$y_axis_unit, "count")
})

test_that("build_export_plot bevarer naevner for run chart + percent", {
  skip_if_not(exists("build_export_plot", mode = "function"))
  withr::local_options(shiny.reactiveConsole = TRUE)

  captured <- capture_export_config(make_export_app_state_n(y_axis_unit = "percent"))
  expect_equal(captured$config$n_col, "Uge")
  expect_equal(captured$y_axis_unit, "percent")
})
