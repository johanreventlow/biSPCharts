# utils_bfhllm_integration.R
# SPCify Integration Layer for BFHllm Package
#
# Thin wrapper providing SPCify-specific configuration and helpers for
# BFHllm package integration. Delegates actual LLM/RAG work to BFHllm.

#' Initialize BFHllm for SPCify
#'
#' Configures BFHllm package with SPCify-specific defaults. Called during
#' app initialization (global.R or run_app.R).
#'
#' @param ai_config List with AI configuration from get_ai_config()
#' @param rag_config List with RAG configuration from get_rag_config()
#'
#' @return invisible(NULL)
#'
#' @keywords internal
initialize_bfhllm <- function(ai_config = NULL, rag_config = NULL) {
  # Get config if not provided
  if (is.null(ai_config)) {
    ai_config <- get_ai_config()
  }

  # Configure BFHllm with SPCify settings
  BFHllm::bfhllm_configure(
    provider = "gemini", # SPCify uses Gemini
    model = ai_config$model,
    timeout_seconds = ai_config$timeout_seconds,
    max_response_chars = ai_config$max_response_chars
  )

  log_info("BFHllm initialized",
    details = list(
      model = ai_config$model,
      timeout = ai_config$timeout_seconds,
      max_chars = ai_config$max_response_chars
    )
  )

  invisible(NULL)
}

#' Check if BFHllm is Available
#'
#' Wrapper for BFHllm::bfhllm_chat_available() with SPCify logging.
#'
#' @return Logical, TRUE if BFHllm is configured and ready
#'
#' @keywords internal
is_bfhllm_available <- function() {
  available <- BFHllm::bfhllm_chat_available()

  if (!available) {
    log_warn("BFHllm not available - check API key configuration", .context = "AI_SETUP")
  }

  return(available)
}

#' Create BFHllm Cache for Shiny Session
#'
#' Wrapper for BFHllm::bfhllm_cache_shiny() that integrates with SPCify
#' configuration system.
#'
#' @param session Shiny session object
#'
#' @return BFHllm cache object (session-scoped)
#'
#' @keywords internal
create_bfhllm_cache <- function(session) {
  # Get TTL from SPCify config (if exists, otherwise use BFHllm default)
  system_config <- get_system_config()
  ttl <- system_config$cache_ttl_seconds %||% 3600 # 1 hour default

  cache <- BFHllm::bfhllm_cache_shiny(session, ttl_seconds = ttl)

  log_debug("BFHllm cache created",
    .context = "AI_CACHE",
    details = list(ttl_seconds = ttl)
  )

  return(cache)
}

#' Generate AI Improvement Suggestion (SPCify Wrapper)
#'
#' Wrapper for BFHllm::bfhllm_spc_suggestion() that adapts SPCify's
#' data structures and adds SPCify-specific logging.
#'
#' @param spc_result List from compute_spc_results_bfh() with metadata and qic_data
#' @param context Named list with SPCify context (data_definition, chart_title, etc.)
#' @param session Shiny session object for cache access
#' @param max_chars Maximum response characters (default from config)
#'
#' @return Character string with AI suggestion, or NULL on error
#'
#' @keywords internal
generate_bfhllm_suggestion <- function(spc_result, context, session, max_chars = NULL) {
  # Get max_chars from config if not specified
  if (is.null(max_chars)) {
    ai_config <- get_ai_config()
    max_chars <- ai_config$max_response_chars
  }

  # Get RAG config
  rag_config <- get_rag_config()
  use_rag <- isTRUE(rag_config$enabled)

  # Create cache
  cache <- create_bfhllm_cache(session)

  log_info("Generating AI suggestion via BFHllm",
    details = list(
      chart_type = spc_result$metadata$chart_type %||% "unknown",
      use_rag = use_rag,
      max_chars = max_chars
    )
  )

  # Call BFHllm
  suggestion <- tryCatch(
    {
      BFHllm::bfhllm_spc_suggestion(
        spc_result = spc_result,
        context = context,
        max_chars = max_chars,
        use_rag = use_rag,
        cache = cache
      )
    },
    error = function(e) {
      log_error(
        message = "BFHllm suggestion generation failed",
        .context = "AI_SUGGESTION",
        details = list(error = e$message)
      )
      return(NULL)
    }
  )

  if (is.null(suggestion)) {
    log_warn("BFHllm returned NULL suggestion", .context = "AI_SUGGESTION")
  } else {
    log_info("BFHllm suggestion generated successfully",
      details = list(length = nchar(suggestion))
    )
  }

  return(suggestion)
}
