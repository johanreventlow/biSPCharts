# utils_bfhllm_integration.R
# biSPCharts Integration Layer for BFHllm Package
#
# Thin wrapper providing biSPCharts-specific configuration and helpers for
# BFHllm package integration. Delegates actual LLM/RAG work to BFHllm.

# CONFIG HELPERS ================================================================

#' Get AI Configuration from golem-config.yml
#'
#' Reads AI configuration settings from golem-config.yml.
#' Returns default values if config section is missing.
#'
#' @return Named list with AI configuration:
#'   - model: LLM model identifier
#'   - timeout_seconds: API call timeout
#'   - max_response_chars: Maximum response length
#'   - enabled: Whether AI is enabled
#'
#' @keywords internal
get_ai_config <- function() {
  # Silent-fail korrekt: golem-config er ikke tilgængelig i tests eller standalone-kørsel
  ai_config <- tryCatch(
    {
      golem::get_golem_options("ai")
    },
    error = function(e) NULL # nolint: swallowed_error_linter
  )

  # Default values
  defaults <- list(
    enabled = TRUE,
    provider = "gemini",
    model = "gemini-2.5-flash-lite",
    timeout_seconds = 10,
    max_response_chars = 350,
    cache_ttl_seconds = 3600
  )

  if (is.null(ai_config)) {
    return(defaults)
  }

  # Merge with defaults (ai_config overrides defaults)
  result <- modifyList(defaults, ai_config)
  return(result)
}

#' Get Session Persistence Configuration from golem-config.yml
#'
#' Reads session persistence settings (auto-save, auto-restore) from the
#' active golem-config profile. Returns sensible defaults if config section
#' is missing. Single source of truth for Issue #193.
#'
#' @return Named list with session configuration:
#'   - auto_save_enabled: Kontinuerlig auto-save hvert save_interval_ms
#'   - auto_restore_session: Genindlæs ved session start
#'   - save_interval_ms: Debounce for data changes (default 2000)
#'   - settings_save_interval_ms: Debounce for settings changes (default 1000)
#'
#' @keywords internal
get_session_config <- function() {
  # NB: Brug get_golem_config (lokal wrapper, læser fra YAML via config::get)
  # i stedet for golem::get_golem_options (som læser fra runtime-options).
  # Dette sikrer at YAML er single source of truth.
  # Silent-fail korrekt: get_golem_config kan mangle i tests; falder tilbage til defaults
  session_config <- tryCatch(
    {
      if (exists("get_golem_config", mode = "function")) {
        get_golem_config("session")
      } else {
        NULL
      }
    },
    error = function(e) NULL # nolint: swallowed_error_linter
  )

  defaults <- list(
    auto_save_enabled = TRUE,
    auto_restore_session = TRUE,
    save_interval_ms = 2000,
    settings_save_interval_ms = 1000
  )

  if (is.null(session_config)) {
    return(defaults)
  }

  modifyList(defaults, session_config)
}

#' Get RAG Configuration from golem-config.yml
#'
#' Reads RAG configuration settings from golem-config.yml.
#' Returns default values if config section is missing.
#'
#' @return Named list with RAG configuration:
#'   - enabled: Whether RAG is enabled
#'   - n_results: Number of knowledge chunks to retrieve
#'   - method: Search method (hybrid, vector, keyword)
#'
#' @keywords internal
get_rag_config <- function() {
  # Silent-fail korrekt: golem-config er ikke tilgængelig i tests eller standalone-kørsel
  ai_config <- tryCatch(
    {
      golem::get_golem_options("ai")
    },
    error = function(e) NULL # nolint: swallowed_error_linter
  )

  # Default values
  defaults <- list(
    enabled = TRUE,
    n_results = 3,
    method = "hybrid"
  )

  if (is.null(ai_config) || is.null(ai_config$rag)) {
    return(defaults)
  }

  # Merge with defaults
  result <- modifyList(defaults, ai_config$rag)
  return(result)
}

#' Get System Configuration
#'
#' Returns system-level configuration values.
#' Falls back to constants from config_system_config.R.
#'
#' @return Named list with system configuration
#'
#' @keywords internal
get_system_config <- function() {
  # Use values from CACHE_CONFIG constant
  list(
    cache_ttl_seconds = CACHE_CONFIG$default_timeout_seconds %||% 300,
    cache_size_limit = CACHE_CONFIG$size_limit_entries %||% 50
  )
}

# INITIALIZATION ================================================================

#' Initialize BFHllm for biSPCharts
#'
#' Configures BFHllm package with biSPCharts-specific defaults. Called during
#' app initialization (global.R or run_app.R).
#'
#' @param ai_config List with AI configuration from get_ai_config()
#' @param rag_config List with RAG configuration from get_rag_config()
#'
#' @return invisible(NULL)
#'
#' @keywords internal
initialize_bfhllm <- function(ai_config = NULL, rag_config = NULL) {
  if (!requireNamespace("BFHllm", quietly = TRUE)) {
    log_info("BFHllm not installed - AI features disabled", .context = "AI_SETUP")
    return(invisible(NULL))
  }

  # Get config if not provided
  if (is.null(ai_config)) {
    ai_config <- get_ai_config()
  }

  # Configure BFHllm with biSPCharts settings
  BFHllm::bfhllm_configure(
    provider = "gemini", # biSPCharts uses Gemini
    model = ai_config$model,
    timeout_seconds = ai_config$timeout_seconds,
    max_response_chars = ai_config$max_response_chars
  )

  log_info("BFHllm initialized",
    .context = "AI_SETUP",
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
#' Wrapper for BFHllm::bfhllm_chat_available() with biSPCharts logging.
#'
#' @return Logical, TRUE if BFHllm is configured and ready
#'
#' @keywords internal
is_bfhllm_available <- function() {
  if (!requireNamespace("BFHllm", quietly = TRUE)) {
    return(FALSE)
  }

  # H7 (#453): wrap probe i tryCatch så bad config / network-fejl ej
  # propagerer op til kalder. Matcher graceful-degradation-kontrakt
  # i CLAUDE.md §6 ("NULL + log warning ved fejl") og samme pattern
  # som generate_bfhllm_suggestion() bruger til chat-kald.
  # suppressWarnings(): BFHllm::bfhllm_validate_setup() kalder warning() ved
  # manglende API-key (forventet i CI + ved unsat env). Egen log_warn nedenfor
  # dækker observability — upstream-warning ville bryde test-gate (#650).
  available <- tryCatch(
    suppressWarnings(BFHllm::bfhllm_chat_available()),
    error = function(e) {
      log_warn(
        sprintf("BFHllm probe fejlede: %s", e$message),
        .context = LOG_CONTEXTS$ai$gemini,
        details = list(error_class = class(e)[1])
      )
      FALSE
    }
  )

  if (!isTRUE(available)) {
    log_warn(
      "BFHllm not available - check API key configuration",
      .context = "AI_SETUP"
    )
  }

  return(isTRUE(available))
}

#' Create BFHllm Cache for Shiny Session
#'
#' Wrapper for BFHllm::bfhllm_cache_shiny() that integrates with biSPCharts
#' configuration system.
#'
#' @param session Shiny session object
#'
#' @return BFHllm cache object (session-scoped)
#'
#' @keywords internal
create_bfhllm_cache <- function(session) {
  if (!requireNamespace("BFHllm", quietly = TRUE)) {
    return(NULL)
  }

  # Get TTL from biSPCharts config (if exists, otherwise use BFHllm default)
  system_config <- get_system_config()
  ttl <- system_config$cache_ttl_seconds %||% 3600 # 1 hour default

  cache <- BFHllm::bfhllm_cache_shiny(session, ttl_seconds = ttl)

  log_debug("BFHllm cache created",
    .context = "AI_CACHE",
    details = list(ttl_seconds = ttl)
  )

  return(cache)
}

#' Generate AI Improvement Suggestion (biSPCharts Wrapper)
#'
#' Wrapper for BFHllm::bfhllm_spc_suggestion() that adapts biSPCharts's
#' data structures and adds biSPCharts-specific logging.
#'
#' @param spc_result List from compute_spc_results_bfh() with metadata and qic_data
#' @param context Named list with biSPCharts context (data_definition, chart_title, etc.)
#' @param session Shiny session object for cache access
#' @param max_chars Maximum response characters (default from config)
#'
#' @return Character string with AI suggestion, or NULL on error
#'
#' @keywords internal
generate_bfhllm_suggestion <- function(spc_result, context, session, max_chars = NULL) {
  if (!requireNamespace("BFHllm", quietly = TRUE)) {
    log_info("BFHllm not installed - skipping AI suggestion", .context = "AI_SUGGESTION")
    return(NULL)
  }

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
    .context = "AI_SUGGESTION",
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
      .context = "AI_SUGGESTION",
      details = list(length = nchar(suggestion))
    )
  }

  return(suggestion)
}
