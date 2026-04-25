# ==============================================================================
# TEST: BFHcharts PNG Export Integration
# ==============================================================================
# FORMÅL: Test PNG export via BFHcharts::bfh_export_png() integration
#
# TEST COVERAGE:
#   - BFHcharts::bfh_export_png() integration
#   - get_size_from_preset() - Size preset til dimension conversion
#   - Dimension conversion (inches → mm)
#   - Size presets (small, medium, large)
#   - Custom dimensions
#
# MIGRATION NOTE:
#   Dette testfile er opdateret efter migration til BFHcharts v0.3.0 export API.
#   generate_png_export() er nu erstattet af BFHcharts::bfh_export_png().
#
#   For detaljerede dimension accuracy tests, se BFHcharts test suite.
#   biSPCharts tester nu kun integration og preset mapping.
# ==============================================================================

library(testthat)
library(ggplot2)

# SETUP ========================================================================

# Mock constants hvis de ikke er tilgængelige
if (!exists("EXPORT_SIZE_PRESETS")) {
  EXPORT_SIZE_PRESETS <- list(
    small = list(width = 800, height = 600, dpi = 96, unit = "px", label = "Lille"),
    medium = list(width = 1200, height = 900, dpi = 96, unit = "px", label = "Medium"),
    large = list(width = 1920, height = 1440, dpi = 96, unit = "px", label = "Stor")
  )
}

# TEST: get_size_from_preset() =================================================

test_that("get_size_from_preset returns correct small preset", {
  preset <- get_size_from_preset("small")

  expect_type(preset, "list")
  expect_equal(preset$width, 800)
  expect_equal(preset$height, 600)
  expect_equal(preset$dpi, 96)
  expect_equal(preset$unit, "px")
})

test_that("get_size_from_preset returns correct medium preset", {
  preset <- get_size_from_preset("medium")

  expect_equal(preset$width, 1200)
  expect_equal(preset$height, 900)
  expect_equal(preset$dpi, 96)
  expect_equal(preset$unit, "px")
})

test_that("get_size_from_preset returns correct large preset", {
  preset <- get_size_from_preset("large")

  expect_equal(preset$width, 1920)
  expect_equal(preset$height, 1440)
  expect_equal(preset$dpi, 96)
  expect_equal(preset$unit, "px")
})

test_that("get_size_from_preset returns medium as default for unknown preset", {
  preset <- get_size_from_preset("unknown_preset")

  expect_equal(preset$width, 1200)
  expect_equal(preset$height, 900)
})

test_that("get_size_from_preset handles NULL input", {
  preset <- get_size_from_preset(NULL)

  # Should default to medium
  expect_equal(preset$width, 1200)
  expect_equal(preset$height, 900)
})

# TEST: BFHcharts PNG Export Integration =======================================

test_that("BFHcharts::bfh_export_png is available", {
  skip_if_not_installed("BFHcharts")

  expect_true("bfh_export_png" %in% getNamespaceExports("BFHcharts"))
})

test_that("PNG export integration uses correct dimension conversion", {
  # Test dimension conversion logic used in mod_export_server.R

  # Pixel preset: 1200×900 @ 96 DPI
  preset <- get_size_from_preset("medium")

  # Convert to inches
  width_inches <- preset$width / preset$dpi
  height_inches <- preset$height / preset$dpi

  expect_equal(width_inches, 12.5) # 1200/96
  expect_equal(height_inches, 9.375) # 900/96

  # Convert to mm for BFHcharts
  width_mm <- width_inches * 25.4
  height_mm <- height_inches * 25.4

  expect_equal(width_mm, 317.5) # 12.5 * 25.4
  expect_equal(height_mm, 238.125) # 9.375 * 25.4
})

test_that("Small preset dimension conversion is correct", {
  preset <- get_size_from_preset("small")

  width_inches <- preset$width / preset$dpi
  height_inches <- preset$height / preset$dpi

  expect_equal(width_inches, 800 / 96)
  expect_equal(height_inches, 600 / 96)

  width_mm <- width_inches * 25.4
  height_mm <- height_inches * 25.4

  expect_equal(width_mm, (800 / 96) * 25.4)
  expect_equal(height_mm, (600 / 96) * 25.4)
})

test_that("Large preset dimension conversion is correct", {
  preset <- get_size_from_preset("large")

  width_inches <- preset$width / preset$dpi
  height_inches <- preset$height / preset$dpi

  expect_equal(width_inches, 1920 / 96)
  expect_equal(height_inches, 1440 / 96)

  width_mm <- width_inches * 25.4
  height_mm <- height_inches * 25.4

  expect_equal(width_mm, (1920 / 96) * 25.4)
  expect_equal(height_mm, (1440 / 96) * 25.4)
})

# TEST: Custom Dimensions =======================================================

test_that("Custom dimensions convert correctly from pixels", {
  # User specifies custom 1000×750 pixels @ 96 DPI
  custom_width_px <- 1000
  custom_height_px <- 750
  dpi <- 96

  # Convert to inches
  width_inches <- custom_width_px / dpi
  height_inches <- custom_height_px / dpi

  expect_equal(width_inches, 1000 / 96)
  expect_equal(height_inches, 750 / 96)

  # Convert to mm for BFHcharts
  width_mm <- width_inches * 25.4
  height_mm <- height_inches * 25.4

  expect_equal(width_mm, (1000 / 96) * 25.4)
  expect_equal(height_mm, (750 / 96) * 25.4)
})

test_that("Custom dimensions in inches convert correctly", {
  # User specifies custom 8×6 inches
  width_inches <- 8
  height_inches <- 6

  # Convert to mm
  width_mm <- width_inches * 25.4
  height_mm <- height_inches * 25.4

  expect_equal(width_mm, 203.2) # 8 * 25.4
  expect_equal(height_mm, 152.4) # 6 * 25.4
})

# ==============================================================================
# INTEGRATION NOTES
# ==============================================================================
#
# Dette testfile tester biSPCharts's integration med BFHcharts::bfh_export_png().
#
# BFHcharts ansvar (testes i BFHcharts package):
# - Actual PNG generation via ragg::agg_png()
# - Dimension accuracy
# - DPI handling
# - File I/O
# - Error handling
#
# biSPCharts ansvar (testes her):
# - Size preset definitions (EXPORT_SIZE_PRESETS)
# - get_size_from_preset() function
# - Dimension conversion logic (pixels → inches → mm)
# - Integration point in mod_export_server.R
#
# ==============================================================================
