# ==============================================================================
# UTILS_AI_CACHE.R
# ==============================================================================
# FORMÅL: Session-scoped in-memory caching for AI responses
#         - Reduce API calls and costs (target 70%+ cache hit rate)
#         - Ensure consistent responses for identical inputs
#         - Improve performance (cache lookup < 50ms vs API call ~5-10s)
#
# ARKITEKTUR:
#   - Cache storage: session$userData$ai_cache (reactiveVal containing list)
#   - Hash-based keys using digest::digest() with xxhash64 algorithm
#   - TTL enforcement on lookup (expired entries return NULL)
#   - Automatic cleanup on session end
#
# RELATERET:
#   - Task #74: Caching Layer - Hash-Based Response Cache
#   - inst/golem-config.yml: ai.cache_ttl_seconds configuration
#   - R/config_log_contexts.R: LOG_CONTEXTS for structured logging
#
# BRUG:
#   # Initialize cache (typically in app_server.R)
#   initialize_ai_cache(session)
#
#   # Generate cache key
#   key <- generate_ai_cache_key(metadata, context)
#
#   # Check for cached response
#   cached <- get_cached_ai_response(key, session)
#
#   # Cache a new response
#   cache_ai_response(key, response_text, session)
#
#   # Clear cache manually
#   clear_ai_cache(session)
#
#   # Get cache statistics
#   stats <- get_cache_stats(session)
# ==============================================================================

#' Get AI Configuration from Golem Config
#'
#' Helper function to retrieve AI-specific configuration from golem-config.yml.
#' Falls back to sensible defaults if configuration is missing.
#'
#' @return List with AI configuration parameters
#' \describe{
#'   \item{cache_ttl_seconds}{Time-to-live for cache entries (default: 3600)}
#'   \item{enabled}{Whether AI features are enabled (default: TRUE)}
#'   \item{provider}{AI provider name (default: "gemini")}
#'   \item{model}{AI model identifier}
#'   \item{timeout_seconds}{API timeout in seconds}
#'   \item{max_response_chars}{Maximum response character length}
#' }
#'
#' @keywords internal
get_ai_config <- function() {
  tryCatch(
    {
      # Try to get AI config from golem options
      ai_config <- golem::get_golem_options("ai")

      # If ai_config is NULL, build from individual options
      if (is.null(ai_config)) {
        ai_config <- list(
          enabled = golem::get_golem_options("ai.enabled") %||% TRUE,
          provider = golem::get_golem_options("ai.provider") %||% "gemini",
          model = golem::get_golem_options("ai.model") %||% "gemini-2.0-flash-exp",
          timeout_seconds = golem::get_golem_options("ai.timeout_seconds") %||% 10,
          max_response_chars = golem::get_golem_options("ai.max_response_chars") %||% 350,
          cache_ttl_seconds = golem::get_golem_options("ai.cache_ttl_seconds") %||% 3600
        )
      }

      # Ensure cache_ttl_seconds is present with default
      if (is.null(ai_config$cache_ttl_seconds)) {
        ai_config$cache_ttl_seconds <- 3600
      }

      return(ai_config)
    },
    error = function(e) {
      # Fallback to safe defaults if golem config fails
      if (exists("log_warn", mode = "function")) {
        log_warn(
          message = "Failed to retrieve AI config from golem, using defaults",
          component = "[AI_CACHE]",
          details = list(error = conditionMessage(e))
        )
      }

      return(list(
        enabled = TRUE,
        provider = "gemini",
        model = "gemini-2.0-flash-exp",
        timeout_seconds = 10,
        max_response_chars = 350,
        cache_ttl_seconds = 3600
      ))
    }
  )
}

#' Generate Cache Key for AI Response
#'
#' Creates deterministic hash from metadata and context to ensure
#' same inputs always produce same cache key.
#'
#' Only includes stable fields in the hash to avoid cache misses from
#' irrelevant changes (timestamps, plot objects, reactive values).
#'
#' @param metadata List from extract_spc_metadata() containing SPC statistics
#' @param context List with user context (data_definition, chart_title, etc.)
#'
#' @return Character string (hex hash using xxhash64 algorithm)
#'
#' @details
#' **Stable metadata fields included in hash:**
#' - chart_type: Type of SPC chart
#' - n_points: Number of data points
#' - signals_detected: Number of signals detected
#' - longest_run: Longest run above/below centerline
#' - n_crossings: Number of centerline crossings
#' - centerline: Centerline value
#' - process_variation: Process variation metric
#'
#' **Stable context fields included in hash:**
#' - data_definition: User's data definition text
#' - chart_title: Chart title
#' - y_axis_unit: Y-axis unit (e.g., "%", "antal")
#' - target_value: Target value if set
#'
#' **Fields EXCLUDED from hash:**
#' - Timestamps (start_date, end_date)
#' - Plot objects
#' - Reactive values
#'
#' @examples
#' \dontrun{
#' metadata <- list(
#'   chart_type = "run",
#'   n_points = 24,
#'   signals_detected = 2,
#'   longest_run = 8,
#'   n_crossings = 3,
#'   centerline = 45.2,
#'   process_variation = "stable"
#' )
#'
#' context <- list(
#'   data_definition = "Ventetid i minutter",
#'   chart_title = "Akutmodtagelse ventetid",
#'   y_axis_unit = "minutter",
#'   target_value = 30
#' )
#'
#' key <- generate_ai_cache_key(metadata, context)
#' # Returns: "a1b2c3d4e5f6g7h8" (deterministic hash)
#' }
#'
#' @keywords internal
generate_ai_cache_key <- function(metadata, context) {
  # Normalize metadata (remove unstable fields like timestamps)
  stable_metadata <- list(
    chart_type = metadata$chart_type,
    n_points = metadata$n_points,
    signals_detected = metadata$signals_detected,
    longest_run = metadata$longest_run,
    n_crossings = metadata$n_crossings,
    centerline = metadata$centerline,
    process_variation = metadata$process_variation
  )

  # Normalize context (use %||% operator for null coalescing)
  stable_context <- list(
    data_definition = context$data_definition %||% "",
    chart_title = context$chart_title %||% "",
    y_axis_unit = context$y_axis_unit %||% "",
    target_value = as.character(context$target_value %||% "")
  )

  # Combine and serialize
  combined <- list(
    metadata = stable_metadata,
    context = stable_context
  )

  # Generate hash (using digest package with xxhash64 - fast and collision-resistant)
  key <- digest::digest(combined, algo = "xxhash64")

  if (exists("log_debug", mode = "function")) {
    log_debug(
      "[AI_CACHE]",
      "Cache key generated",
      details = list(key = key)
    )
  }

  return(key)
}

#' Initialize AI Cache in Session
#'
#' Should be called once per session, typically in app_server.R or
#' module initialization. Sets up session-scoped reactiveVal for cache
#' storage and configures automatic cleanup on session end.
#'
#' This function is idempotent - safe to call multiple times, will only
#' initialize once per session.
#'
#' @param session Shiny session object
#'
#' @details
#' **Cache structure:**
#' session$userData$ai_cache is a reactiveVal containing a list where:
#' - Keys are cache keys (from generate_ai_cache_key())
#' - Values are lists with: \code{list(value = response_text, timestamp = Sys.time())}
#'
#' **Cleanup:**
#' Registers session$onSessionEnded() callback to clear cache when user
#' disconnects, preventing memory leaks.
#'
#' @examples
#' \dontrun{
#' # In app_server.R or module
#' initialize_ai_cache(session)
#' }
#'
#' @keywords internal
initialize_ai_cache <- function(session) {
  shiny::req(session)

  if (is.null(session$userData$ai_cache)) {
    session$userData$ai_cache <- shiny::reactiveVal(list())

    if (exists("log_info", mode = "function")) {
      log_info(
        message = "AI cache initialized for session",
        component = "[AI_CACHE]",
        details = list(session_token = session$token)
      )
    }

    # Setup cleanup on session end
    session$onSessionEnded(function() {
      clear_ai_cache(session)

      if (exists("log_info", mode = "function")) {
        log_info(
          message = "AI cache cleared on session end",
          component = "[AI_CACHE]"
        )
      }
    })
  }
}

#' Get Cached AI Response
#'
#' Retrieves cached AI response for given key. Returns NULL if not found
#' or if TTL has expired.
#'
#' Automatically initializes cache if not already initialized.
#'
#' @param key Character string cache key (from generate_ai_cache_key())
#' @param session Shiny session object
#'
#' @return Cached response string, or NULL if not found/expired
#'
#' @details
#' **TTL Enforcement:**
#' Checks entry timestamp against current time. If age exceeds
#' cache_ttl_seconds from config, returns NULL (cache miss).
#'
#' **Performance:**
#' Cache lookup typically < 1ms. Much faster than API call (~5-10s).
#'
#' @examples
#' \dontrun{
#' key <- generate_ai_cache_key(metadata, context)
#' cached_response <- get_cached_ai_response(key, session)
#'
#' if (!is.null(cached_response)) {
#'   # Use cached response
#' } else {
#'   # Make API call and cache result
#' }
#' }
#'
#' @keywords internal
get_cached_ai_response <- function(key, session) {
  shiny::req(session)

  # Initialize if needed
  initialize_ai_cache(session)

  # Isolate reactive reads to avoid requiring reactive context
  cache <- shiny::isolate(session$userData$ai_cache())

  if (is.null(cache) || !key %in% names(cache)) {
    if (exists("log_debug", mode = "function")) {
      log_debug(
        "[AI_CACHE]",
        "Cache miss",
        details = list(key = key)
      )
    }
    return(NULL)
  }

  entry <- cache[[key]]

  # Check TTL
  ai_config <- get_ai_config()
  ttl <- ai_config$cache_ttl_seconds %||% 3600 # Default 1 hour

  age_seconds <- as.numeric(difftime(Sys.time(), entry$timestamp, units = "secs"))

  if (age_seconds > ttl) {
    if (exists("log_debug", mode = "function")) {
      log_debug(
        "[AI_CACHE]",
        "Cache expired",
        details = list(key = key, age_seconds = age_seconds, ttl = ttl)
      )
    }
    return(NULL)
  }

  if (exists("log_info", mode = "function")) {
    log_info(
      message = "Cache hit",
      component = "[AI_CACHE]",
      details = list(key = key, age_seconds = age_seconds)
    )
  }

  return(entry$value)
}

#' Cache AI Response
#'
#' Stores AI response in session cache with current timestamp.
#' Automatically initializes cache if not already initialized.
#'
#' @param key Character string cache key (from generate_ai_cache_key())
#' @param value Character string response to cache
#' @param session Shiny session object
#'
#' @details
#' **Storage:**
#' Adds/updates entry in cache with structure:
#' \code{list(value = response_text, timestamp = Sys.time())}
#'
#' **Memory:**
#' Cache is in-memory only, no persistence. Automatically cleared on
#' session end to prevent memory leaks.
#'
#' @examples
#' \dontrun{
#' key <- generate_ai_cache_key(metadata, context)
#' response <- call_ai_api(metadata, context)
#' cache_ai_response(key, response, session)
#' }
#'
#' @keywords internal
cache_ai_response <- function(key, value, session) {
  shiny::req(session)
  shiny::req(value)

  # Initialize if needed
  initialize_ai_cache(session)

  # Isolate reactive operations
  shiny::isolate({
    cache <- session$userData$ai_cache()

    # Add entry
    cache[[key]] <- list(
      value = value,
      timestamp = Sys.time()
    )

    # Update reactiveVal
    session$userData$ai_cache(cache)
  })

  if (exists("log_debug", mode = "function")) {
    log_debug(
      "[AI_CACHE]",
      "Response cached",
      details = list(key = key, value_length = nchar(value))
    )
  }
}

#' Clear AI Cache
#'
#' Clears all cached AI responses. Can be called manually or automatically
#' on session end.
#'
#' This is the only cache function that is exported - allows manual cache
#' clearing from UI or debugging contexts.
#'
#' @param session Shiny session object
#'
#' @examples
#' \dontrun{
#' # Manual cache clear (e.g., from UI button)
#' clear_ai_cache(session)
#' }
#'
#' @export
clear_ai_cache <- function(session) {
  shiny::req(session)

  if (!is.null(session$userData$ai_cache)) {
    # Isolate reactive operations
    shiny::isolate({
      cache <- session$userData$ai_cache()
      n_entries <- length(cache)

      session$userData$ai_cache(list())

      if (exists("log_info", mode = "function")) {
        log_info(
          message = "Cache cleared",
          component = "[AI_CACHE]",
          details = list(entries_removed = n_entries)
        )
      }
    })
  }
}

#' Get AI Cache Statistics
#'
#' Returns statistics about current AI cache state for debugging and monitoring.
#'
#' @param session Shiny session object
#'
#' @return List with cache stats:
#' \describe{
#'   \item{entries}{Number of cached entries}
#'   \item{total_size}{Total character count of all cached responses}
#'   \item{oldest_entry}{Timestamp of oldest cache entry (or NA if empty)}
#' }
#'
#' @details
#' **Use cases:**
#' - Performance monitoring (cache hit rate)
#' - Memory usage tracking
#' - Debugging cache behavior
#'
#' @examples
#' \dontrun{
#' stats <- get_ai_cache_stats(session)
#' message(sprintf(
#'   "Cache: %d entries, %d chars, oldest: %s",
#'   stats$entries,
#'   stats$total_size,
#'   stats$oldest_entry
#' ))
#' }
#'
#' @keywords internal
get_ai_cache_stats <- function(session) {
  shiny::req(session)

  if (is.null(session$userData$ai_cache)) {
    return(list(entries = 0, total_size = 0, oldest_entry = NA))
  }

  # Isolate reactive read
  cache <- shiny::isolate(session$userData$ai_cache())

  stats <- list(
    entries = length(cache),
    total_size = sum(vapply(cache, function(e) nchar(e$value), integer(1))),
    oldest_entry = if (length(cache) > 0) {
      min(vapply(cache, function(e) e$timestamp, numeric(1)))
    } else {
      NA_real_
    }
  )

  return(stats)
}
