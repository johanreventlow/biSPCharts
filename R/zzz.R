#' Package initialization and loading
#'
#' This file handles package initialization when biSPCharts is loaded.
#' It replaces the global.R source() chain with proper package loading.
#'
#' @param libname Library name (not used)
#' @param pkgname Package name (should be "biSPCharts")
#'
#' @importFrom utils packageVersion
#' @noRd

# Package-level environment for storing configuration and variables
# This prevents pollution of .GlobalEnv
.claudespc_env <- NULL

#' Get or create the biSPCharts package environment
#'
#' Returns the package-level environment used for storing configuration
#' and global variables. Creates it if it doesn't exist.
#'
#' @return Environment containing package-level variables
#' @noRd
get_claudespc_environment <- function() {
  if (is.null(.claudespc_env)) {
    .claudespc_env <<- new.env(parent = emptyenv())
  }
  return(.claudespc_env)
}

#' Get configuration value from package environment
#'
#' @param key Configuration key to retrieve
#' @param default Default value if key not found
#' @return Configuration value or default
#' @keywords internal
get_package_config <- function(key, default = NULL) {
  claudespc_env <- get_claudespc_environment()
  if (exists(key, envir = claudespc_env)) {
    return(get(key, envir = claudespc_env))
  } else {
    return(default)
  }
}

#' Get the complete runtime configuration
#'
#' @return Runtime configuration list or NULL
#' @keywords internal
get_runtime_config <- function() {
  get_package_config("runtime_config", default = NULL)
}

#' Get test mode auto load setting
#'
#' @return Boolean indicating if test mode auto load is enabled
#' @keywords internal
get_test_mode_auto_load <- function() {
  get_package_config("TEST_MODE_AUTO_LOAD", default = FALSE)
}

#' Get auto restore enabled setting
#'
#' @return Boolean indicating if auto restore is enabled
#' @keywords internal
get_auto_restore_enabled <- function() {
  get_package_config("AUTO_RESTORE_ENABLED", default = TRUE)
}

#' Get auto save enabled setting
#'
#' @return Boolean indicating if continuous auto-save is enabled
#' @keywords internal
get_auto_save_enabled <- function() {
  get_package_config("AUTO_SAVE_ENABLED", default = TRUE)
}

#' Get auto-save debounce interval for data changes (milliseconds)
#'
#' @return Integer milliseconds
#' @keywords internal
get_save_interval_ms <- function() {
  get_package_config("SAVE_INTERVAL_MS", default = 2000)
}

#' Get auto-save debounce interval for settings changes (milliseconds)
#'
#' @return Integer milliseconds
#' @keywords internal
get_settings_save_interval_ms <- function() {
  get_package_config("SETTINGS_SAVE_INTERVAL_MS", default = 1000)
}

#' Get hospital name from package environment
#'
#' @return Hospital name string
#' @keywords internal
get_package_hospital_name <- function() {
  get_package_config("HOSPITAL_NAME", default = "Unknown Hospital")
}

#' Get hospital theme from package environment
#'
#' @return Bootstrap theme object
#' @keywords internal
get_package_theme <- function() {
  get_package_config("my_theme", default = NULL)
}

#' Get test mode file path
#'
#' @return Test file path string
#' @keywords internal
get_test_mode_file_path <- function() {
  get_package_config("TEST_MODE_FILE_PATH", default = NULL)
}

#' Get QIC call counter value
#'
#' Returns current value of the QIC call counter for performance monitoring.
#'
#' @return Integer counter value
#' @keywords internal
get_qic_call_counter <- function() {
  claudespc_env <- get_claudespc_environment()
  if (exists("qic_call_counter", envir = claudespc_env)) {
    return(claudespc_env$qic_call_counter)
  } else {
    return(0L)
  }
}

#' Increment QIC call counter
#'
#' Increments the QIC call counter and returns new value.
#'
#' @return New counter value
#' @keywords internal
increment_qic_call_counter <- function() {
  claudespc_env <- get_claudespc_environment()
  if (!exists("qic_call_counter", envir = claudespc_env)) {
    claudespc_env$qic_call_counter <- 0L
  }
  claudespc_env$qic_call_counter <- claudespc_env$qic_call_counter + 1L
  return(claudespc_env$qic_call_counter)
}

#' Get actual QIC call counter value
#'
#' Returns current value of actual qicharts2::qic() calls for performance monitoring.
#'
#' @return Integer counter value
#' @keywords internal
get_actual_qic_call_counter <- function() {
  claudespc_env <- get_claudespc_environment()
  if (exists("actual_qic_call_counter", envir = claudespc_env)) {
    return(claudespc_env$actual_qic_call_counter)
  } else {
    return(0L)
  }
}

#' Increment actual QIC call counter
#'
#' Increments the actual qicharts2::qic() call counter and returns new value.
#'
#' @return New counter value
#' @keywords internal
increment_actual_qic_call_counter <- function() {
  claudespc_env <- get_claudespc_environment()
  if (!exists("actual_qic_call_counter", envir = claudespc_env)) {
    claudespc_env$actual_qic_call_counter <- 0L
  }
  claudespc_env$actual_qic_call_counter <- claudespc_env$actual_qic_call_counter + 1L
  return(claudespc_env$actual_qic_call_counter)
}

#' Reset QIC performance counters
#'
#' Resets both QIC call counters to zero.
#'
#' @keywords internal
reset_qic_performance_counters <- function() {
  claudespc_env <- get_claudespc_environment()
  claudespc_env$qic_call_counter <- 0L
  claudespc_env$actual_qic_call_counter <- 0L
  invisible()
}
.onLoad <- function(libname, pkgname) {
  # Initialize package-level configuration
  initialize_package_globals()

  # Set up logging
  initialize_logging_system()

  # Load runtime configuration using the full implementation
  setup_package_runtime_config()

  # NOTE: Startup performance optimizations (cache, lazy loading) moved to run_app()
  # to ensure they work consistently in both package and source loading modes

  # Set up resource paths for static files
  setup_resource_paths()

  # Registrer Mari font FOeR Roboto -- BFHtheme cacher foerste match,
  # og Mari har hoejeste prioritet i get_bfh_font()
  if (exists("register_mari_font", mode = "function")) {
    register_mari_font()
  }

  # Register embedded Roboto Medium font as fallback
  if (exists("register_roboto_font", mode = "function")) {
    register_roboto_font()
  }

  invisible()
}

.onAttach <- function(libname, pkgname) {
  bfhllm_status <- if (requireNamespace("BFHllm", quietly = TRUE)) "tilg\u00e6ngelig" else "ikke installeret"
  qic_status <- if (requireNamespace("qicharts2", quietly = TRUE)) "tilg\u00e6ngelig" else "ikke installeret"
  quarto_status <- if (nzchar(Sys.which("quarto"))) "tilg\u00e6ngelig" else "ikke fundet i PATH"

  # Analytics-status: kill-switch vinder, derefter config, derefter legacy env-var
  kill_switch_active <- toupper(Sys.getenv("BISPC_DISABLE_ANALYTICS", "")) %in%
    c("TRUE", "1", "YES", "ON")
  if (kill_switch_active) {
    analytics_enabled <- FALSE
    analytics_config_source <- "env:BISPC_DISABLE_ANALYTICS"
  } else {
    config_val <- tryCatch(
      golem::get_golem_options("analytics.shinylogs_enabled"),
      error = function(e) NULL
    )
    if (!is.null(config_val)) {
      analytics_enabled <- isTRUE(config_val)
      analytics_config_source <- "golem-config"
    } else {
      legacy_flag <- Sys.getenv("ENABLE_SHINYLOGS", "TRUE")
      analytics_enabled <- toupper(legacy_flag) %in% c("TRUE", "1", "YES", "ON")
      analytics_config_source <- "env:ENABLE_SHINYLOGS (legacy)"
    }
  }

  packageStartupMessage(
    "biSPCharts optional features: ",
    "BFHllm=", bfhllm_status, ", ",
    "qicharts2=", qic_status, ", ",
    "Quarto=", quarto_status, "\n",
    "Analytics: shinylogs=", if (analytics_enabled) "aktiv" else "inaktiv",
    " (kilde: ", analytics_config_source, ")"
  )
}

#' Initialize package-level global variables
#'
#' @noRd
initialize_package_globals <- function() {
  # Initialize branding configuration using safe getters
  initialize_branding()

  # Store branding in package environment instead of polluting .GlobalEnv
  claudespc_env <- get_claudespc_environment()
  claudespc_env$HOSPITAL_NAME <- get_hospital_name()
  claudespc_env$HOSPITAL_LOGO_PATH <- get_hospital_logo_path()
  claudespc_env$my_theme <- get_bootstrap_theme()
  claudespc_env$HOSPITAL_COLORS <- get_hospital_colors()
  claudespc_env$HOSPITAL_THEME <- get_hospital_ggplot_theme()

  # M1: Initialize QIC performance counters in package environment
  # (moved from .GlobalEnv for session isolation)
  claudespc_env$qic_call_counter <- 0L
  claudespc_env$actual_qic_call_counter <- 0L

  # NOTE: Global environment exposure removed as part of legacy cleanup
  # All consumers should now use package getters:
  # - get_package_hospital_name() instead of HOSPITAL_NAME
  # - get_package_theme() instead of my_theme
  # - get_package_config("HOSPITAL_LOGO_PATH") instead of HOSPITAL_LOGO_PATH
  # - get_package_config("HOSPITAL_COLORS") instead of HOSPITAL_COLORS
}

#' Initialize logging system
#'
#' @noRd
initialize_logging_system <- function() {
  # Set default log level if not set
  if (!nzchar(Sys.getenv("SPC_LOG_LEVEL", ""))) {
    Sys.setenv(SPC_LOG_LEVEL = "INFO")
  }

  # Initialize shinylogs announcement (moved from parse-time execution)
  if (exists("initialize_shinylogs_announcement", mode = "function")) {
    initialize_shinylogs_announcement()
  }

  # Logging functions (log_debug, log_info, etc.) handle their own
  # availability checks and fallbacks, so no additional setup needed
}


#' Setup package runtime configuration (called during .onLoad)
#'
#' @noRd
setup_package_runtime_config <- function() {
  # Call the full initialize_runtime_config() implementation
  # and store result in package environment instead of .GlobalEnv
  config <- initialize_runtime_config()

  if (!is.null(config)) {
    # Store config in package environment
    claudespc_env <- get_claudespc_environment()
    claudespc_env$runtime_config <- config

    # Set up performance-related globals in package environment too
    if (!is.null(config$testing)) {
      claudespc_env$TEST_MODE_AUTO_LOAD <- config$testing$auto_load_enabled %||% FALSE
    }
    if (!is.null(config$development)) {
      claudespc_env$AUTO_RESTORE_ENABLED <- config$development$auto_restore_enabled %||% FALSE
      claudespc_env$AUTO_SAVE_ENABLED <- config$development$auto_save_enabled %||% TRUE
      claudespc_env$SAVE_INTERVAL_MS <- config$development$save_interval_ms %||% 2000
      claudespc_env$SETTINGS_SAVE_INTERVAL_MS <- config$development$settings_save_interval_ms %||% 1000
    }
  }

  invisible()
}


#' Set up resource paths for static files
#'
#' @noRd
setup_resource_paths <- function() {
  # Resource paths will be set up in golem_add_external_resources()
  # when the app starts
  invisible()
}

#' Package unload cleanup
#'
#' @param libpath Library path (not used)
#' @noRd
.onUnload <- function(libpath) {
  # Clean up any package-level resources
  if (exists("claudespc_globals", envir = parent.env(environment()))) {
    rm("claudespc_globals", envir = parent.env(environment()))
  }

  # Global environment cleanup no longer needed since globals are not exposed

  invisible()
}
