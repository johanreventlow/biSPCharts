# utils_performance.R
# Performance utilities: evaluate_data_content_cached og hjælpere
# Note: create_cached_reactive, create_performance_debounced og
# clear_performance_cache er fjernet — kanoniske versioner i
# utils_performance_caching.R (se issue #102)

#' Optimeret data content validator med caching og event-driven invalidation
#'
#' Performance-optimeret version af den gentagne purrr::map_lgl logik
#' fra utils_server_session_helpers.R. Bruger session-local cache og
#' event-driven invalidation for at reducere redundante evaluations.
#'
#' @param data Data frame der skal evalueres for meaningful content
#' @param cache_key Optional cache key (default: data hash)
#' @param session Shiny session object for session-local cache
#' @param invalidate_events Character vector med events der skal invalidere cache
#'
#' @return Logical - TRUE hvis data har meaningful content, FALSE ellers
#'
#' @examples
#' \dontrun{
#' # Basic usage med automatic caching
#' has_content <- evaluate_data_content_cached(my_data)
#'
#' # Med explicit session og cache control
#' has_content <- evaluate_data_content_cached(
#'   my_data,
#'   session = session,
#'   invalidate_events = c("data_loaded", "session_reset")
#' )
#' }
#'
#' @family performance
#' @keywords internal
evaluate_data_content_cached <- function(data, cache_key = NULL, session = NULL, invalidate_events = c("data_loaded", "session_reset")) {
  # Null data check først
  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) {
    return(FALSE)
  }

  # Generate cache key hvis ikke angivet
  if (is.null(cache_key)) {
    # FIX BUG #2: Hash ENTIRE dataset instead of just first row
    # This prevents cache returning TRUE when rows 2+ are cleared
    cache_key <- safe_operation(
      "Generate data content cache key",
      code = {
        data_signature <- digest::digest(
          list(
            nrow = nrow(data),
            ncol = ncol(data),
            column_names = names(data),
            data_hash = digest::digest(data, algo = "xxhash64", serialize = TRUE)
          ),
          algo = "xxhash64",
          serialize = TRUE
        )
        paste0("data_content_", data_signature)
      },
      fallback = function(e) {
        paste0("data_content_fallback_", as.integer(Sys.time()))
      },
      error_type = "processing"
    )
  }

  # Få session-local cache
  cache_env <- get_session_cache(session)

  # Check cache først
  if (exists(cache_key, envir = cache_env)) {
    cached_result <- get(cache_key, envir = cache_env)
    # Valider cache er fresh (ikke for gammel)
    if (!is.null(cached_result$timestamp) &&
      (Sys.time() - cached_result$timestamp) < PERFORMANCE_THRESHOLDS$cache_timeout_default) {
      log_debug(paste("Cache hit for data content check:", cache_key), "PERFORMANCE")
      return(cached_result$result)
    }
  }

  # Cache miss - compute meaningful data check
  log_debug(paste("Cache miss - computing data content for:", cache_key), "PERFORMANCE")

  start_time <- Sys.time()

  # OPTIMERET VERSION: Single-pass analyse fremfor purrr::map_lgl
  meaningful_data <- safe_operation(
    "Evaluate data content (optimized)",
    code = {
      # Pre-allocate logical vector for efficiency
      col_results <- logical(ncol(data))

      # Single loop gennem columns instead of purrr::map_lgl
      for (i in seq_along(data)) {
        col <- data[[i]]
        if (is.logical(col)) {
          col_results[i] <- any(col, na.rm = TRUE)
        } else if (is.numeric(col)) {
          col_results[i] <- any(!is.na(col))
        } else if (is.character(col)) {
          # nzchar(NA, keepNA = FALSE) returnerer uventet TRUE — brug eksplicit NA-tjek
          col_results[i] <- any(!is.na(col) & nzchar(col))
        } else {
          col_results[i] <- FALSE
        }
      }

      # Return TRUE hvis any column har meaningful content
      any(col_results)
    },
    fallback = function(e) {
      log_warn(paste("Data content evaluation failed:", e$message), "PERFORMANCE")
      FALSE # Conservative fallback
    },
    error_type = "processing"
  )

  execution_time <- as.numeric(Sys.time() - start_time)

  # Performance logging
  if (execution_time > 0.05) { # 50ms threshold for data content check
    log_warn(
      paste(
        "Slow data content evaluation took", round(execution_time * 1000, 1), "ms for",
        nrow(data), "rows x", ncol(data), "cols"
      ),
      "PERFORMANCE"
    )
  }

  # Cache result med timestamp
  cached_entry <- list(
    result = meaningful_data,
    timestamp = Sys.time(),
    execution_time = execution_time
  )
  assign(cache_key, cached_entry, envir = cache_env)

  # Setup cache invalidation på events hvis session er available
  if (!is.null(session) && exists("app_state") && !is.null(app_state$events)) {
    setup_cache_invalidation(cache_key, invalidate_events, cache_env, session)
  }

  return(meaningful_data)
}

#' Setup cache invalidation for specified events
#'
#' Internal helper til at setup automatic cache invalidation
#' når specific events indtræffer i app_state$events.
#'
#' @param cache_key Character - cache key der skal invalideres
#' @param events Character vector - events der skal trigger invalidation
#' @param cache_env Environment - cache environment
#' @param session Shiny session object
#'
#' @return NULL (side effect only)
#' @keywords internal
setup_cache_invalidation <- function(cache_key, events, cache_env, session) {
  for (event_name in events) {
    if (exists(event_name, envir = app_state$events)) {
      # Oprette observer for cache invalidation
      obs_key <- paste0("cache_invalidation_", cache_key, "_", event_name)

      # Check om observer allerede eksisterer
      if (!exists(obs_key, envir = cache_env)) {
        observer <- shiny::observeEvent(
          app_state$events[[event_name]],
          ignoreInit = TRUE,
          {
            log_debug(paste("Invalidating cache for key:", cache_key, "due to event:", event_name), "PERFORMANCE")
            if (exists(cache_key, envir = cache_env)) {
              rm(list = cache_key, envir = cache_env)
            }
          }
        )

        # Gem observer reference for cleanup
        assign(obs_key, observer, envir = cache_env)

        # Setup cleanup når session ender
        session$onSessionEnded(function() {
          if (exists(obs_key, envir = cache_env)) {
            obs <- get(obs_key, envir = cache_env)
            if (inherits(obs, "Observer")) {
              obs$destroy()
            }
            rm(list = obs_key, envir = cache_env)
          }
        })
      }
    }
  }
}

#' Get eller opret session-local cache environment
#'
#' Internal helper til at få session-specific cache environment.
#' Fallback til global cache hvis session ikke er tilgængelig.
#'
#' @param session Shiny session object (optional)
#' @return Environment til cache storage
#' @keywords internal
get_session_cache <- function(session = NULL) {
  if (!is.null(session) && !is.null(session$userData)) {
    # Session-local cache
    if (is.null(session$userData$performance_cache)) {
      session$userData$performance_cache <- new.env(parent = emptyenv())
    }
    return(session$userData$performance_cache)
  } else {
    # Fallback: Brug module-level cache (undgår .GlobalEnv forurening)
    return(.performance_cache)
  }
}
