# utils_startup_cache.R
# Startup cache system for static artifacts to improve boot performance

#' Startup cache configuration
#' Configuration for caching static artifacts during startup to reduce
#' repeated computations and file reads on subsequent application starts.
#'
#' @details
#' Cached artifacts:
#' - Hospital branding configuration (colors, logos, text)
#' - Observer priorities configuration
#' - Chart types configuration
#' - System configuration snapshot
#' - SPC configuration defaults
#'
#' Cache location: Uses persistent user cache directory for optimal performance
#' Cache TTL: 1 hour (configurable)
#'
#' @details
#' Cache directory: tools::R_user_dir("biSPCharts", which = "cache")
#' This ensures cache persists across R sessions for maximum startup performance.
STARTUP_CACHE_CONFIG <- list(
  cache_dir = tools::R_user_dir("biSPCharts", which = "cache"),
  cache_ttl_seconds = 3600, # 1 hour
  max_cache_size_mb = 10, # Maximum cache size

  # Artifacts to cache
  artifacts = list(
    hospital_branding = list(
      file = "hospital_branding.rds",
      generator = function() get_hospital_branding_config(),
      ttl_seconds = 7200 # Branding changes rarely, cache longer
    ),
    observer_priorities = list(
      file = "observer_priorities.rds",
      generator = function() get_observer_priorities_config(),
      ttl_seconds = 3600
    ),
    chart_types = list(
      file = "chart_types.rds",
      generator = function() get_chart_types_config(),
      ttl_seconds = 3600
    ),
    system_config = list(
      file = "system_config.rds",
      generator = function() get_system_config_snapshot(),
      ttl_seconds = 1800 # Config changes more frequently
    )
  )
)

#' Initialize startup cache directory
#'
#' @return TRUE if cache dir exists or was created, FALSE otherwise
#' @keywords internal
init_startup_cache <- function() {
  cache_dir <- STARTUP_CACHE_CONFIG$cache_dir
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  log_info("Startup cache initialized at:", cache_dir, .context = "STARTUP_CACHE")
  dir.exists(cache_dir)
}

#' Cache startup data
#' Cache all configured static artifacts for faster subsequent startups
#'
#' @return List of successfully cached artifacts
#' @keywords internal
cache_startup_data <- function() {
  if (!init_startup_cache()) {
    log_warn("Cannot cache startup data - cache initialization failed", .context = "STARTUP_CACHE")
    return(character(0))
  }

  cached_artifacts <- character(0)
  cache_dir <- STARTUP_CACHE_CONFIG$cache_dir

  log_info("Starting startup data caching", .context = "STARTUP_CACHE")

  for (artifact_name in names(STARTUP_CACHE_CONFIG$artifacts)) {
    artifact_config <- STARTUP_CACHE_CONFIG$artifacts[[artifact_name]]
    cache_file <- file.path(cache_dir, artifact_config$file)

    should_cache <- TRUE

    # Check if cache file exists and is still valid
    if (file.exists(cache_file)) {
      file_info <- file.info(cache_file)
      file_age_seconds <- as.numeric(Sys.time() - file_info$mtime)
      ttl <- artifact_config$ttl_seconds %||% STARTUP_CACHE_CONFIG$cache_ttl_seconds

      if (file_age_seconds < ttl) {
        should_cache <- FALSE
        log_debug(paste("Cache file still valid:", artifact_name), "STARTUP_CACHE")
      }
    }

    if (should_cache) {
      cached <- safe_operation(
        operation_name = paste("Cache artifact:", artifact_name),
        code = {
          # Fix: Check if generator is a function directly instead of deparse/substitute
          if (is.function(artifact_config$generator)) {
            data <- artifact_config$generator()
            saveRDS(data, cache_file)
            log_debug(paste("Cached artifact:", artifact_name, "to", basename(cache_file)), "STARTUP_CACHE")
            return(TRUE)
          } else {
            log_debug(paste("Generator function not available for:", artifact_name), "STARTUP_CACHE")
            return(FALSE)
          }
        },
        fallback = function(e) {
          log_warn(paste("Failed to cache", artifact_name, ":", e$message), "STARTUP_CACHE")
          return(FALSE)
        }
      )

      if (cached) {
        cached_artifacts <- c(cached_artifacts, artifact_name)
      }
    }
  }

  if (length(cached_artifacts) > 0) {
    log_info(paste("Cached artifacts:", paste(cached_artifacts, collapse = ", ")), "STARTUP_CACHE")
  } else {
    log_info("No new artifacts cached (all up-to-date)", "STARTUP_CACHE")
  }

  return(cached_artifacts)
}

#' Load cached startup data
#' Load cached static artifacts to speed up startup
#'
#' @return List of successfully loaded artifacts with their data
#' @keywords internal
load_cached_startup_data <- function() {
  cache_dir <- STARTUP_CACHE_CONFIG$cache_dir

  if (!dir.exists(cache_dir)) {
    log_debug("No startup cache directory found", .context = "STARTUP_CACHE")
    return(list())
  }

  loaded_data <- list()

  for (artifact_name in names(STARTUP_CACHE_CONFIG$artifacts)) {
    artifact_config <- STARTUP_CACHE_CONFIG$artifacts[[artifact_name]]
    cache_file <- file.path(cache_dir, artifact_config$file)

    if (file.exists(cache_file)) {
      # Check if cache is still valid
      file_info <- file.info(cache_file)
      file_age_seconds <- as.numeric(Sys.time() - file_info$mtime)
      ttl <- artifact_config$ttl_seconds %||% STARTUP_CACHE_CONFIG$cache_ttl_seconds

      if (file_age_seconds < ttl) {
        data <- safe_operation(
          operation_name = paste("Load cached artifact:", artifact_name),
          code = {
            cached_data <- readRDS(cache_file)
            log_debug(paste("Loaded cached artifact:", artifact_name), "STARTUP_CACHE")
            return(cached_data)
          },
          fallback = function(e) {
            log_warn(paste("Failed to load cached", artifact_name, ":", e$message), "STARTUP_CACHE")
            return(NULL)
          }
        )

        if (!is.null(data)) {
          loaded_data[[artifact_name]] <- data
        }
      } else {
        log_debug(paste("Cache expired for:", artifact_name), "STARTUP_CACHE")
        # Remove expired cache file
        unlink(cache_file)
      }
    }
  }

  if (length(loaded_data) > 0) {
    log_info(paste("Loaded cached artifacts:", paste(names(loaded_data), collapse = ", ")), "STARTUP_CACHE")
  }

  return(loaded_data)
}
