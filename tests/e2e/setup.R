# ==============================================================================
# tests/e2e/setup.R
# ==============================================================================
# Delt helper-kode for E2E-tests. Sources automatisk af testthat::test_dir
# via filnavn-konvention (det er dog ikke "helper-*" — så skal manuelt sources
# fra hver test-fil eller fra run_e2e.R).
#
# §4.1 af harden-test-suite-regression-gate.
# ==============================================================================

suppressPackageStartupMessages(library(testthat))
suppressPackageStartupMessages(library(shiny))

# ------------------------------------------------------------------------------
# Chrome-availability gate
# ------------------------------------------------------------------------------

#' Skip test hvis Chrome/Chromium ikke tilgængelig
skip_if_no_chrome <- function() {
  if (!requireNamespace("shinytest2", quietly = TRUE)) {
    skip("shinytest2 ikke installeret")
  }
  if (!requireNamespace("chromote", quietly = TRUE)) {
    skip("chromote ikke installeret")
  }
  chrome_path <- tryCatch(shinytest2::detect_chrome(),
    error = function(e) ""
  )
  if (!nzchar(chrome_path)) {
    skip("Chrome/Chromium ikke fundet")
  }

  if (Sys.getenv("CI_SKIP_SHINYTEST2", "false") %in% c("true", "TRUE", "1")) {
    skip("CI_SKIP_SHINYTEST2 env-flag sat")
  }
  invisible(TRUE)
}

# ------------------------------------------------------------------------------
# AppDriver factory
# ------------------------------------------------------------------------------

#' Opret shinytest2 AppDriver konfigureret til biSPCharts
#'
#' Kræver at pkgload::load_all() er kørt eller pakken er installeret.
create_biSPCharts_driver <- function(timeout = 30 * 1000,
                                     load_timeout = 30 * 1000,
                                     ...) {
  skip_if_no_chrome()

  project_root <- tryCatch(
    trimws(system2("git", c("rev-parse", "--show-toplevel"),
      stdout = TRUE, stderr = FALSE
    )),
    error = function(e) getwd()
  )

  # Brug pakke-leveret run_app() hvis biSPCharts er loaded
  app_expr <- if ("biSPCharts" %in% loadedNamespaces()) {
    quote(biSPCharts::run_app())
  } else {
    # Fallback: source global.R + run via shiny::shinyApp
    source(file.path(project_root, "global.R"), local = TRUE)
    quote(shiny::shinyApp(ui = app_ui(), server = app_server))
  }

  shinytest2::AppDriver$new(
    app_dir = app_expr,
    name = "biSPCharts-e2e",
    timeout = timeout,
    load_timeout = load_timeout,
    ...
  )
}
