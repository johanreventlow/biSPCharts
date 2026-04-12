# ==============================================================================
# CONFIG_PERFORMANCE_GETTERS.R
# ==============================================================================
# FORMÅL: Accessor functions for performance-related constants.
#
# Provides getter functions for all performance tuning parameters, allowing
# future runtime configuration via YAML or environment variables without
# modifying calling code.
#
# PRECEDENCE: Future YAML → Environment Variable → Constant Default
#
# BRUGT AF: Everywhere DEBOUNCE_DELAYS, OPERATION_TIMEOUTS, etc. are used
# ==============================================================================

#' Get debounce delay for specified operation
#'
#' Returns the debounce delay (in milliseconds) for a given operation type.
#' Currently reads from `DEBOUNCE_DELAYS` constant; future versions can support
#' YAML configuration or environment variable overrides without code changes.
#'
#' **Supported operations:**
#' - `"input_change"`: Rapid user input (dropdown, typing) — default 150ms
#' - `"file_select"`: File selection and complex inputs — default 500ms
#' - `"chart_update"`: Chart rendering — default 500ms
#' - `"table_cleanup"`: Table operation cleanup — default 2000ms
#'
#' @param operation Character string naming the operation type
#'
#' @return Numeric value in milliseconds, or default 500ms if operation not found
#'
#' @examples
#' \dontrun{
#' delay <- get_debounce_delay("input_change")
#' # Returns: 150
#'
#' # In Shiny reactive
#' user_input <- shiny::debounce(
#'   reactive(input$dropdown),
#'   millis = get_debounce_delay("input_change")
#' )
#' }
#'
#' @keywords internal
get_debounce_delay <- function(operation = "input_change") {
  DEBOUNCE_DELAYS[[operation]] %||% 500
}

#' Get operation timeout for specified operation
#'
#' Returns the timeout (in milliseconds) for a given operation type.
#' Currently reads from `OPERATION_TIMEOUTS` constant; future versions can support
#' YAML configuration without code changes.
#'
#' **Supported operations:**
#' - `"file_read"`: File reading timeout — default 30000ms (30s)
#' - `"chart_render"`: Chart rendering timeout — default 10000ms (10s)
#' - `"auto_detect"`: Auto-detection timeout — default 5000ms (5s)
#' - `"ui_update"`: UI update timeout — default 2000ms (2s)
#'
#' @param operation Character string naming the operation type
#'
#' @return Numeric value in milliseconds, or default 10000ms if operation not found
#'
#' @examples
#' \dontrun{
#' timeout <- get_operation_timeout("chart_render")
#' # Returns: 10000
#' }
#'
#' @keywords internal
get_operation_timeout <- function(operation = "chart_render") {
  OPERATION_TIMEOUTS[[operation]] %||% 10000
}

#' Get performance threshold for specified metric
#'
#' Returns the performance monitoring threshold for a given metric.
#' Currently reads from `PERFORMANCE_THRESHOLDS` constant; future versions can
#' support YAML configuration for dynamic thresholds.
#'
#' **Supported metrics:**
#' - `"reactive_warning"`: Reactive expression time threshold — default 0.5s
#' - `"debounce_warning"`: Debounced operation time threshold — default 1.0s
#' - `"memory_warning"`: Memory change warning threshold — default 10MB
#' - `"cache_timeout_default"`: Default cache lifetime — default 300s (5 min)
#' - `"max_cache_entries"`: Maximum cached entries — default 50
#'
#' @param metric Character string naming the performance metric
#'
#' @return Numeric threshold value, or NULL if metric not found
#'
#' @examples
#' \dontrun{
#' threshold <- get_performance_threshold("reactive_warning")
#' # Returns: 0.5
#'
#' if (elapsed_time > get_performance_threshold("reactive_warning")) {
#'   log_warn("Reactive expression took too long")
#' }
#' }
#'
#' @keywords internal
get_performance_threshold <- function(metric = "reactive_warning") {
  PERFORMANCE_THRESHOLDS[[metric]] %||% NULL
}

#' Get cache configuration for specified setting
#'
#' Returns cache configuration values (timeouts, size limits, cleanup intervals).
#' Currently reads from `CACHE_CONFIG` constant; future versions can support
#' dynamic configuration per cache context.
#'
#' **Supported settings:**
#' - `"default_timeout_seconds"`: Standard cache lifetime — default 300s (5 min)
#' - `"extended_timeout_seconds"`: For expensive operations — default 600s (10 min)
#' - `"short_timeout_seconds"`: For frequently changing data — default 60s
#' - `"size_limit_entries"`: Maximum cached entries — default 50
#' - `"cleanup_interval_seconds"`: Cache cleanup frequency — default 300s (5 min)
#'
#' @param setting Character string naming the cache setting
#'
#' @return Numeric configuration value, or NULL if setting not found
#'
#' @examples
#' \dontrun{
#' ttl <- get_cache_config("default_timeout_seconds")
#' # Returns: 300
#'
#' cache$set(key = "result", value = data, timeout = get_cache_config("default_timeout_seconds"))
#' }
#'
#' @keywords internal
get_cache_config <- function(setting = "default_timeout_seconds") {
  CACHE_CONFIG[[setting]] %||% NULL
}

#' Get auto-save debounce delay for specified context
#'
#' Returns the debounce delay for auto-save operations.
#' Currently reads from `AUTOSAVE_DELAYS` constant; future versions can support
#' YAML configuration for per-environment tuning.
#'
#' **Supported contexts:**
#' - `"data_save"`: Data auto-save delay — default 2000ms (2s)
#' - `"settings_save"`: Settings auto-save delay — default 1000ms (1s)
#'
#' @param context Character string naming the auto-save context
#'
#' @return Numeric value in milliseconds, or default 2000ms if context not found
#'
#' @examples
#' \dontrun{
#' # Auto-save data with configured debounce
#' data_autosave <- shiny::debounce(
#'   reactive(app_state$data$current_data),
#'   millis = get_autosave_delay("data_save")
#' )
#' }
#'
#' @keywords internal
get_autosave_delay <- function(context = "data_save") {
  AUTOSAVE_DELAYS[[context]] %||% 2000
}

#' Get loop protection delay for specified scenario
#'
#' Returns the delay used to prevent reactive loops during UI updates.
#' Allows future configuration without code changes.
#'
#' **Supported scenarios:**
#' - `"default"`: Standard delay for programmatic updates — default 500ms
#' - `"conservative"`: Conservative delay for slower browsers — default 800ms
#' - `"minimal"`: Minimal delay for fast responses — default 200ms
#' - `"onFlushed_fallback"`: Fallback when session$onFlushed unavailable — default 1000ms
#'
#' @param scenario Character string naming the scenario
#'
#' @return Numeric value in milliseconds, or default 500ms if scenario not found
#'
#' @examples
#' \dontrun{
#' delay <- get_loop_protection_delay("default")
#' }
#'
#' @keywords internal
get_loop_protection_delay <- function(scenario = "default") {
  LOOP_PROTECTION_DELAYS[[scenario]] %||% 500
}

#' Get UI update configuration for specified update type
#'
#' Returns UI update timing configuration to prevent race conditions and
#' ensure responsive updates. Supports future dynamic configuration.
#'
#' **Supported update types:**
#' - `"immediate_delay"`: No delay — default 0ms
#' - `"fast_update_delay"`: Fast responsive updates — default 50ms
#' - `"standard_update_delay"`: Standard update timing — default 100ms
#' - `"safe_programmatic_delay"`: Prevent update loops — default 150ms
#'
#' @param update_type Character string naming the update type
#'
#' @return Numeric value in milliseconds, or default 100ms if type not found
#'
#' @examples
#' \dontrun{
#' delay <- get_ui_update_delay("standard_update_delay")
#' }
#'
#' @keywords internal
get_ui_update_delay <- function(update_type = "standard_update_delay") {
  UI_UPDATE_CONFIG[[update_type]] %||% 100
}

#' Get test mode configuration for specified setting
#'
#' Returns test mode configuration values. Future versions may support
#' per-test environment customization.
#'
#' **Supported settings:**
#' - `"ready_event_delay_seconds"`: Delay before emitting ready event — default 1.5s
#' - `"startup_debounce_ms"`: Test data auto-load debounce — default 300ms
#' - `"auto_detect_delay_ms"`: Auto-detection trigger delay — default 250ms
#' - `"lazy_plot_generation"`: Whether to defer plot generation — default TRUE
#'
#' @param setting Character string naming the test mode setting
#'
#' @return Configuration value (numeric or logical), or NULL if setting not found
#'
#' @examples
#' \dontrun{
#' if (get_test_mode_config("lazy_plot_generation")) {
#'   # Defer plot generation until needed
#' }
#' }
#'
#' @keywords internal
get_test_mode_config <- function(setting = "ready_event_delay_seconds") {
  TEST_MODE_CONFIG[[setting]] %||% NULL
}
