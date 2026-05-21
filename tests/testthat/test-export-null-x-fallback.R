# test-export-null-x-fallback.R
#
# Regression-test: build_export_plot skal tolerere NULL x_column paa samme
# maade som analyse-pathen i generateSPCPlot, der falder tilbage til en
# syntetisk spc_row_index naar x mangler (R/fct_spc_plot_generation.R:115-126).
#
# Foer fix: build_export_plot returnerede NULL ved manglende x -> preview blev
# aldrig rendret og PDF/PNG-download fejlede med "Ingen plot tilgaengeligt".
# Resultat: bruger saa fungerende chart i analyse-fanen men hverken preview
# eller eksport i eksport-fanen (asymmetrisk adfaerd, daarligt signal).

skip_if_not_installed("mockery")
skip_if_not_installed("shiny")

make_export_app_state <- function(x_column = NULL, y_column = "value",
                                  x_col_auto = NULL, y_col_auto = "value") {
  shiny::reactiveValues(
    data = shiny::reactiveValues(
      current_data = data.frame(
        label = c("Uge 1", "Uge 2", "Uge 3"),
        value = c(10, 20, 30),
        stringsAsFactors = FALSE
      )
    ),
    columns = shiny::reactiveValues(
      mappings = shiny::reactiveValues(
        x_column = x_column,
        y_column = y_column,
        n_column = NULL,
        chart_type = "run"
      ),
      auto_detect = shiny::reactiveValues(
        results = list(x_col = x_col_auto, y_col = y_col_auto)
      )
    ),
    visualization = shiny::reactiveValues(
      last_valid_config = list(chart_type = "run")
    ),
    cache = list(qic = NULL)
  )
}

test_that("build_export_plot tolererer NULL x_column naar y er sat", {
  if (!exists("build_export_plot", mode = "function")) {
    # SKIP-REASON: env -- build_export_plot kraever load_all() context
    skip("build_export_plot ikke tilgaengelig")
  }
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- make_export_app_state(x_column = NULL, y_column = "value")

  captured <- new.env(parent = emptyenv())
  captured$config <- NULL
  mockery::stub(build_export_plot, "generateSPCPlot", function(...) {
    args <- list(...)
    captured$config <- args$config
    captured$app_state <- args$app_state
    list(
      plot = "sentinel-plot",
      bfh_qic_result = list(plot = "sentinel-plot")
    )
  })

  result <- shiny::isolate(build_export_plot(
    app_state = app_state,
    title_input = "Test",
    dept_input = "Dept",
    plot_context = "export_pdf"
  ))

  expect_false(is.null(result),
    info = "build_export_plot skal IKKE returnere NULL ved manglende x -- generateSPCPlot haandterer fallback"
  )
  expect_equal(result$plot, "sentinel-plot")
  expect_null(captured$config$x_col,
    info = "x_col propageres som NULL saa generateSPCPlot-fallback til spc_row_index aktiveres"
  )
  expect_equal(captured$config$y_col, "value")
  expect_identical(captured$app_state, app_state,
    info = "app_state skal sendes videre saa export-pathen kan bruge SPC-cache"
  )
})

test_that("build_export_plot returnerer NULL ved manglende y_column", {
  if (!exists("build_export_plot", mode = "function")) {
    # SKIP-REASON: env -- build_export_plot kraever load_all() context
    skip("build_export_plot ikke tilgaengelig")
  }
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- make_export_app_state(
    x_column = "label", y_column = NULL,
    x_col_auto = "label", y_col_auto = NULL
  )

  generate_spc_called <- FALSE
  mockery::stub(build_export_plot, "generateSPCPlot", function(...) {
    generate_spc_called <<- TRUE
    list(plot = "should-not-reach", bfh_qic_result = list())
  })

  result <- shiny::isolate(build_export_plot(
    app_state = app_state,
    title_input = "Test",
    dept_input = "Dept",
    plot_context = "export_pdf"
  ))

  expect_null(result, info = "y er hard-requirement -- uden y er der intet at plotte")
  expect_false(generate_spc_called,
    info = "generateSPCPlot maa ikke kaldes naar y mangler"
  )
})

test_that("preview_ready evaluerer uden at blokere naar x_column er NULL", {
  # Regression: tidligere blokerede shiny::req(mappings$x_column) preview-
  # reactive'erne (export_plot + pdf_export_plot) naar auto-detect ikke kunne
  # gaette x. Effekt: preview blev aldrig rendret, selvom analyse-pathen viste
  # fungerende chart via spc_row_index-fallback. Fix: x_column fjernet fra
  # req()-listerne i begge reactive'er.
  if (!exists("mod_export_server", mode = "function")) {
    # SKIP-REASON: env -- mod_export_server kraever fuldt load_all() context
    skip("mod_export_server ikke tilgaengelig")
  }

  app_state <- shiny::reactiveValues(
    data = shiny::reactiveValues(
      current_data = data.frame(
        Observation = c("A", "B", "C", "D", "E"),
        value = c(10, 12, 11, 13, 12),
        stringsAsFactors = FALSE
      )
    ),
    columns = shiny::reactiveValues(
      mappings = shiny::reactiveValues(
        x_column = NULL,
        y_column = "value",
        n_column = NULL,
        chart_type = "run"
      ),
      auto_detect = shiny::reactiveValues(
        results = list(x_col = NULL, y_col = "value")
      )
    ),
    visualization = shiny::reactiveValues(
      last_valid_config = list(chart_type = "run"),
      plot_object = NULL,
      plot_ready = TRUE
    ),
    session = shiny::reactiveValues(active_tab = "eksporter"),
    events = shiny::reactiveValues()
  )

  shiny::testServer(mod_export_server, args = list(app_state = app_state), {
    suppressWarnings(session$flushReact())
    returned <- session$returned
    ready_value <- tryCatch(returned$preview_ready(),
      error = function(e) NULL
    )
    # Med NULL x_column og valid y_column skal preview_ready evaluere uden
    # at req() blokerer hele reactive-grafen. Vi accepterer baade FALSE
    # (fx hvis Quarto mangler) og TRUE -- nogensinde NULL betyder req()
    # blokerede early og reactive blev droppet.
    expect_true(is.logical(ready_value),
      label = "preview_ready skal evaluere til logical -- ikke droppet af req(x_column)"
    )
  })
})

test_that("build_export_plot bruger auto_detect$results$x_col som fallback for mappings", {
  if (!exists("build_export_plot", mode = "function")) {
    # SKIP-REASON: env -- build_export_plot kraever load_all() context
    skip("build_export_plot ikke tilgaengelig")
  }
  withr::local_options(shiny.reactiveConsole = TRUE)

  # Scenarie: mappings$x_column er tom streng (normalize_mapping -> NULL),
  # men auto_detect har en gyldig x_col. Fallback skal aktiveres.
  app_state <- make_export_app_state(
    x_column = "", y_column = "value",
    x_col_auto = "label", y_col_auto = "value"
  )

  captured <- new.env(parent = emptyenv())
  captured$config <- NULL
  mockery::stub(build_export_plot, "generateSPCPlot", function(...) {
    args <- list(...)
    captured$config <- args$config
    list(plot = "ok", bfh_qic_result = list())
  })

  result <- shiny::isolate(build_export_plot(
    app_state = app_state,
    title_input = "Test",
    dept_input = "Dept",
    plot_context = "export_pdf"
  ))

  expect_false(is.null(result))
  expect_equal(captured$config$x_col, "label",
    info = "tom mapping -> fallback til auto_detect$results$x_col"
  )
})

test_that("build_export_plot genbruger SPC-cache for identisk export_pdf", {
  if (!exists("build_export_plot", mode = "function") ||
    !exists("get_or_init_qic_cache", mode = "function")) {
    # SKIP-REASON: env -- kræver fuldt load_all() context med export/cache helpers
    skip("Export/cache helpers ikke tilgaengelige")
  }
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- make_export_app_state(
    x_column = "label", y_column = "value",
    x_col_auto = "label", y_col_auto = "value"
  )

  first <- shiny::isolate(build_export_plot(
    app_state = app_state,
    title_input = "Cache test",
    dept_input = "Dept",
    plot_context = "export_pdf"
  ))
  second <- shiny::isolate(build_export_plot(
    app_state = app_state,
    title_input = "Cache test",
    dept_input = "Dept",
    plot_context = "export_pdf"
  ))

  expect_false(is.null(first))
  expect_false(is.null(second))

  cache_stats <- shiny::isolate(get_or_init_qic_cache(app_state)$stats())
  expect_true(cache_stats$hits >= 1L,
    info = "Andet identiske export_pdf-kald skal ramme SPC-cache"
  )
})
