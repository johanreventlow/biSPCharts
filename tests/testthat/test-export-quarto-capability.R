# ==============================================================================
# test-export-quarto-capability.R
# ==============================================================================
# Tests for check_quarto_capability() og validate_export_dpi() helpers.
# Bruger mockery til at isolere system2() og Sys.which() kald.
#
# Bemærk om caching: check_quarto_capability() cacher resultatet per R-session.
# Tests der bruger mockery::stub() på Sys.which/system2 skal rydde cachen
# via biSPCharts:::.quarto_capability_cache$set(NULL) i setup.
#
# Task 6 af harden-export-quarto-capability OpenSpec change (#319).
# ==============================================================================

# Hjælper: ryd session-cache og kør check_quarto_capability med mocks
with_quarto_mock <- function(which_returns, version_returns, code) {
  # Ryd cache saa mockede systemkald faktisk eksekveres
  old_cache <- biSPCharts:::.quarto_capability_cache$get()
  biSPCharts:::.quarto_capability_cache$set(NULL)
  on.exit(biSPCharts:::.quarto_capability_cache$set(old_cache), add = TRUE)

  mockery::stub(check_quarto_capability, "Sys.which", function(...) which_returns)
  if (!is.null(version_returns)) {
    mockery::stub(check_quarto_capability, "system2", function(...) version_returns)
  }
  code
}

# check_quarto_capability() ---------------------------------------------------

test_that("check_quarto_capability returnerer FALSE hvis quarto ikke er i PATH", {
  biSPCharts:::.quarto_capability_cache$set(NULL)
  on.exit(biSPCharts:::.quarto_capability_cache$set(NULL), add = TRUE)

  mockery::stub(check_quarto_capability, "Sys.which", function(...) "")
  cap <- check_quarto_capability()

  expect_false(cap$available)
  expect_false(cap$typst_supported)
  expect_true(is.na(cap$quarto_version))
  expect_match(cap$message, "Quarto ikke fundet")
})

test_that("check_quarto_capability returnerer TRUE med version 1.4", {
  biSPCharts:::.quarto_capability_cache$set(NULL)
  on.exit(biSPCharts:::.quarto_capability_cache$set(NULL), add = TRUE)

  mockery::stub(check_quarto_capability, "Sys.which", function(...) "/usr/bin/quarto")
  mockery::stub(check_quarto_capability, "system2", function(...) "1.4.0")
  cap <- check_quarto_capability()

  expect_true(cap$available)
  expect_true(cap$typst_supported)
  expect_equal(cap$quarto_version, "1.4.0")
  expect_match(cap$message, "Typst-unders")
})

test_that("check_quarto_capability returnerer FALSE for version 1.2", {
  biSPCharts:::.quarto_capability_cache$set(NULL)
  on.exit(biSPCharts:::.quarto_capability_cache$set(NULL), add = TRUE)

  mockery::stub(check_quarto_capability, "Sys.which", function(...) "/usr/bin/quarto")
  mockery::stub(check_quarto_capability, "system2", function(...) "1.2.0")
  cap <- check_quarto_capability()

  expect_true(cap$available)
  expect_false(cap$typst_supported)
  expect_match(cap$message, "1\\.3\\+")
})

test_that("check_quarto_capability returnerer TRUE for version 1.3.0 (graensevaerdi)", {
  biSPCharts:::.quarto_capability_cache$set(NULL)
  on.exit(biSPCharts:::.quarto_capability_cache$set(NULL), add = TRUE)

  mockery::stub(check_quarto_capability, "Sys.which", function(...) "/usr/local/bin/quarto")
  mockery::stub(check_quarto_capability, "system2", function(...) "1.3.0")
  cap <- check_quarto_capability()

  expect_true(cap$available)
  expect_true(cap$typst_supported)
})

test_that("check_quarto_capability haandterer system2-fejl gracefully", {
  biSPCharts:::.quarto_capability_cache$set(NULL)
  on.exit(biSPCharts:::.quarto_capability_cache$set(NULL), add = TRUE)

  mockery::stub(check_quarto_capability, "Sys.which", function(...) "/usr/bin/quarto")
  mockery::stub(check_quarto_capability, "system2", function(...) stop("system2 fejlede"))
  cap <- check_quarto_capability()

  # Quarto fundet i PATH, men version-parse fejlede => typst_supported FALSE
  expect_true(cap$available)
  expect_false(cap$typst_supported)
})

# validate_export_dpi() -------------------------------------------------------

test_that("validate_export_dpi accepterer gyldige DPI-vaerdier", {
  expect_invisible(validate_export_dpi(72))
  expect_invisible(validate_export_dpi(150))
  expect_invisible(validate_export_dpi(300))
  expect_invisible(validate_export_dpi(600))
})

test_that("validate_export_dpi kaster export_input_error ved DPI under 72", {
  expect_error(
    validate_export_dpi(50),
    class = "export_input_error"
  )
})

test_that("validate_export_dpi kaster export_input_error ved DPI over 600", {
  expect_error(
    validate_export_dpi(601),
    class = "export_input_error"
  )
})

test_that("validate_export_dpi kaster export_input_error ved ikke-numerisk input", {
  expect_error(
    validate_export_dpi("150"),
    class = "export_input_error"
  )
  expect_error(
    validate_export_dpi(NA),
    class = "export_input_error"
  )
})

test_that("validate_export_dpi kaster export_input_error ved vektor-input", {
  expect_error(
    validate_export_dpi(c(150, 300)),
    class = "export_input_error"
  )
})

test_that("export_input_error arver fra spc_error", {
  err <- tryCatch(
    validate_export_dpi(50),
    error = function(e) e
  )
  expect_true(inherits(err, "spc_error"))
  expect_true(inherits(err, "export_input_error"))
})
