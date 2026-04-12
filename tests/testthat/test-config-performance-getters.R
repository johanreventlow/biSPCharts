# Tests for Performance Configuration Accessor Functions
# Verify that getter functions provide correct access to performance constants
# and handle missing/invalid keys gracefully with fallbacks

library(testthat)

test_that("get_debounce_delay returns correct values for known operations", {
  expect_equal(get_debounce_delay("input_change"), 150, info = "input_change should be 150ms")
  expect_equal(get_debounce_delay("file_select"), 500, info = "file_select should be 500ms")
  expect_equal(get_debounce_delay("chart_update"), 500, info = "chart_update should be 500ms")
  expect_equal(get_debounce_delay("table_cleanup"), 2000, info = "table_cleanup should be 2000ms")
})

test_that("get_debounce_delay returns fallback for unknown operations", {
  result <- get_debounce_delay("nonexistent_operation")
  expect_equal(result, 500, info = "Should return 500ms fallback for unknown operation")
})

test_that("get_debounce_delay defaults to 'input_change' when no argument provided", {
  result <- get_debounce_delay()
  expect_equal(result, 150, info = "Default should be input_change (150ms)")
})

test_that("get_operation_timeout returns correct values for known operations", {
  expect_equal(get_operation_timeout("file_read"), 30000, info = "file_read should be 30000ms")
  expect_equal(get_operation_timeout("chart_render"), 10000, info = "chart_render should be 10000ms")
  expect_equal(get_operation_timeout("auto_detect"), 5000, info = "auto_detect should be 5000ms")
  expect_equal(get_operation_timeout("ui_update"), 2000, info = "ui_update should be 2000ms")
})

test_that("get_operation_timeout returns fallback for unknown operations", {
  result <- get_operation_timeout("nonexistent_operation")
  expect_equal(result, 10000, info = "Should return 10000ms fallback for unknown operation")
})

test_that("get_operation_timeout defaults to 'chart_render' when no argument provided", {
  result <- get_operation_timeout()
  expect_equal(result, 10000, info = "Default should be chart_render (10000ms)")
})

test_that("get_performance_threshold returns correct values for known metrics", {
  expect_equal(get_performance_threshold("reactive_warning"), 0.5, info = "reactive_warning should be 0.5")
  expect_equal(get_performance_threshold("debounce_warning"), 1.0, info = "debounce_warning should be 1.0")
  expect_equal(get_performance_threshold("memory_warning"), 10, info = "memory_warning should be 10")
  expect_equal(get_performance_threshold("cache_timeout_default"), 300, info = "cache_timeout_default should be 300")
  # Note: max_cache_entries is in CACHE_CONFIG, not PERFORMANCE_THRESHOLDS
})

test_that("get_performance_threshold returns NULL for unknown metrics", {
  result <- get_performance_threshold("nonexistent_metric")
  expect_null(result, info = "Should return NULL for unknown metric")
})

test_that("get_performance_threshold defaults to 'reactive_warning'", {
  result <- get_performance_threshold()
  expect_equal(result, 0.5, info = "Default should be reactive_warning (0.5)")
})

test_that("get_cache_config returns correct values for known settings", {
  expect_equal(get_cache_config("default_timeout_seconds"), 300, info = "default_timeout_seconds should be 300")
  expect_equal(get_cache_config("extended_timeout_seconds"), 600, info = "extended_timeout_seconds should be 600")
  expect_equal(get_cache_config("short_timeout_seconds"), 60, info = "short_timeout_seconds should be 60")
  expect_equal(get_cache_config("size_limit_entries"), 50, info = "size_limit_entries should be 50")
  expect_equal(get_cache_config("cleanup_interval_seconds"), 300, info = "cleanup_interval_seconds should be 300")
})

test_that("get_cache_config returns NULL for unknown settings", {
  result <- get_cache_config("nonexistent_setting")
  expect_null(result, info = "Should return NULL for unknown setting")
})

test_that("get_cache_config defaults to 'default_timeout_seconds'", {
  result <- get_cache_config()
  expect_equal(result, 300, info = "Default should be default_timeout_seconds (300)")
})

test_that("get_autosave_delay returns correct values for known contexts", {
  expect_equal(get_autosave_delay("data_save"), 2000, info = "data_save should be 2000ms")
  expect_equal(get_autosave_delay("settings_save"), 1000, info = "settings_save should be 1000ms")
})

test_that("get_autosave_delay returns fallback for unknown contexts", {
  result <- get_autosave_delay("nonexistent_context")
  expect_equal(result, 2000, info = "Should return 2000ms fallback for unknown context")
})

test_that("get_autosave_delay defaults to 'data_save'", {
  result <- get_autosave_delay()
  expect_equal(result, 2000, info = "Default should be data_save (2000ms)")
})

test_that("get_loop_protection_delay returns correct values for known scenarios", {
  expect_equal(get_loop_protection_delay("default"), 500, info = "default should be 500ms")
  expect_equal(get_loop_protection_delay("conservative"), 800, info = "conservative should be 800ms")
  expect_equal(get_loop_protection_delay("minimal"), 200, info = "minimal should be 200ms")
  expect_equal(get_loop_protection_delay("onFlushed_fallback"), 1000, info = "onFlushed_fallback should be 1000ms")
})

test_that("get_loop_protection_delay returns fallback for unknown scenarios", {
  result <- get_loop_protection_delay("nonexistent_scenario")
  expect_equal(result, 500, info = "Should return 500ms fallback for unknown scenario")
})

test_that("get_loop_protection_delay defaults to 'default'", {
  result <- get_loop_protection_delay()
  expect_equal(result, 500, info = "Default should be default (500ms)")
})

test_that("get_ui_update_delay returns correct values for known update types", {
  expect_equal(get_ui_update_delay("immediate_delay"), 0, info = "immediate_delay should be 0ms")
  expect_equal(get_ui_update_delay("fast_update_delay"), 50, info = "fast_update_delay should be 50ms")
  expect_equal(get_ui_update_delay("standard_update_delay"), 100, info = "standard_update_delay should be 100ms")
  expect_equal(get_ui_update_delay("safe_programmatic_delay"), 150, info = "safe_programmatic_delay should be 150ms")
})

test_that("get_ui_update_delay returns fallback for unknown update types", {
  result <- get_ui_update_delay("nonexistent_type")
  expect_equal(result, 100, info = "Should return 100ms fallback for unknown type")
})

test_that("get_ui_update_delay defaults to 'standard_update_delay'", {
  result <- get_ui_update_delay()
  expect_equal(result, 100, info = "Default should be standard_update_delay (100ms)")
})

test_that("get_test_mode_config returns correct values for known settings", {
  expect_equal(get_test_mode_config("ready_event_delay_seconds"), 1.5, info = "ready_event_delay_seconds should be 1.5")
  expect_equal(get_test_mode_config("startup_debounce_ms"), 300, info = "startup_debounce_ms should be 300")
  expect_equal(get_test_mode_config("auto_detect_delay_ms"), 250, info = "auto_detect_delay_ms should be 250")
  expect_equal(get_test_mode_config("lazy_plot_generation"), TRUE, info = "lazy_plot_generation should be TRUE")
})

test_that("get_test_mode_config returns NULL for unknown settings", {
  result <- get_test_mode_config("nonexistent_setting")
  expect_null(result, info = "Should return NULL for unknown setting")
})

test_that("get_test_mode_config defaults to 'ready_event_delay_seconds'", {
  result <- get_test_mode_config()
  expect_equal(result, 1.5, info = "Default should be ready_event_delay_seconds (1.5)")
})

test_that("All getter functions are callable without arguments", {
  # Verify that all getter functions work with default arguments
  expect_type(get_debounce_delay(), "double")
  expect_type(get_operation_timeout(), "double")
  expect_type(get_performance_threshold(), "double")
  expect_type(get_cache_config(), "double")
  expect_type(get_autosave_delay(), "double")
  expect_type(get_loop_protection_delay(), "double")
  expect_type(get_ui_update_delay(), "double")
  expect_type(get_test_mode_config(), "double")
})

test_that("Getter functions support future YAML configuration via documented pattern", {
  # This test verifies the accessor function interface supports future YAML extension
  # Without actual YAML loading, just verify the function structure is correct

  # Verify functions return appropriate types for constants
  expect_true(is.numeric(get_debounce_delay("input_change")))
  expect_true(is.numeric(get_operation_timeout("chart_render")))
  expect_true(is.numeric(get_performance_threshold("reactive_warning")))
  expect_true(is.numeric(get_cache_config("default_timeout_seconds")))
  expect_true(is.numeric(get_autosave_delay("data_save")))
  expect_true(is.numeric(get_loop_protection_delay("default")))
  expect_true(is.numeric(get_ui_update_delay("standard_update_delay")))

  # Functions that can return NULL or logical should support that too
  expect_true(is.logical(get_test_mode_config("lazy_plot_generation")) ||
              is.null(get_test_mode_config("nonexistent")))
})
