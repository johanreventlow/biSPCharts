# Tests for UI Configuration Accessor Functions
# Verify that getter functions provide correct access to UI-related constants
# and handle missing/invalid keys gracefully with fallbacks

library(testthat)

test_that("get_ui_column_width returns correct values for known layout types", {
  sidebar_cols <- get_ui_column_width("sidebar")
  expect_equal(sidebar_cols, c(3, 9), info = "sidebar should be c(3, 9)")

  half_cols <- get_ui_column_width("half")
  expect_equal(half_cols, c(6, 6), info = "half should be c(6, 6)")

  thirds_cols <- get_ui_column_width("thirds")
  expect_equal(thirds_cols, c(4, 4, 4), info = "thirds should be c(4, 4, 4)")

  quarter_cols <- get_ui_column_width("quarter")
  expect_equal(quarter_cols, c(6, 6, 6, 6), info = "quarter should be c(6, 6, 6, 6)")
})

test_that("get_ui_column_width returns NULL for unknown layout types", {
  result <- get_ui_column_width("nonexistent_layout")
  expect_null(result, info = "Should return NULL for unknown layout")
})

test_that("get_ui_column_width defaults to 'sidebar'", {
  result <- get_ui_column_width()
  expect_equal(result, c(3, 9), info = "Default should be sidebar (3, 9)")
})

test_that("get_ui_height returns correct values for known components", {
  expect_equal(get_ui_height("logo"), "40px", info = "logo should be 40px")
  expect_equal(get_ui_height("modal_content"), "300px", info = "modal_content should be 300px")
  expect_equal(get_ui_height("chart_container"), "calc(50vh - 60px)", info = "chart_container should be calc(50vh - 60px)")
  expect_equal(get_ui_height("table_max"), "200px", info = "table_max should be 200px")
  expect_equal(get_ui_height("sidebar_min"), "130px", info = "sidebar_min should be 130px")
})

test_that("get_ui_height returns NULL for unknown components", {
  result <- get_ui_height("nonexistent_component")
  expect_null(result, info = "Should return NULL for unknown component")
})

test_that("get_ui_height defaults to 'chart_container'", {
  result <- get_ui_height()
  expect_equal(result, "calc(50vh - 60px)", info = "Default should be chart_container")
})

test_that("get_ui_style returns correct CSS for known style types", {
  flex_style <- get_ui_style("flex_column")
  expect_true(grepl("flex", flex_style), info = "flex_column should contain flex")
  expect_true(grepl("display", flex_style), info = "flex_column should contain display")

  full_width <- get_ui_style("full_width")
  expect_equal(full_width, "width: 100%;", info = "full_width should be 'width: 100%;'")

  right_align <- get_ui_style("right_align")
  expect_equal(right_align, "text-align: right;", info = "right_align should be 'text-align: right;'")
})

test_that("get_ui_style returns NULL for unknown style types", {
  result <- get_ui_style("nonexistent_style")
  expect_null(result, info = "Should return NULL for unknown style")
})

test_that("get_ui_style defaults to 'flex_column'", {
  result <- get_ui_style()
  expect_true(grepl("flex", result), info = "Default should be flex_column")
})

test_that("get_ui_input_width returns correct values for known width types", {
  expect_equal(get_ui_input_width("full"), "100%", info = "full should be 100%")
  expect_equal(get_ui_input_width("half"), "50%", info = "half should be 50%")
  expect_equal(get_ui_input_width("quarter"), "25%", info = "quarter should be 25%")
  expect_equal(get_ui_input_width("three_quarter"), "75%", info = "three_quarter should be 75%")
  expect_equal(get_ui_input_width("auto"), "auto", info = "auto should be auto")
})

test_that("get_ui_input_width returns NULL for unknown width types", {
  result <- get_ui_input_width("nonexistent_width")
  expect_null(result, info = "Should return NULL for unknown width")
})

test_that("get_ui_input_width defaults to 'full'", {
  result <- get_ui_input_width()
  expect_equal(result, "100%", info = "Default should be full (100%)")
})

test_that("get_ui_layout_proportion returns correct values for known proportions", {
  expect_equal(get_ui_layout_proportion("half"), 0.5, info = "half should be 0.5")
  expect_equal(get_ui_layout_proportion("quarter"), 0.25, info = "quarter should be 0.25")
  expect_equal(get_ui_layout_proportion("three_quarters"), 0.75, info = "three_quarters should be 0.75")

  # Check third and two_thirds with tolerance for floating point
  third <- get_ui_layout_proportion("third")
  expect_true(abs(third - 1/3) < 0.001, info = "third should be ~0.333")

  two_thirds <- get_ui_layout_proportion("two_thirds")
  expect_true(abs(two_thirds - 2/3) < 0.001, info = "two_thirds should be ~0.667")
})

test_that("get_ui_layout_proportion returns NULL for unknown proportions", {
  result <- get_ui_layout_proportion("nonexistent_proportion")
  expect_null(result, info = "Should return NULL for unknown proportion")
})

test_that("get_ui_layout_proportion defaults to 'half'", {
  result <- get_ui_layout_proportion()
  expect_equal(result, 0.5, info = "Default should be half (0.5)")
})

test_that("get_ui_font_scaling returns correct values for known parameters", {
  expect_equal(get_ui_font_scaling("divisor"), 42, info = "divisor should be 42")
  expect_equal(get_ui_font_scaling("min_size"), 8, info = "min_size should be 8")
  expect_equal(get_ui_font_scaling("max_size"), 64, info = "max_size should be 64")
})

test_that("get_ui_font_scaling returns NULL for unknown parameters", {
  result <- get_ui_font_scaling("nonexistent_parameter")
  expect_null(result, info = "Should return NULL for unknown parameter")
})

test_that("get_ui_font_scaling defaults to 'divisor'", {
  result <- get_ui_font_scaling()
  expect_equal(result, 42, info = "Default should be divisor (42)")
})

test_that("get_ui_viewport_default returns correct values for known parameters", {
  expect_equal(get_ui_viewport_default("width"), 800, info = "width should be 800")
  expect_equal(get_ui_viewport_default("height"), 600, info = "height should be 600")
  expect_equal(get_ui_viewport_default("dpi"), 96, info = "dpi should be 96")
})

test_that("get_ui_viewport_default returns NULL for unknown parameters", {
  result <- get_ui_viewport_default("nonexistent_parameter")
  expect_null(result, info = "Should return NULL for unknown parameter")
})

test_that("get_ui_viewport_default defaults to 'width'", {
  result <- get_ui_viewport_default()
  expect_equal(result, 800, info = "Default should be width (800)")
})

test_that("All UI getter functions are callable without arguments", {
  # Verify that all getter functions work with default arguments
  expect_type(get_ui_column_width(), "double")
  expect_type(get_ui_height(), "character")
  expect_type(get_ui_style(), "character")
  expect_type(get_ui_input_width(), "character")
  expect_type(get_ui_layout_proportion(), "double")
  expect_type(get_ui_font_scaling(), "double")
  expect_type(get_ui_viewport_default(), "double")
})

test_that("UI getter functions return appropriate types", {
  # Column widths should be numeric vectors
  expect_type(get_ui_column_width("sidebar"), "double")

  # Heights and styles should be character
  expect_type(get_ui_height("logo"), "character")
  expect_type(get_ui_style("full_width"), "character")

  # Input widths should be character
  expect_type(get_ui_input_width("half"), "character")

  # Proportions and font scaling should be numeric
  expect_type(get_ui_layout_proportion("half"), "double")
  expect_type(get_ui_font_scaling("min_size"), "double")

  # Viewport defaults should be numeric
  expect_type(get_ui_viewport_default("width"), "double")
})
