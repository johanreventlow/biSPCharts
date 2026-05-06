# utils_spc_cache.R
# Kanonisk SPC computation-cache (xxhash64-nøgler, LRU-eviction).
# Tre cache-lag eksisterer; dette er den primære:
#   utils_spc_cache.R         — kanonisk SPC-resultater (dette lag)
#   utils_qic_caching.R       — Anhøj/qicharts2-resultater (supplerende)
#   utils_performance_caching.R — generisk key-value (config, branding)

#' Generate Backend-Agnostic SPC Cache Key
#'
#' Creates a deterministic cache key based on data signature and configuration.
#' Works with both BFHchart and qicharts2 backends by focusing on data and
#' configuration rather than backend-specific API parameters.
#'
#' @details
#' **Cache Key Strategy:**
#' - Data signature: xxhash64 of relevant data columns only (x, y, n, cl, etc.)
#' - Config signature: xxhash64 of stable configuration parameters
#' - Combined format: `"spc_{chart_type}_{data_sig}_{config_sig}"`
#'
#' **Backend Independence:**
#' This function generates the same cache key regardless of whether BFHchart
#' or qicharts2 is used, enabling cache sharing during A/B testing and
#' seamless backend migration.
#'
#' **Performance:**
#' - Uses xxhash64 algorithm (5-10x faster than MD5)
#' - Reuses shared data signatures from utils_data_signatures.R when available
#' - Hashes only relevant columns, not entire dataset
#'
#' **Cache Invalidation:**
#' Cache keys automatically change when:
#' - Data values change (new data_signature)
#' - Configuration changes (chart type, freeze, part, target, etc.)
#' - Column mappings change (x, y, n columns)
#'
#' @param data data.frame. Input dataset with SPC data. Required.
#' @param config list. SPC configuration with keys:
#'   \describe{
#'     \item{chart_type}{character. Chart type (run, i, p, etc.). Required.}
#'     \item{x_column}{character. X-axis column name. Required.}
#'     \item{y_column}{character. Y-axis column name. Required.}
#'     \item{n_column}{character. Denominator column (optional).}
#'     \item{cl_column}{character. Centerline override column (optional).}
#'     \item{freeze_position}{integer. Freeze row position (optional).}
#'     \item{part_positions}{integer vector. Part boundaries (optional).}
#'     \item{target_value}{numeric. Target value (optional).}
#'     \item{centerline_value}{numeric. Custom centerline (optional).}
#'     \item{y_axis_unit}{character. Y-axis unit (optional).}
#'     \item{multiply_by}{numeric. Scale multiplier (optional, default 1).}
#'   }
#'
#' @return character. Cache key string in format: `"spc_{type}_{data}_{config}"`
#'   Example: `"spc_run_a3f9e2b1c4d8_7e4f2a1b9c3d"`
#'
#' @examples
#' \dontrun{
#' # Basic run chart
#' config <- list(
#'   chart_type = "run",
#'   x_column = "date",
#'   y_column = "value"
#' )
#' key <- generate_spc_cache_key(data, config)
#'
#' # P-chart with denominator and freeze
#' config <- list(
#'   chart_type = "p",
#'   x_column = "date",
#'   y_column = "complications",
#'   n_column = "procedures",
#'   freeze_position = 12,
#'   multiply_by = 100
#' )
#' key <- generate_spc_cache_key(data, config)
#'
#' # Multi-phase chart
#' config <- list(
#'   chart_type = "i",
#'   x_column = "week",
#'   y_column = "defects",
#'   part_positions = c(10, 20, 30),
#'   target_value = 5
#' )
#' key <- generate_spc_cache_key(data, config)
#' }
#'
#' @seealso
#' \code{\link{generate_shared_data_signature}} for data signature generation
#' \code{\link{cache_spc_result}} for caching SPC results
#' \code{\link{get_cached_spc_result}} for retrieving cached results
#' @keywords internal
generate_spc_cache_key <- function(data, config) {
  safe_operation(
    operation_name = "SPC cache key generation",
    code = {
      # 1. Validate inputs
      if (is.null(data) || !is.data.frame(data)) {
        stop("data must be a non-null data.frame")
      }

      if (is.null(config) || !is.list(config)) {
        stop("config must be a non-null list")
      }

      # 2. Validate required config keys
      required_keys <- c("chart_type", "x_column", "y_column")
      missing_keys <- setdiff(required_keys, names(config))

      if (length(missing_keys) > 0) {
        stop(paste(
          "config missing required keys:",
          paste(missing_keys, collapse = ", ")
        ))
      }

      # 3. Extract relevant data columns for signature
      # Only hash columns that affect SPC calculation. freeze_column og
      # part_column inkluderes (#482): toggle af freeze/part skifter
      # kolonne-vaerdier i data, og dermed cache-key — undgaar stale chart
      # ved baseline/fase-aendringer.
      data_columns <- c(
        config$x_column,
        config$y_column,
        config$n_column,
        config$cl_column,
        config$kommentar_column,
        config$freeze_column,
        config$part_column
      )

      # Filter to existing columns
      data_columns <- data_columns[!is.null(data_columns)]
      data_columns <- data_columns[data_columns %in% names(data)]

      if (length(data_columns) == 0) {
        stop("No valid data columns found for cache key generation")
      }

      # 4. Generate data signature (reuse shared signature if available)
      data_subset <- data[, data_columns, drop = FALSE]

      # Try to use shared data signature system
      if (exists("generate_shared_data_signature", mode = "function")) {
        data_signature <- generate_shared_data_signature(
          data_subset,
          include_structure = FALSE
        )
      } else {
        # Fallback: Direct xxhash64
        data_signature <- digest::digest(
          data_subset,
          algo = "xxhash64",
          serialize = TRUE
        )
      }

      # 5. Extract stable configuration elements
      # freeze_column/part_column/cl_column/kommentar_column tilfoejes (#482):
      # kolonne-NAVNE indgaar i config-hash saa skift mellem to forskellige
      # freeze-kolonner trigger cache-miss selv om data-indhold er ens.
      config_signature <- list(
        chart_type = config$chart_type,
        x_column = config$x_column,
        y_column = config$y_column,
        n_column = config$n_column,
        cl_column = config$cl_column,
        freeze_column = config$freeze_column,
        part_column = config$part_column,
        kommentar_column = config$kommentar_column,
        freeze_position = config$freeze_position,
        part_positions = config$part_positions,
        target_value = config$target_value,
        centerline_value = config$centerline_value,
        y_axis_unit = config$y_axis_unit,
        multiply_by = config$multiply_by %||% 1,
        # CRITICAL: Include viewport dimensions for context-aware caching
        # Different plot contexts (analysis, export_preview, export_pdf) have
        # different viewport dimensions which affect label placement in BFHcharts.
        # Without this, plots from one context would be incorrectly reused in another.
        viewport_width = config$viewport_width,
        viewport_height = config$viewport_height
      )

      # 6. Hash configuration
      config_hash <- digest::digest(
        config_signature,
        algo = "xxhash64",
        serialize = TRUE
      )

      # 7. Combine into cache key
      key_components <- c(
        "spc",
        config$chart_type,
        data_signature,
        config_hash
      )

      cache_key <- paste(key_components, collapse = "_")

      log_debug(
        paste(
          "Generated SPC cache key:",
          "chart_type =", config$chart_type,
          ", key =", substr(cache_key, 1, 40), "..."
        ),
        .context = "SPC_CACHE"
      )

      return(cache_key)
    },
    fallback = NULL,
    error_type = "cache_key_generation"
  )
}


#' Get Cached SPC Result
#'
#' Retrieves cached SPC computation result if available and not expired.
#'
#' @param cache_key character. Cache key from `generate_spc_cache_key()`.
#' @param cache cache object. QIC cache instance from `get_or_init_qic_cache()`.
#'
#' @return Cached SPC result (list with plot, qic_data, metadata) or NULL if
#'   cache miss or expired.
#'
#' @examples
#' \dontrun{
#' cache_key <- generate_spc_cache_key(data, config)
#' qic_cache <- get_or_init_qic_cache(app_state)
#' cached_result <- get_cached_spc_result(cache_key, qic_cache)
#'
#' if (!is.null(cached_result)) {
#'   # Cache hit - use cached result
#'   print(cached_result$plot)
#' } else {
#'   # Cache miss - compute fresh
#'   result <- compute_spc_results_bfh(...)
#' }
#' }
#'
#' @keywords internal
get_cached_spc_result <- function(cache_key, cache) {
  safe_operation(
    operation_name = "Retrieve cached SPC result",
    code = {
      if (is.null(cache_key) || !is.character(cache_key)) {
        return(NULL)
      }

      if (is.null(cache) || !is.list(cache)) {
        log_warn("Invalid cache object provided", .context = "SPC_CACHE")
        return(NULL)
      }

      # Retrieve from cache
      cached_value <- cache$get(cache_key)

      if (!is.null(cached_value)) {
        log_debug(
          paste("Cache hit for key:", substr(cache_key, 1, 40), "..."),
          .context = "SPC_CACHE"
        )
      }

      return(cached_value)
    },
    fallback = NULL,
    error_type = "cache_retrieval"
  )
}


#' Cache SPC Result
#'
#' Stores SPC computation result in cache with TTL.
#'
#' @param cache_key character. Cache key from `generate_spc_cache_key()`.
#' @param result SPC result (list with plot, qic_data, metadata).
#' @param cache cache object. QIC cache instance from `get_or_init_qic_cache()`.
#' @param ttl numeric. Time-to-live in seconds. Default 3600 (1 hour).
#'
#' @return TRUE if successfully cached, FALSE otherwise.
#'
#' @examples
#' \dontrun{
#' result <- compute_spc_results_bfh(data, config)
#' cache_key <- generate_spc_cache_key(data, config)
#' qic_cache <- get_or_init_qic_cache(app_state)
#' cache_spc_result(cache_key, result, qic_cache, ttl = 3600)
#' }
#'
#' @keywords internal
cache_spc_result <- function(cache_key, result, cache, ttl = 3600) {
  safe_operation(
    operation_name = "Cache SPC result",
    code = {
      if (is.null(cache_key) || !is.character(cache_key)) {
        log_warn("Invalid cache key - cannot cache result", .context = "SPC_CACHE")
        return(FALSE)
      }

      if (is.null(result)) {
        log_warn("Cannot cache NULL result", .context = "SPC_CACHE")
        return(FALSE)
      }

      if (is.null(cache) || !is.list(cache)) {
        log_warn("Invalid cache object - cannot cache result", .context = "SPC_CACHE")
        return(FALSE)
      }

      # Store in cache
      cache$set(cache_key, result, timeout = ttl)

      log_debug(
        paste(
          "Cached SPC result:",
          "key =", substr(cache_key, 1, 40), "...",
          ", ttl =", ttl, "seconds"
        ),
        .context = "SPC_CACHE"
      )

      return(TRUE)
    },
    fallback = FALSE,
    error_type = "cache_storage"
  )
}


#' Clear All SPC Cache Entries
#'
#' Removes all entries from a QIC cache object. Wrapper around `cache$clear()`
#' som muliggør testbar og eksplicit oprydning af SPC-cachen.
#'
#' @param cache cache object. QIC cache instance fra `get_or_init_qic_cache()` eller `create_qic_cache()`.
#'
#' @return TRUE hvis ryddet succesfuldt, FALSE ved fejl.
#'
#' @examples
#' \dontrun{
#' qic_cache <- get_or_init_qic_cache(app_state)
#' clear_spc_cache(qic_cache)
#' }
#'
#' @keywords internal
clear_spc_cache <- function(cache) {
  safe_operation(
    operation_name = "Clear SPC cache",
    code = {
      if (is.null(cache) || !is.list(cache) || !is.function(cache$clear)) {
        log_warn("Invalid cache object provided", .context = "SPC_CACHE")
        return(FALSE)
      }

      cache$clear()

      log_debug("SPC cache ryddet", .context = "SPC_CACHE")

      return(TRUE)
    },
    fallback = FALSE,
    error_type = "cache_clear"
  )
}
