# golem_utils.R
# Golem-inspired utility functions for robust Shiny app management
# Fase 3.4: Proper golem patterns implementation with YAML configuration support

#' Null-coalescing operator
#'
#' Returns the left-hand side if it's not NULL, otherwise returns the right-hand side
#'
#' @param lhs Left-hand side value
#' @param rhs Right-hand side value (fallback)
#' @return lhs if not NULL, otherwise rhs
#' @export
`%||%` <- function(lhs, rhs) {
  if (!is.null(lhs)) lhs else rhs
}

#' Get Application Option (Golem-style)
#'
#' Retrieve application options with fallback to defaults.
#'
#' @param option_name Name of the option to retrieve
#' @param default Default value if option is not set
#' @return Option value or default
#' @examples
#' \dontrun{
#' # Get with default
#' debug_level <- get_app_option("debug_level", "INFO")
#'
#' # Check if in test mode
#' is_test_mode <- get_app_option("test_mode", FALSE)
#' }
#' @keywords internal
get_app_option <- function(option_name, default = NULL) {
  option_key <- paste0("claudespc.", option_name)
  return(getOption(option_key, default))
}

#' Check if Application is in Development Mode
#'
#' Golem-style development mode detection combining explicit options
#' with environment detection.
#'
#' @return Boolean indicating development mode
#' @keywords internal
is_dev_mode <- function() {
  # Check explicit option first
  explicit_dev <- get_app_option("production_mode", NULL)
  if (!is.null(explicit_dev)) {
    return(!explicit_dev) # dev mode is opposite of production mode
  }

  # Fall back to environment detection
  if (exists("detect_development_environment", mode = "function")) {
    return(detect_development_environment())
  }

  # Ultimate fallback
  return(interactive())
}

#' Check if Application is in Production Mode
#'
#' Golem-style production mode detection.
#'
#' @return Boolean indicating production mode
#' @keywords internal
is_prod_mode <- function() {
  # Check explicit option first
  explicit_prod <- get_app_option("production_mode", NULL)
  if (!is.null(explicit_prod)) {
    return(explicit_prod)
  }

  # Fall back to environment detection
  if (exists("detect_production_environment", mode = "function")) {
    return(detect_production_environment())
  }

  # Ultimate fallback - if not interactive, assume production
  return(!interactive())
}

#' Application Resource Path Setup (Golem-style)
#'
#' Setup static resource paths following golem conventions.
#'
#' @param path Path to add as resource
#' @param prefix Prefix for the resource path
#' @return Invisibly returns TRUE if successful
add_resource_path <- function(path = "www", prefix = "www") {
  # Input validation
  if (is.null(prefix) || length(prefix) == 0 || prefix == "" || is.na(prefix)) {
    if (exists("log_warn")) {
      log_warn("Invalid prefix provided to add_resource_path", .context = "RESOURCE_PATHS")
    } else {
      warning("Invalid prefix provided to add_resource_path")
    }
    return(invisible(FALSE))
  }

  if (is.null(path) || length(path) == 0 || path == "" || is.na(path)) {
    if (exists("log_warn")) {
      log_warn("Invalid path provided to add_resource_path", .context = "RESOURCE_PATHS")
    } else {
      warning("Invalid path provided to add_resource_path")
    }
    return(invisible(FALSE))
  }

  # Use system.file() for packaged apps, fallback for development
  if (path == "www") {
    www_path <- system.file("app", "www", package = "biSPCharts")
    if (www_path == "") {
      # Development mode fallbacks
      possible_paths <- c(
        file.path("inst", "app", "www"),
        file.path("www"),
        file.path("app", "www")
      )

      www_path <- NULL
      for (possible_path in possible_paths) {
        if (dir.exists(possible_path)) {
          www_path <- possible_path
          break
        }
      }

      if (is.null(www_path)) {
        if (exists("log_debug")) {
          log_debug("No www directory found in development mode", .context = "RESOURCE_PATHS")
        }
        return(invisible(FALSE))
      }
    }
    path <- www_path
  }

  if (dir.exists(path)) {
    # Additional validation for shiny::addResourcePath requirements
    tryCatch(
      {
        shiny::addResourcePath(prefix, path)
        if (exists("log_debug")) {
          log_debug(paste("Added resource path:", prefix, "->", path), "RESOURCE_PATHS")
        }
        return(invisible(TRUE))
      },
      error = function(e) {
        if (exists("log_warn")) {
          log_warn(paste("Failed to add resource path:", e$message), "RESOURCE_PATHS")
        } else {
          warning(paste("Failed to add resource path:", e$message))
        }
        return(invisible(FALSE))
      }
    )
  } else {
    if (exists("log_debug")) {
      log_debug(paste("Resource path not found:", path), "RESOURCE_PATHS")
    }
    return(invisible(FALSE))
  }
}

#' Favicon Setup (Golem-style)
#'
#' Setup application favicon following golem patterns.
#'
#' @param path Path to favicon file
#' @return HTML tags for favicon
favicon <- function(path = "www/favicon.ico") {
  # For packaged apps, adjust favicon path
  if (path == "www/favicon.ico") {
    favicon_path <- system.file("app", "www", "favicon.ico", package = "biSPCharts")
    if (favicon_path == "") {
      favicon_path <- file.path("inst", "app", "www", "favicon.ico")
    }
    if (file.exists(favicon_path)) {
      path <- "www/favicon.ico" # Keep relative path for href
    }
  }

  if (file.exists(path) || grepl("^www/", path)) {
    return(shiny::tags$head(shiny::tags$link(rel = "icon", href = path)))
  } else {
    log_debug(paste("Favicon not found:", path), .context = "FAVICON")
    return(NULL)
  }
}

# CONFIGURATION SUPPORT ======================================================
# Note: Golem configuration is handled via config::get() in app_config.R
# This avoids duplicate YAML readers and ensures consistent config loading

#' Detect Golem Environment
#'
#' Detect current deployment environment following golem conventions.
#'
#' @return String indicating environment (development, production, testing, default)
detect_golem_environment <- function() {
  # Check GOLEM_CONFIG_ACTIVE first (primary environment variable)
  golem_config <- Sys.getenv("GOLEM_CONFIG_ACTIVE", "")
  if (golem_config != "") {
    mapped_env <- switch(golem_config,
      "development" = "development",
      "dev" = "development",
      "production" = "production",
      "prod" = "production",
      "testing" = "testing",
      "test" = "testing",
      "default" # Fallback
    )
    log_debug(paste("Environment detected from GOLEM_CONFIG_ACTIVE:", mapped_env), .context = "GOLEM_ENV")
    return(mapped_env)
  }

  # Map R_CONFIG_ACTIVE to GOLEM_CONFIG_ACTIVE for backward compatibility
  r_config <- Sys.getenv("R_CONFIG_ACTIVE", "")
  if (r_config != "") {
    mapped_env <- switch(r_config,
      "development" = "development",
      "dev" = "development",
      "production" = "production",
      "prod" = "production",
      "testing" = "testing",
      "test" = "testing",
      "default" # Fallback
    )
    # Set GOLEM_CONFIG_ACTIVE based on R_CONFIG_ACTIVE for consistency
    Sys.setenv(GOLEM_CONFIG_ACTIVE = mapped_env)
    log_debug(paste("Environment mapped from R_CONFIG_ACTIVE to GOLEM_CONFIG_ACTIVE:", mapped_env), .context = "GOLEM_ENV")
    return(mapped_env)
  }

  # Check application mode
  if (exists("is_prod_mode", mode = "function") && is_prod_mode()) {
    return("production")
  }

  if (exists("is_dev_mode", mode = "function") && is_dev_mode()) {
    return("development")
  }

  # Check for testing environment
  if (any(c("testthat", "test") %in% search())) {
    return("testing")
  }

  # Interactive session implies development
  if (interactive()) {
    return("development")
  }

  # Default fallback
  log_debug("No specific environment detected, using default", .context = "GOLEM_ENV")
  return("default")
}

# HELPER FUNCTIONS ============================================================

#' Null-coalescing operator
#'
# Null coalescing operator is defined in utils_logging.R
