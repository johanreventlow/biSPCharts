# utils_cache_generators.R
# Generator functions for startup cache artifacts

#' Get hospital branding configuration for caching
#'
#' Extract all hospital branding data that can be cached for faster startup
#'
#' @return List with hospital branding configuration
#' @keywords internal
get_hospital_branding_config <- function() {
  safe_operation(
    operation_name = "Generate hospital branding cache",
    code = {
      branding_config <- list()

      # Hospital colors — kald getter hvis tilgængelig; ellers BFH-brand defaults.
      # Defaults matcher BFHtheme::bfh_cols() farvepalette og er korrekte for
      # biSPCharts-brug; de erstatter IKKE branding-getter under normal drift.
      if (exists("get_hospital_colors", mode = "function")) {
        branding_config$colors <- get_hospital_colors()
      } else {
        branding_config$colors <- list(
          primary = "#007dbb",
          secondary = "#646c6f",
          success = "#4f8325",
          warning = "#f9b928",
          danger = "#dc202b",
          accent = "#FF6B35"
        )
      }

      # Hospital name and metadata
      if (exists("get_hospital_name", mode = "function")) {
        branding_config$name <- get_hospital_name()
      } else {
        branding_config$name <- "biSPCharts SPC"
      }

      # Cache timestamp
      branding_config$generated_at <- Sys.time()
      branding_config$version <- "1.0.0"

      log_debug("Generated hospital branding cache data", .context = "CACHE_GENERATOR")
      return(branding_config)
    },
    fallback = function(e) {
      # Error-fallback: minimale BFH-brand defaults så UI ikke crasher.
      log_warn(paste("Failed to generate hospital branding cache:", e$message), "CACHE_GENERATOR")
      return(list(
        colors = list(primary = "#007dbb", secondary = "#646c6f"),
        name = "biSPCharts SPC",
        generated_at = Sys.time(),
        version = "1.0.0"
      ))
    }
  )
}

#' Get observer priorities configuration for caching
#'
#' Extract observer priorities that can be cached
#'
#' @return List with observer priorities
#' @keywords internal
get_observer_priorities_config <- function() {
  safe_operation(
    operation_name = "Generate observer priorities cache",
    code = {
      priorities <- list()

      # Get observer priorities if they exist (#492 3.1).
      # I package-mode lever OBSERVER_PRIORITIES i biSPCharts-namespace,
      # ikke .GlobalEnv. Tidligere lookup ville altid falde til hardcoded
      # default med forkerte numeriske niveauer (HIGH=900L vs faktisk 2000
      # i config_observer_priorities.R).
      # Package-namespace-lookup fejler kun udenfor pakke-kontekst (fx ren
      # source('global.R')); fald tilbage til .GlobalEnv-sti uden noise.
      pkg_ns <- tryCatch(
        asNamespace("biSPCharts"),
        error = function(e) {
          log_debug(
            paste("asNamespace('biSPCharts') ej tilgaengelig:", conditionMessage(e)),
            .context = "CACHE_GENERATOR"
          )
          NULL
        }
      )
      if (!is.null(pkg_ns) &&
        exists("OBSERVER_PRIORITIES", envir = pkg_ns, inherits = FALSE)) {
        priorities <- get("OBSERVER_PRIORITIES", envir = pkg_ns, inherits = FALSE)
      } else if (exists("OBSERVER_PRIORITIES", envir = .GlobalEnv)) {
        # Dev-mode fallback (source('global.R') uden devtools::load_all)
        priorities <- get("OBSERVER_PRIORITIES", envir = .GlobalEnv)
      } else {
        # Default priorities (sidste fallback hvis package ej loadet endnu)
        priorities <- list(
          STATE_MANAGEMENT = 1000L,
          HIGH = 900L,
          DATA_PROCESSING = 800L,
          UI_UPDATES = 700L,
          MEDIUM = 500L,
          LOW = 300L,
          CLEANUP = 100L
        )
      }

      priorities$generated_at <- Sys.time()
      priorities$version <- "1.0.0"

      log_debug("Generated observer priorities cache data", .context = "CACHE_GENERATOR")
      return(priorities)
    },
    fallback = function(e) {
      log_warn(paste("Failed to generate observer priorities cache:", e$message), "CACHE_GENERATOR")
      return(list(
        HIGH = 900L,
        MEDIUM = 500L,
        LOW = 300L,
        generated_at = Sys.time(),
        version = "1.0.0"
      ))
    }
  )
}

#' Get chart types configuration for caching
#'
#' Extract chart types configuration that can be cached
#'
#' @return List with chart types configuration
#' @keywords internal
get_chart_types_config <- function() {
  safe_operation(
    operation_name = "Generate chart types cache",
    code = {
      chart_types <- list()

      # Standard SPC chart types
      chart_types$spc_types <- list(
        "I chart" = list(
          description = "Individual measurements chart",
          requires = c("y_column"),
          optional = c("x_column")
        ),
        "MR chart" = list(
          description = "Moving range chart",
          requires = c("y_column"),
          optional = c("x_column")
        ),
        "Xbar chart" = list(
          description = "Average chart",
          requires = c("y_column", "n_column"),
          optional = c("x_column")
        ),
        "S chart" = list(
          description = "Standard deviation chart",
          requires = c("y_column", "n_column"),
          optional = c("x_column")
        ),
        "P chart" = list(
          description = "Proportion chart",
          requires = c("y_column", "n_column"),
          optional = c("x_column")
        ),
        "C chart" = list(
          description = "Count chart",
          requires = c("y_column"),
          optional = c("x_column")
        ),
        "U chart" = list(
          description = "Rate chart",
          requires = c("y_column", "n_column"),
          optional = c("x_column")
        )
      )

      chart_types$generated_at <- Sys.time()
      chart_types$version <- "1.0.0"

      log_debug("Generated chart types cache data", .context = "CACHE_GENERATOR")
      return(chart_types)
    },
    fallback = function(e) {
      log_warn(paste("Failed to generate chart types cache:", e$message), "CACHE_GENERATOR")
      return(list(
        spc_types = list("I chart" = list(description = "Individual measurements chart")),
        generated_at = Sys.time(),
        version = "1.0.0"
      ))
    }
  )
}

#' Get system configuration snapshot for caching
#' Create a snapshot of system configuration that can be cached
#'
#' @return List with system configuration
#' @keywords internal
get_system_config_snapshot <- function() {
  safe_operation(
    operation_name = "Generate system config cache",
    code = {
      config <- list()

      # Environment detection
      config$environment <- detect_golem_environment()

      # Log level (#458: typed env access via safe_getenv)
      config$log_level <- safe_getenv("SPC_LOG_LEVEL", "INFO", "character")

      # Key environment variables
      config$env_vars <- list(
        golem_config_active = safe_getenv("GOLEM_CONFIG_ACTIVE", "", "character"),
        test_mode_auto_load = safe_getenv("TEST_MODE_AUTO_LOAD", "FALSE", "character"),
        spc_debug_mode = safe_getenv("SPC_DEBUG_MODE", "FALSE", "character"),
        spc_source_loading = safe_getenv("SPC_SOURCE_LOADING", "FALSE", "character")
      )

      # Runtime flags
      config$runtime_flags <- list(
        interactive_session = interactive(),
        # Bevidst raw Sys.getenv() — vi tjekker ENV-key existence, ikke value
        package_mode = !"SPC_SOURCE_LOADING" %in% names(Sys.getenv()) ||
          safe_getenv("SPC_SOURCE_LOADING", "FALSE", "character") == "FALSE"
      )

      config$generated_at <- Sys.time()
      config$version <- "1.0.0"

      log_debug("Generated system config cache data", .context = "CACHE_GENERATOR")
      return(config)
    },
    fallback = function(e) {
      log_warn(paste("Failed to generate system config cache:", e$message), "CACHE_GENERATOR")
      return(list(
        environment = "production",
        log_level = "INFO",
        generated_at = Sys.time(),
        version = "1.0.0"
      ))
    }
  )
}
