#' Performance Caching Utilities
#'
#' Caching system til at forbedre performance af expensive operations,
#' specielt auto-detection og data processing. Implementeret som del af
#' performance optimization efter tidyverse migration code review.
#'
#' @name performance_caching
NULL

# Module-level cache environment - LEGACY fallback når app_state ej tilgængelig
# (test-context, batch-jobs uden session). Issue #529: session-scoped cache via
# app_state$cache$performance er den anbefalede vej i multi-session deploys.
.performance_cache <- new.env(parent = emptyenv())

#' Resolve performance cache environment
#'
#' Returnerer session-scoped cache fra app_state$cache$performance hvis sat,
#' ellers module-level fallback. Issue #529: forhindrer cross-session
#' contamination ved multi-session Connect Cloud-deploys.
#'
#' @param app_state Optional centralized app state. Hvis NULL: module-level cache.
#'
#' @return Environment til cache storage
#' @keywords internal
resolve_performance_cache <- function(app_state = NULL) {
  if (!is.null(app_state) &&
    !is.null(app_state$cache) &&
    !is.null(app_state$cache$performance) &&
    is.environment(app_state$cache$performance)) {
    return(app_state$cache$performance)
  }
  .performance_cache
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
    cached_result <- get_cached_result(cache_key, app_state = app_state)
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
  cache_result(cache_key, results, timeout_seconds = 1800, app_state = app_state)

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
manage_cache_size <- function(size_limit = NULL, app_state = NULL) {
  if (is.null(size_limit)) {
    size_limit <- tryCatch(
      CACHE_CONFIG$size_limit_entries,
      error = function(e) 50L
    )
  }

  cache_env <- resolve_performance_cache(app_state)
  cache_keys <- ls(envir = cache_env)
  n_entries <- length(cache_keys)

  if (n_entries <= size_limit) {
    return(invisible(NULL))
  }

  # Hent last_access-tidsstempel for alle entries (LRU-orden)
  access_times <- vapply(cache_keys, function(k) {
    entry <- get(k, envir = cache_env)
    if (!is.null(entry$last_access)) {
      as.numeric(entry$last_access)
    } else {
      0
    }
  }, numeric(1L))

  # Fjern de ældste (mindst nyligt tilgåede) entries
  n_to_remove <- n_entries - size_limit
  oldest_keys <- cache_keys[order(access_times)[seq_len(n_to_remove)]]

  rm(list = oldest_keys, envir = cache_env)

  log_debug(
    "LRU cache eviction gennemfort",
    .context = "PERFORMANCE_CACHE"
  )
  log_debug_kv(
    removed_count = n_to_remove,
    remaining_count = length(ls(envir = cache_env)),
    .context = "PERFORMANCE_CACHE"
  )

  invisible(NULL)
}

#' Get Cached Result
#'
#' Henter cached result hvis det eksisterer og ikke er expired.
#'
#' @param cache_key Character string med cache key
#' @param app_state Optional app_state for centralized cache resolution.
#'   Default NULL bruger global cache env.
#'
#' @return Cached result eller NULL hvis ikke fundet/expired
#'
get_cached_result <- function(cache_key, app_state = NULL) {
  cache_env <- resolve_performance_cache(app_state)

  if (!exists(cache_key, envir = cache_env)) {
    return(NULL)
  }

  cached_entry <- get(cache_key, envir = cache_env)

  # Check if expired
  if (Sys.time() > cached_entry$expires_at) {
    rm(list = cache_key, envir = cache_env)
    log_debug_kv(
      message = "Cache entry expired and removed",
      cache_key = cache_key,
      .context = "[PERFORMANCE_CACHE]"
    )
    return(NULL)
  }

  # Update access time for LRU management
  cached_entry$last_access <- Sys.time()
  assign(cache_key, cached_entry, envir = cache_env)

  return(cached_entry)
}

#' Cache Result
#'
#' Gemmer result i cache med expiration time.
#'
#' @param cache_key Character string med cache key
#' @param value Value at cache
#' @param timeout_seconds Timeout i sekunder
#' @param app_state Optional app_state for centralized cache resolution.
#'   Default NULL bruger global cache env.
#'
cache_result <- function(cache_key, value, timeout_seconds, app_state = NULL) {
  cache_env <- resolve_performance_cache(app_state)
  cached_entry <- list(
    value = value,
    created_at = Sys.time(),
    expires_at = Sys.time() + timeout_seconds,
    last_access = Sys.time(),
    size_estimate = object.size(value)
  )

  assign(cache_key, cached_entry, envir = cache_env)
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
clear_performance_cache <- function(pattern = NULL, app_state = NULL) {
  cache_env <- resolve_performance_cache(app_state)
  cache_keys <- ls(envir = cache_env)

  if (!is.null(pattern)) {
    cache_keys <- cache_keys[grepl(pattern, cache_keys)]
  }

  if (length(cache_keys) > 0) {
    rm(list = cache_keys, envir = cache_env)

    log_debug_kv(
      message = "Performance cache cleared",
      pattern = pattern %||% "all",
      cleared_count = length(cache_keys),
      .context = "[PERFORMANCE_CACHE]"
    )
  }
}
