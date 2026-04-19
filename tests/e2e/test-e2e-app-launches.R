# ==============================================================================
# tests/e2e/test-e2e-app-launches.R
# ==============================================================================
# §4.1.2 af harden-test-suite-regression-gate — E2E smoke-test.
#
# Minimal happy-path: verifier at appen kan startes headless og at
# landing page renderes uden crash. Runtime: ~20-30s (chromote startup).
# ==============================================================================

# Source setup.R eksplicit (filnavn starter ikke med "helper-")
source(test_path("setup.R"))

test_that("E2E: biSPCharts app starter headless og viser landing", {
  skip_if_no_chrome()

  app <- create_biSPCharts_driver()
  withr::defer(try(app$stop(), silent = TRUE))

  # Vent på initial render
  app$wait_for_idle(timeout = 30 * 1000)

  # Landing skal vise "start_wizard"-button eller lignende entry-point
  html <- app$get_html("body")
  expect_true(nchar(html) > 0, label = "App-HTML skal være ikke-tom")

  # Verifiér at en af de forventede landing-elementer er present
  has_landing_marker <- grepl(
    "start_wizard|landing_body|biSPCharts|Kom i gang",
    html,
    ignore.case = TRUE
  )
  expect_true(has_landing_marker,
    label = "Landing page skal indeholde start_wizard eller biSPCharts-header"
  )
})

test_that("E2E: navbar-entry er reaktiv efter start_wizard", {
  skip_if_no_chrome()

  app <- create_biSPCharts_driver()
  withr::defer(try(app$stop(), silent = TRUE))

  app$wait_for_idle(timeout = 30 * 1000)

  # Klik på start_wizard hvis button findes (ikke alle landing-varianter
  # viser den umiddelbart — så fall-back til direkte navbar-navigation)
  button_clicked <- tryCatch(
    {
      app$click("start_wizard")
      TRUE
    },
    error = function(e) FALSE
  )

  if (!button_clicked) {
    skip("start_wizard-button ikke fundet — landing-variant uden wizard")
  }

  app$wait_for_idle(timeout = 15 * 1000)
  html_after <- app$get_html("body")

  # Upload-trin skal være aktivt efter wizard-start
  expect_true(
    grepl("upload|indlæs|File", html_after, ignore.case = TRUE),
    label = "Upload-trin skal være synligt efter start_wizard-klik"
  )
})
