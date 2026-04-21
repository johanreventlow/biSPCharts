#' Performance Caching Utilities
#'
#' Caching system til at forbedre performance af expensive operations,
#' specielt auto-detection og data processing. Implementeret som del af
#' performance optimization efter tidyverse migration code review.
#'
#' @name performance_caching
NULL

# Module-level cache environment - brugt som fallback når session ikke er tilgængelig.
# BEMÆRK: Denne cache deles mellem sessions i samme R-process.
# Session-scoped caching foretrækkes via session$userData$performance_cache.
.performance_cache <- new.env(parent = emptyenv())

#' Create Cached Reactive
#'
#' Wrapper around reactive expressions med caching til expensive operations.
#' Implementerer memoization med digest-based cache keys.
#'
#' @param reactive_expr Reactive expression at cache
#' @param cache_key Character string eller function der genererer cache key
#' @param cache_timeout Timeout i sekunder (default: CACHE_CONFIG$default_timeout_seconds)
#' @param cache_size_limit Maximum antal cache entries (default: 50)
#'
#' @return Cached reactive expression
#'
#' @examples
#' \dontrun{
#' # Auto-detection caching
#' cached_autodetect <- create_cached_reactive(
#'   {
#'     detect_columns_full_analysis(data, app_state)
#'   },
#'   "autodetect",
#'   cache_timeout = CACHE_CONFIG$extended_timeout_seconds
#' )
#'
#' # Data-specific caching
#' cached_processing <- create_cached_reactive(
#'   {
#'     expensive_data_processing(data)
#'   },
#'   function() paste0("processing_", digest::digest(data)),
#'   CACHE_CONFIG$default_timeout_seconds
#' )
#' }
#'
#' @keywords internal
create_cached_reactive <- function(reactive_expr, cache_key, cache_timeout = CACHE_CONFIG$default_timeout_seconds, cache_size_limit = CACHE_CONFIG$size_limit_entries) {
  # FIX BUG #3: Capture expression lazily using substitute()
  # This allows reactive dependencies to trigger re-evaluation
  expr_call <- substitute(reactive_expr)
  expr_env <- parent.frame()

  # Create evaluation function that runs inside reactive context
  expr_fn <- if (is.function(reactive_expr)) {
    # Already a function - use directly
    reactive_expr
  } else {
    # Expression or code block - wrap in function for lazy evaluation
    eval(call("function", pairlist(), expr_call), expr_env)
  }

  # Convert cache_key to function if it's a string
  key_func <- if (is.function(cache_key)) {
    cache_key
  } else {
    function() as.character(cache_key)
  }

  # Instance-scoped nonce for cache isolation mellem forskellige wrappers
  # (undgår utilsigtede key-kollisioner på tværs af callers/sessions).
  instance_nonce <- digest::digest(
    list(
      as.numeric(Sys.time()),
      stats::runif(1)
    ),
    algo = "xxhash64"
  )

  # Revision bumpes ved hver reaktiv re-evaluering (dependency ændring eller
  # timeout-baseret invalidation). Dette sikrer at stale cache entries ikke
  # genbruges efter dependency change.
  reactive_revision <- 0L

  return(reactive({
    reactive_revision <<- reactive_revision + 1L

    # Sørg for timeout-baseret re-evaluering, så cache-expiry faktisk kan
    # træde i kraft selv når dependencies ikke ændrer sig.
    if (is.numeric(cache_timeout) && length(cache_timeout) == 1 && is.finite(cache_timeout) && cache_timeout > 0) {
      shiny::invalidateLater(max(1L, as.integer(cache_timeout * 1000)))
    }

    # Generate actual cache key
    actual_key <- paste0(
      key_func(),
      "::",
      instance_nonce,
      "::rev_",
      reactive_revision
    )

    # Check if cached result exists and is fresh
    cached_result <- get_cached_result(actual_key)

    if (!is.null(cached_result)) {
      log_debug(
        "Cache hit - returning cached result",
        .context = "PERFORMANCE_CACHE"
      )
      log_debug_kv(cache_key = actual_key, .context = "PERFORMANCE_CACHE")
      return(cached_result$value)
    }

    # Cache miss - compute new result
    log_debug(
      "Cache miss - computing new result",
      .context = "PERFORMANCE_CACHE"
    )
    log_debug_kv(cache_key = actual_key, .context = "PERFORMANCE_CACHE")

    # FIX BUG #3: Execute lazily via expr_fn() instead of evaluating reactive_expr directly
    start_time <- Sys.time()
    result <- expr_fn()
    computation_time <- as.numeric(Sys.time() - start_time)

    # Store result in cache
    cache_result(actual_key, result, cache_timeout)

    # Clean cache if needed
    manage_cache_size(cache_size_limit)

    log_debug(
      "Result cached successfully",
      .context = "PERFORMANCE_CACHE"
    )
    log_debug_kv(
      cache_key = actual_key,
      computation_time = computation_time,
      .context = "PERFORMANCE_CACHE"
    )

    return(result)
  }))
}

#' Generate Data-Based Cache Key
#'
#' Genererer cache key baseret på data content ved hjælp af digest.
#' Sikrer at cache keys ændres når data ændres.
#'
#' @param data Data object (data.frame, list, etc.)
#' @param prefix Cache key prefix for identification
#' @param include_names Include column/element names i cache key
#'
#' @return Character string med cache key
#'
#' @examples
#' \dontrun{
#' key <- generate_data_cache_key(my_data, "autodetect")
#' key_detailed <- generate_data_cache_key(my_data, "processing", TRUE)
#' }
#' @keywords internal
generate_data_cache_key <- function(data, prefix = "data", include_names = FALSE) {
  if (is.null(data) || length(data) == 0) {
    return(paste0(prefix, "_empty"))
  }

  # Standardiseret hashing: xxhash64 (hurtigere end md5, konsistent med resten af codebase)
  data_digest <- digest::digest(data, algo = "xxhash64")

  # Include structure information for better cache invalidation
  structure_info <- paste0(
    class(data)[1], "_",
    if (is.data.frame(data)) paste0(nrow(data), "x", ncol(data)) else length(data)
  )

  # Include names if requested (for column-dependent operations)
  names_part <- if (include_names && !is.null(names(data))) {
    digest::digest(names(data), algo = "xxhash64")
  } else {
    ""
  }

  cache_key <- paste0(prefix, "_", structure_info, "_", data_digest, "_", names_part)

  # Ensure key is not too long
  if (nchar(cache_key) > 200) {
    cache_key <- paste0(prefix, "_", digest::digest(cache_key, algo = "xxhash64"))
  }

  return(cache_key)
}

#' Cache Auto-Detection Results
#'
#' Specialiseret caching for auto-detection operations med intelligent
#' cache invalidation baseret på data changes og column structure.
#'
#' @param data Data at analysere
#' @param app_state App state object
#' @param force_refresh Force cache refresh (default: FALSE)
#'
#' @return Cached auto-detection results
#'
#' @examples
#' \dontrun{
#' results <- cache_auto_detection_results(data, app_state)
#' fresh_results <- cache_auto_detection_results(data, app_state, TRUE)
#' }
#'
#' @keywords internal
cache_auto_detection_results <- function(data, app_state, force_refresh = FALSE) {
  # Generate comprehensive cache key for auto-detection
  cache_key <- generate_data_cache_key(data, "autodetect", include_names = TRUE)

  if (!force_refresh) {
    cached_result <- get_cached_result(cache_key)
    if (!is.null(cached_result)) {
      log_debug(
        "Auto-detection cache hit",
        list(cache_key = cache_key, data_dims = dim(data)),
        .context = "AUTO_DETECT_CACHE"
      )
      return(cached_result$value)
    }
  }

  # Cache miss or forced refresh - perform auto-detection
  log_debug(
    "Auto-detection cache miss - running analysis",
    list(cache_key = cache_key, force_refresh = force_refresh),
    .context = "AUTO_DETECT_CACHE"
  )

  start_time <- Sys.time()

  # Use existing auto-detection logic (fra fct_autodetect_unified.R)
  results <- detect_columns_full_analysis(data, app_state)

  computation_time <- as.numeric(Sys.time() - start_time)

  # Cache results for 30 minutes (auto-detection is expensive, longer cache reduces duplicates)
  cache_result(cache_key, results, timeout_seconds = 1800)

  log_info(
    "Auto-detection completed and cached",
    .context = "AUTO_DETECT_CACHE"
  )
  log_debug_kv(
    cache_key = cache_key,
    computation_time = computation_time,
    results_count = length(results),
    .context = "AUTO_DETECT_CACHE"
  )

  return(results)
}

#' Cache Management Functions
#'

#' Manage Cache Size (LRU eviction)
#'
#' Sikrer at antallet af entries i `.performance_cache` ikke overstiger
#' `size_limit`. Bruger LRU-strategi: den ældst-tilgåede entry fjernes
#' først, når grænsen er nået.
#'
#' @param size_limit Maximum antal cache entries der må eksistere
#'   (default: CACHE_CONFIG$size_limit_entries eller 50).
#'
#' @return Invisible NULL
#'
#' @keywords internal
manage_cache_size <- function(size_limit = NULL) {
  if (is.null(size_limit)) {
    size_limit <- tryCatch(
      CACHE_CONFIG$size_limit_entries,
      error = function(e) 50L
    )
  }

  cache_keys <- ls(envir = .performance_cache)
  n_entries <- length(cache_keys)

  if (n_entries <= size_limit) {
    return(invisible(NULL))
  }

  # Hent last_access-tidsstempel for alle entries (LRU-orden)
  access_times <- vapply(cache_keys, function(k) {
    entry <- get(k, envir = .performance_cache)
    if (!is.null(entry$last_access)) {
      as.numeric(entry$last_access)
    } else {
      0
    }
  }, numeric(1L))

  # Fjern de ældste (mindst nyligt tilgåede) entries
  n_to_remove <- n_entries - size_limit
  oldest_keys <- cache_keys[order(access_times)[seq_len(n_to_remove)]]

  rm(list = oldest_keys, envir = .performance_cache)

  log_debug(
    "LRU cache eviction gennemfort",
    .context = "PERFORMANCE_CACHE"
  )
  log_debug_kv(
    removed_count = n_to_remove,
    remaining_count = length(ls(envir = .performance_cache)),
    .context = "PERFORMANCE_CACHE"
  )

  invisible(NULL)
}

#' Get Cached Result
#'
#' Henter cached result hvis det eksisterer og ikke er expired.
#'
#' @param cache_key Character string med cache key
#'
#' @return Cached result eller NULL hvis ikke fundet/expired
#'
get_cached_result <- function(cache_key) {
  if (!exists(cache_key, envir = .performance_cache)) {
    return(NULL)
  }

  cached_entry <- get(cache_key, envir = .performance_cache)

  # Check if expired
  if (Sys.time() > cached_entry$expires_at) {
    rm(list = cache_key, envir = .performance_cache)
    log_debug_kv(
      message = "Cache entry expired and removed",
      cache_key = cache_key,
      .context = "[PERFORMANCE_CACHE]"
    )
    return(NULL)
  }

  # Update access time for LRU management
  cached_entry$last_access <- Sys.time()
  assign(cache_key, cached_entry, envir = .performance_cache)

  return(cached_entry)
}

#' Cache Result
#'
#' Gemmer result i cache med expiration time.
#'
#' @param cache_key Character string med cache key
#' @param value Value at cache
#' @param timeout_seconds Timeout i sekunder
#'
cache_result <- function(cache_key, value, timeout_seconds) {
  cached_entry <- list(
    value = value,
    created_at = Sys.time(),
    expires_at = Sys.time() + timeout_seconds,
    last_access = Sys.time(),
    size_estimate = object.size(value)
  )

  assign(cache_key, cached_entry, envir = .performance_cache)
}

#' Clear Performance Cache
#'
#' Rydder hele performance cache. Bruges ved session cleanup
#' og efter store data changes.
#'
#' @param pattern Optional regex pattern til at rydde specific keys
#'
#' @examples
#' \dontrun{
#' clear_performance_cache() # Clear alt
#' clear_performance_cache("autodetect_.*") # Clear kun autodetect cache
#' }
#' @keywords internal
clear_performance_cache <- function(pattern = NULL) {
  cache_keys <- ls(envir = .performance_cache)

  if (!is.null(pattern)) {
    cache_keys <- cache_keys[grepl(pattern, cache_keys)]
  }

  if (length(cache_keys) > 0) {
    rm(list = cache_keys, envir = .performance_cache)

    log_debug_kv(
      message = "Performance cache cleared",
      pattern = pattern %||% "all",
      cleared_count = length(cache_keys),
      .context = "[PERFORMANCE_CACHE]"
    )
  }
}

#' Create Performance-Debounced Reactive
#'
#' Kombinerer caching med debouncing for optimal performance på
#' hyppigt-opdaterede reactive expressions.
#'
#' @param reactive_expr Reactive expression
#' @param cache_key Cache key (string eller function)
#' @param debounce_millis Debounce delay i millisekunder
#' @param cache_timeout Cache timeout i sekunder (default: CACHE_CONFIG$default_timeout_seconds)
#'
#' @return Debounced og cached reactive expression
#'
#' @examples
#' \dontrun{
#' optimized_reactive <- create_performance_debounced(
#'   reactive({
#'     expensive_computation(input$data)
#'   }),
#'   "computation",
#'   millis = 500,
#'   cache_timeout = CACHE_CONFIG$default_timeout_seconds
#' )
#' }
#'
#' @keywords internal
create_performance_debounced <- function(reactive_expr, cache_key, debounce_millis = 500, cache_timeout = CACHE_CONFIG$default_timeout_seconds) {
  # First apply caching
  cached_reactive <- create_cached_reactive(reactive_expr, cache_key, cache_timeout)

  # Then apply debouncing
  debounced_reactive <- shiny::debounce(cached_reactive, debounce_millis)

  return(debounced_reactive)
}
