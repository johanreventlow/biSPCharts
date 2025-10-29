# utils_ragnar_integration.R
# Ragnar RAG Integration Layer
# Provides knowledge store loading and querying for SPC methodology context

# MODULE STATE ==================================================================

# Module-level environment for session-scoped store caching
.ragnar_store_cache <- new.env(parent = emptyenv())
.ragnar_store_cache$store <- NULL
.ragnar_store_cache$load_attempted <- FALSE

# STORE LOADING =================================================================

#' Load Ragnar Knowledge Store
#'
#' Loads the pre-built Ragnar knowledge store from inst/ directory.
#' Store is loaded once per session and cached for performance.
#'
#' @return ragnar_store object or NULL if store not found/cannot be loaded
#' @keywords internal
#' @examples
#' \dontrun{
#' store <- load_ragnar_store()
#' if (!is.null(store)) {
#'   # Query store
#' }
#' }
load_ragnar_store <- function() {
  # Return cached store if already loaded
  if (!is.null(.ragnar_store_cache$store)) {
    log_debug("Using cached Ragnar store", .context = "RAG")
    return(.ragnar_store_cache$store)
  }

  # Don't retry if previous load attempt failed
  if (.ragnar_store_cache$load_attempted) {
    log_debug("Skipping reload - previous attempt failed", .context = "RAG")
    return(NULL)
  }

  # Mark load attempt
  .ragnar_store_cache$load_attempted <- TRUE

  # Check 1: Ragnar package installed
  if (!requireNamespace("ragnar", quietly = TRUE)) {
    log_warn(
      message = "Ragnar package not installed - RAG disabled",
      .context = "RAG",
      details = list(
        suggestion = "Install with: install.packages('ragnar')"
      )
    )
    return(NULL)
  }

  # Check 2: Store file exists
  # Try installed package location first, fallback to development mode
  store_path <- system.file("ragnar_store", package = "SPCify")

  # Development mode fallback: check inst/ragnar_store directly
  if (store_path == "" || !file.exists(store_path)) {
    dev_store_path <- "inst/ragnar_store"
    if (file.exists(dev_store_path)) {
      store_path <- dev_store_path
      log_debug("Using development mode store path", .context = "RAG")
    } else {
      log_warn(
        message = "Ragnar knowledge store not found",
        .context = "RAG",
        details = list(
          expected_installed = "inst/ragnar_store (in installed package)",
          expected_dev = "inst/ragnar_store (in source directory)",
          suggestion = "Run data-raw/build_ragnar_store.R to build store"
        )
      )
      return(NULL)
    }
  }

  log_debug("Loading Ragnar knowledge store", .context = "RAG")

  # Load store with error handling
  store <- tryCatch(
    {
      ragnar::ragnar_store_connect(location = store_path)
    },
    error = function(e) {
      log_error(
        message = "Failed to load Ragnar knowledge store",
        .context = "RAG",
        details = list(
          error = e$message,
          store_path = store_path
        )
      )
      return(NULL)
    }
  )

  if (is.null(store)) {
    return(NULL)
  }

  # Cache successfully loaded store
  .ragnar_store_cache$store <- store

  log_info(
    message = "Ragnar knowledge store loaded successfully",
    .context = "RAG",
    details = list(store_path = store_path)
  )

  return(store)
}

#' Reset Ragnar Store Cache
#'
#' Clears cached store and load attempt flag. Used for testing and
#' forcing reload after store rebuild.
#'
#' @return invisible(NULL)
#' @keywords internal
reset_ragnar_store_cache <- function() {
  .ragnar_store_cache$store <- NULL
  .ragnar_store_cache$load_attempted <- FALSE

  log_debug("Ragnar store cache reset", .context = "RAG")

  invisible(NULL)
}

# KNOWLEDGE QUERYING ============================================================

#' Query Knowledge Store for SPC Context
#'
#' Retrieves relevant SPC methodology context from Ragnar knowledge store
#' based on chart type, detected signals, and target comparison.
#'
#' @param chart_type Character string (Danish chart type, e.g. "serieplot")
#' @param signals Character vector of detected Anhøj rules (e.g. c("Serielængde", "Krydsninger"))
#' @param target_comparison Character string ("over", "under", "ved") or NULL
#' @param store ragnar_store object (default: load from package)
#' @param n_results Number of relevant chunks to retrieve (default: 3)
#'
#' @return Character string with concatenated retrieved context, or NULL on error
#' @keywords internal
#' @examples
#' \dontrun{
#' context <- query_spc_knowledge(
#'   chart_type = "serieplot",
#'   signals = c("Serielængde"),
#'   target_comparison = "over",
#'   n_results = 3
#' )
#' }
query_spc_knowledge <- function(chart_type,
                                signals,
                                target_comparison = NULL,
                                store = NULL,
                                n_results = 3) {
  # Load store if not provided
  if (is.null(store)) {
    store <- load_ragnar_store()
    if (is.null(store)) {
      log_debug("Store not available - skipping RAG query", .context = "RAG")
      return(NULL)
    }
  }

  # Build query from SPC metadata
  query_parts <- c(
    paste("Chart type:", chart_type),
    if (!is.null(signals) && length(signals) > 0) {
      paste("Signals detected:", paste(signals, collapse = ", "))
    } else {
      NULL
    },
    if (!is.null(target_comparison) && target_comparison != "") {
      paste("Target comparison:", target_comparison)
    } else {
      NULL
    },
    "How to interpret and suggest improvements?"
  )

  query <- paste(query_parts, collapse = ". ")

  log_debug(
    "Querying knowledge store",
    "query:", query,
    "n_results:", n_results,
    .context = "RAG"
  )

  # Retrieve relevant chunks
  results <- tryCatch(
    {
      ragnar::ragnar_retrieve(
        store = store,
        text = query,
        top_k = n_results
      )
    },
    error = function(e) {
      log_error(
        message = "Knowledge store query failed",
        .context = "RAG",
        details = list(
          error = e$message,
          query = query
        )
      )
      return(NULL)
    }
  )

  if (is.null(results) || nrow(results) == 0) {
    log_warn(
      message = "No knowledge chunks retrieved",
      .context = "RAG",
      details = list(query = query)
    )
    return(NULL)
  }

  # Extract and concatenate content
  context <- paste(results$content, collapse = "\n\n")

  log_info(
    "Knowledge store query successful",
    "chunks_retrieved:", nrow(results),
    "context_length:", nchar(context),
    .context = "RAG"
  )

  return(context)
}

# CONFIGURATION =================================================================

#' Get RAG Configuration
#'
#' Retrieves RAG settings from golem config with fallback defaults.
#'
#' @return List with RAG configuration (enabled, n_results, method)
#' @keywords internal
get_rag_config <- function() {
  ai_config <- golem::get_golem_options("ai")

  if (is.null(ai_config) || is.null(ai_config$rag)) {
    # Return defaults if config not available
    return(list(
      enabled = TRUE,
      n_results = 3,
      method = "hybrid"
    ))
  }

  list(
    enabled = ai_config$rag$enabled %||% TRUE,
    n_results = ai_config$rag$n_results %||% 3,
    method = ai_config$rag$method %||% "hybrid"
  )
}

#' Check if RAG is Enabled
#'
#' Checks if RAG feature is enabled in configuration and store is available.
#'
#' @return Logical indicating if RAG can be used
#' @keywords internal
is_rag_enabled <- function() {
  # Check config
  rag_config <- get_rag_config()
  if (!isTRUE(rag_config$enabled)) {
    log_debug("RAG disabled in config", .context = "RAG")
    return(FALSE)
  }

  # Check if store can be loaded
  store <- load_ragnar_store()
  if (is.null(store)) {
    log_debug("RAG store not available", .context = "RAG")
    return(FALSE)
  }

  return(TRUE)
}
