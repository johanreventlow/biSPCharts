# app_initialization.R
# Modular Application Initialization System
# Fase 3.2: Complete orchestration of app startup

#' Initialize Complete Shiny Application
#'
#' Package-based initialization function that replaces file sourcing with
#' package namespace access. All functions are assumed to be loaded via
#' package loading (library(biSPCharts)).
#'
#' @param force_reload Boolean indicating if forced reload is needed (legacy parameter)
#' @param config_override Optional configuration override
#' @return List containing initialization results
#' @keywords internal
initialize_app <- function(force_reload = FALSE, config_override = NULL) {
  log_debug("Starting package-based app initialization", .context = "APP_INIT")

  init_results <- list()

  # 1. Verify package functions are available
  init_results$package_verification <- verify_package_functions()

  # 2. Initialize configuration system
  init_results$config <- if (!is.null(config_override)) {
    config_override
  } else {
    if (exists("initialize_runtime_config", mode = "function")) {
      initialize_runtime_config()
    } else {
      # Fallback basic config
      list(
        logging = list(debug_mode_enabled = FALSE),
        testing = list(auto_load_enabled = FALSE),
        development = list(
          auto_restore_enabled = FALSE,
          auto_save_enabled = TRUE,
          save_interval_ms = 2000,
          settings_save_interval_ms = 1000
        ),
        performance = list()
      )
    }
  }

  # 3. Setup branding (now handled by package .onLoad)
  init_results$branding <- verify_branding_setup()

  # 4. Setup performance optimizations
  init_results$performance <- setup_performance_optimizations(init_results$config)

  # 5. Verify initialization completeness
  init_results$verification <- verify_initialization_completeness()

  log_debug("Package-based app initialization completed", .context = "APP_INIT")
  return(init_results)
}

#' Verify Package Functions Are Available
#'
#' Verify that essential package functions are loaded and available.
#' Replaces the old foundation utilities loading with package verification.
#'
#' @return List with verification results
verify_package_functions <- function() {
  # Essential functions that should be available via package loading
  essential_functions <- c(
    "create_app_state", # State management
    "create_emit_api", # Event system
    "get_hospital_name", # Branding (internal)
    "get_bootstrap_theme", # Branding (internal)
    "app_ui", # UI function
    "app_server" # Server function
  )

  results <- list(
    available_functions = c(),
    missing_functions = c(),
    verification_time = NULL
  )

  results$verification_time <- system.time({
    for (func_name in essential_functions) {
      if (exists(func_name, mode = "function")) {
        results$available_functions <- c(results$available_functions, func_name)
      } else {
        results$missing_functions <- c(results$missing_functions, func_name)
      }
    }
  })[["elapsed"]]

  log_debug(paste(
    "Package functions verified:",
    length(results$available_functions), "available,",
    length(results$missing_functions), "missing"
  ), .context = "PACKAGE_VERIFICATION")

  return(results)
}

#' Verify Branding Setup
#'
#' Verify that branding configuration is properly loaded and available.
#' Replaces the old core loading with branding verification.
#'
#' @return List with branding verification results
verify_branding_setup <- function() {
  results <- list(
    hospital_name_available = FALSE,
    theme_available = FALSE,
    logo_path_available = FALSE,
    colors_available = FALSE
  )

  log_app_init_error <- function(e) {
    log_debug(conditionMessage(e), .context = "APP_INIT")
    NULL
  }

  # Brug getter funktioner i stedet for at checke globale variabler
  tryCatch(
    {
      hospital_name <- get_hospital_name()
      if (!is.null(hospital_name) && nchar(hospital_name) > 0) {
        results$hospital_name_available <- TRUE
        results$hospital_name <- hospital_name
      }
    },
    error = log_app_init_error
  )

  tryCatch(
    {
      theme <- get_bootstrap_theme()
      if (!is.null(theme)) {
        results$theme_available <- TRUE
        results$theme_class <- class(theme)
      }
    },
    error = log_app_init_error
  )

  tryCatch(
    {
      logo_path <- get_hospital_logo_path()
      if (!is.null(logo_path) && nchar(logo_path) > 0) {
        results$logo_path_available <- TRUE
        results$logo_path <- logo_path
      }
    },
    error = log_app_init_error
  )

  tryCatch(
    {
      colors <- get_hospital_colors()
      if (!is.null(colors) && length(colors) > 0) {
        results$colors_available <- TRUE
        results$color_count <- length(colors)
      }
    },
    error = log_app_init_error
  )

  results$complete <- all(
    results$hospital_name_available,
    results$theme_available,
    results$logo_path_available
  )

  if (results$complete) {
    log_debug("Branding verification PASSED", .context = "BRANDING_VERIFICATION")
  } else {
    log_debug("⚠ Branding verification PARTIAL - some elements missing", .context = "BRANDING_VERIFICATION")
  }

  return(results)
}

# PACKAGE-BASED HELPER FUNCTIONS ================================

#' Setup Performance Optimizations
#'
#' Configure performance-related settings based on app configuration.
#' Simplified for package-based loading.
#'
#' @param config App configuration
#' @return List with optimization results
#' @keywords internal
setup_performance_optimizations <- function(config) {
  optimizations <- list()

  # Setup configuration variables in package environment (not .GlobalEnv)
  claudespc_env <- get_claudespc_environment()

  if (!is.null(config$testing)) {
    claudespc_env$TEST_MODE_AUTO_LOAD <- config$testing$auto_load_enabled %||% FALSE

    # Phase 3: Test mode optimization settings
    claudespc_env$TEST_MODE_STARTUP_DEBOUNCE_MS <- config$testing$startup_debounce_ms %||% 500
    claudespc_env$TEST_MODE_LAZY_PLOT_GENERATION <- config$testing$lazy_plot_generation %||% TRUE
    claudespc_env$TEST_MODE_AUTO_DETECTION_DELAY_MS <- config$testing$auto_detection_delay_ms %||% 250
    claudespc_env$TEST_MODE_RACE_CONDITION_PREVENTION <- config$testing$race_condition_prevention %||% TRUE

    optimizations$testing_config_set <- TRUE
    optimizations$test_mode_optimization_set <- TRUE
  }

  if (!is.null(config$development)) {
    claudespc_env$AUTO_RESTORE_ENABLED <- config$development$auto_restore_enabled %||% FALSE
    claudespc_env$AUTO_SAVE_ENABLED <- config$development$auto_save_enabled %||% TRUE
    claudespc_env$SAVE_INTERVAL_MS <- config$development$save_interval_ms %||% 2000
    claudespc_env$SETTINGS_SAVE_INTERVAL_MS <- config$development$settings_save_interval_ms %||% 1000
    optimizations$development_config_set <- TRUE
  }

  log_debug("Performance optimizations configured", .context = "PERFORMANCE_SETUP")
  return(optimizations)
}

#' Verify Initialization Completeness
#'
#' Post-initialization verification that all critical components are loaded.
#' Simplified for package-based approach.
#'
#' @return List with verification results
verify_initialization_completeness <- function() {
  verification <- list()

  # Check critical functions are available via package loading
  critical_functions <- c(
    "app_ui", "app_server", "run_app", # Main app functions (from package)
    "create_app_state", # State management (from package)
    "autodetect_engine" # Autodetect functionality (from package)
  )

  verification$missing_functions <- c()
  for (func_name in critical_functions) {
    if (!exists(func_name, mode = "function")) {
      verification$missing_functions <- c(verification$missing_functions, func_name)
    }
  }

  # Check critical global variables (for backward compatibility)
  critical_globals <- c(
    "HOSPITAL_NAME", "my_theme" # Branding (set by .onLoad)
  )

  verification$missing_globals <- c()
  for (var_name in critical_globals) {
    if (!exists(var_name)) {
      verification$missing_globals <- c(verification$missing_globals, var_name)
    }
  }

  # Summary
  verification$complete <- (
    length(verification$missing_functions) == 0 &&
      length(verification$missing_globals) == 0
  )

  if (verification$complete) {
    log_debug("Initialization verification PASSED", .context = "VERIFICATION")
  } else {
    log_debug(paste(
      "Initialization verification FAILED:",
      length(verification$missing_functions), "missing functions,",
      length(verification$missing_globals), "missing globals"
    ), .context = "VERIFICATION")
  }

  return(verification)
}

#' Get Initialization Status Report
#'
#' Generate comprehensive report of initialization status.
#' Simplified for package-based approach.
#'
#' @param init_results Results from initialize_app()
#' @return Data frame with initialization status
#' @keywords internal
get_initialization_status_report <- function(init_results) {
  if (is.null(init_results)) {
    return(data.frame(
      component = "initialization",
      status = "not_started",
      details = "initialize_app() has not been called",
      stringsAsFactors = FALSE
    ))
  }

  # Extract status from each component
  components <- names(init_results)
  status_rows <- list()

  for (component in components) {
    component_data <- init_results[[component]]

    if (is.list(component_data)) {
      if ("complete" %in% names(component_data)) {
        status <- if (component_data$complete) "success" else "partial_failure"
        details <- if (component_data$complete) {
          "All components verified"
        } else {
          paste(
            "Issues:", length(component_data$missing_functions %||% c()), "missing functions,",
            length(component_data$missing_globals %||% c()), "missing globals"
          )
        }
      } else {
        status <- "success"
        details <- "Component loaded successfully"
      }
    } else {
      status <- "success"
      details <- "Component loaded successfully"
    }

    status_rows[[component]] <- data.frame(
      component = component,
      status = status,
      details = details,
      stringsAsFactors = FALSE
    )
  }

  return(do.call(rbind, status_rows))
}
