# utils_gemini_integration.R
# Google Gemini API Integration Layer
# Provides safe API wrapper, validation, timeout handling and circuit breaker

# CIRCUIT BREAKER STATE ========================================================

# Module-level environment for circuit breaker state tracking
.circuit_breaker_state <- new.env(parent = emptyenv())
.circuit_breaker_state$failures <- 0L
.circuit_breaker_state$last_failure_time <- NULL
.circuit_breaker_state$is_open <- FALSE

# SETUP VALIDATION ==============================================================

#' Validate Gemini API Setup
#'
#' Checks if all prerequisites for Gemini API are met:
#' - Ellmer package is installed
#' - GOOGLE_API_KEY environment variable is set
#' - AI feature is enabled in golem config
#'
#' @return Logical indicating if setup is valid
#' @keywords internal
#' @examples
#' \dontrun{
#' if (validate_gemini_setup()) {
#'   # Proceed with API calls
#' }
#' }
validate_gemini_setup <- function() {
  # Check 1: Ellmer package installed
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    log_warn(
      message = "Ellmer package not installed",
      .context = "GEMINI_API"
    )
    return(FALSE)
  }

  # Check 2: API key present and valid
  api_key <- Sys.getenv("GOOGLE_API_KEY")
  if (api_key == "" || api_key == "your_api_key_here") {
    log_warn(
      message = "GOOGLE_API_KEY not set or invalid",
      .context = "GEMINI_API"
    )
    return(FALSE)
  }

  # Check 3: AI enabled in config (use get_ai_config with fallback logic)
  ai_config <- get_ai_config()
  if (!isTRUE(ai_config$enabled)) {
    log_info(
      message = "AI feature disabled in config",
      .context = "GEMINI_API"
    )
    return(FALSE)
  }

  log_debug("Gemini setup validated successfully", .context = "GEMINI_API")
  return(TRUE)
}

# API WRAPPER ===================================================================

#' Call Gemini API with Error Handling
#'
#' Wrapper function for calling Google Gemini API with comprehensive error
#' handling, timeout management, and circuit breaker protection.
#'
#' @param prompt Character string with the prompt to send to Gemini
#' @param model Character string with model name. Default: "gemini-2.5-flash-lite"
#' @param timeout Numeric timeout in seconds. Default: 10
#'
#' @return Character string with response text, or NULL on error
#' @keywords internal
#' @examples
#' \dontrun{
#' response <- call_gemini_api(
#'   prompt = "Suggest improvements for this data pattern",
#'   timeout = 15
#' )
#' }
call_gemini_api <- function(prompt,
                            model = "gemini-2.5-flash-lite",
                            timeout = 10) {
  safe_operation(
    operation_name = "Gemini API call",
    code = {
      # Validate setup
      if (!validate_gemini_setup()) {
        stop("Gemini not configured. Check GOOGLE_API_KEY and config.")
      }

      # Check circuit breaker
      if (circuit_breaker_is_open()) {
        stop("Circuit breaker open - too many recent failures. Try again later.")
      }

      # Initialize chat
      # NOTE: Network connectivity is validated by ellmer itself.
      # LIMITATION: If network is unavailable, ellmer may hang for 30-60 seconds
      # (system default timeout) before failing. This is an upstream limitation
      # in ellmer's HTTP client. setTimeLimit() below may not interrupt C-level
      # network calls. Users should ensure stable internet before using AI features.
      log_debug(
        "Initializing Gemini chat",
        "model:", model,
        "prompt_length:", nchar(prompt),
        .context = "GEMINI_API"
      )

      chat <- ellmer::chat_google_gemini(
        model = model,
        api_key = Sys.getenv("GOOGLE_API_KEY")
      )

      # Call with timeout wrapper
      # NOTE: setTimeLimit may not interrupt all C-level network calls,
      # but ellmer should handle its own timeouts. This provides a backup.
      response <- NULL
      tryCatch(
        {
          setTimeLimit(elapsed = timeout, transient = TRUE)
          response <- chat$chat(prompt)
          setTimeLimit(elapsed = Inf, transient = FALSE)
        },
        error = function(e) {
          setTimeLimit(elapsed = Inf, transient = FALSE)
          if (grepl("reached elapsed time limit|time limit", e$message)) {
            stop("API call timeout exceeded")
          }
          stop(e$message)
        }
      )

      # Extract text (handle different ellmer response formats)
      text <- if (is.character(response)) {
        response # ellmer 0.2.0+ returns character vector directly
      } else if (is.list(response) && !is.null(response$text)) {
        response$text # Older ellmer versions return list with $text
      } else {
        stop("Unexpected response format from ellmer")
      }

      # Log success
      log_info(
        message = "Gemini API success",
        .context = "GEMINI_API",
        details = list(
          prompt_length = nchar(prompt),
          response_length = nchar(text),
          model = model
        )
      )

      # Record success for circuit breaker
      circuit_breaker_record_success()

      return(text)
    },
    fallback = function(e) {
      # Record failure for circuit breaker
      circuit_breaker_record_failure()

      # Classify error type
      error_type <- if (grepl("timeout", tolower(e$message))) {
        "timeout"
      } else if (grepl("rate", tolower(e$message))) {
        "rate_limit"
      } else if (grepl("api key", tolower(e$message))) {
        "invalid_key"
      } else if (grepl("circuit breaker", tolower(e$message))) {
        "circuit_breaker"
      } else if (grepl("network|connectivity|dns|nslookup", tolower(e$message))) {
        "network_error"
      } else {
        "api_error"
      }

      log_error(
        message = "Gemini API failed",
        .context = "GEMINI_API",
        details = list(
          error_type = error_type,
          error_message = e$message,
          model = model
        )
      )

      return(NULL)
    },
    show_user = TRUE,
    error_type = "api"
  )
}

# RESPONSE VALIDATION ===========================================================

#' Validate and Sanitize Gemini Response
#'
#' Validates API response text and sanitizes it by:
#' - Checking for NULL or empty responses
#' - Removing HTML tags
#' - Normalizing whitespace
#' - Trimming to maximum character limit
#'
#' @param text Character string with response from Gemini
#' @param max_chars Maximum allowed characters. Default: 350
#'
#' @return Sanitized text string, trimmed to max_chars, or NULL if invalid
#' @keywords internal
#' @examples
#' \dontrun{
#' sanitized <- validate_gemini_response(
#'   text = "<p>This is a suggestion</p>",
#'   max_chars = 100
#' )
#' }
validate_gemini_response <- function(text, max_chars = 350) {
  # Check for NULL or empty
  if (is.null(text) || !is.character(text) || nchar(text) == 0) {
    log_warn(
      message = "Empty or invalid response from Gemini",
      .context = "GEMINI_API"
    )
    return(NULL)
  }

  # Sanitize: Remove HTML tags
  text <- gsub("<[^>]+>", "", text)

  # Sanitize: Normalize whitespace
  text <- gsub("\\s+", " ", text)
  text <- trimws(text)

  # Check if still empty after sanitization
  if (nchar(text) == 0) {
    log_warn(
      message = "Response empty after sanitization",
      .context = "GEMINI_API"
    )
    return(NULL)
  }

  # Trim if needed (preserve word boundaries and markdown structure)
  if (nchar(text) > max_chars) {
    log_warn(
      message = "Response too long, trimming",
      .context = "GEMINI_API",
      details = list(
        original_length = nchar(text),
        max_chars = max_chars
      )
    )

    # Trim to max_chars - 3 (reserve space for "...")
    text <- substr(text, 1, max_chars - 3)

    # Find last space to avoid cutting mid-word
    last_space <- regexpr("\\s[^\\s]*$", text)
    if (last_space > 0) {
      text <- substr(text, 1, last_space)
    }

    # Trim trailing whitespace after word boundary cut
    text <- trimws(text)

    # Balance markdown asterisks (remove trailing * if odd count)
    asterisk_count <- lengths(regmatches(text, gregexpr("\\*", text)))
    if (asterisk_count %% 2 == 1) {
      # Odd number of asterisks - remove last one to balance
      text <- sub("\\*([^*]*)$", "\\1", text)
      text <- trimws(text)
    }

    text <- paste0(text, "...")
  }

  log_debug(
    "Response validated",
    "final_length:", nchar(text),
    .context = "GEMINI_API"
  )

  return(text)
}

# CIRCUIT BREAKER IMPLEMENTATION ================================================

#' Check if Circuit Breaker is Open
#'
#' Checks if the circuit breaker is currently open (blocking API calls).
#' Circuit breaker opens after threshold failures and automatically resets
#' after timeout period.
#'
#' @return Logical indicating if circuit breaker is open
#' @keywords internal
circuit_breaker_is_open <- function() {
  # Get config values with safe fallbacks
  ai_config <- golem::get_golem_options("ai")
  threshold <- ai_config$circuit_breaker$failure_threshold %||% 5L
  reset_timeout <- ai_config$circuit_breaker$reset_timeout_seconds %||% 300L

  if (!.circuit_breaker_state$is_open) {
    return(FALSE)
  }

  # Check if reset timeout has passed
  if (!is.null(.circuit_breaker_state$last_failure_time)) {
    elapsed <- as.numeric(
      difftime(
        Sys.time(),
        .circuit_breaker_state$last_failure_time,
        units = "secs"
      )
    )

    if (elapsed > reset_timeout) {
      log_info(
        message = "Circuit breaker reset after timeout",
        .context = "GEMINI_API",
        details = list(
          elapsed_seconds = round(elapsed, 1),
          reset_timeout_seconds = reset_timeout
        )
      )
      .circuit_breaker_state$is_open <- FALSE
      .circuit_breaker_state$failures <- 0L
      return(FALSE)
    }
  }

  return(TRUE)
}

#' Record Circuit Breaker Failure
#'
#' Records an API failure and opens circuit breaker if threshold is reached.
#'
#' @return invisible(NULL)
#' @keywords internal
circuit_breaker_record_failure <- function() {
  # Get config values with safe fallbacks
  ai_config <- golem::get_golem_options("ai")
  threshold <- ai_config$circuit_breaker$failure_threshold %||% 5L

  .circuit_breaker_state$failures <- .circuit_breaker_state$failures + 1L
  .circuit_breaker_state$last_failure_time <- Sys.time()

  if (.circuit_breaker_state$failures >= threshold) {
    .circuit_breaker_state$is_open <- TRUE
    log_error(
      message = "Circuit breaker opened",
      .context = "GEMINI_API",
      details = list(
        failures = .circuit_breaker_state$failures,
        threshold = threshold
      )
    )
  } else {
    log_debug(
      "Circuit breaker failure recorded",
      "failures:", .circuit_breaker_state$failures,
      "threshold:", threshold,
      .context = "GEMINI_API"
    )
  }

  invisible(NULL)
}

#' Record Circuit Breaker Success
#'
#' Records a successful API call and resets circuit breaker state.
#'
#' @return invisible(NULL)
#' @keywords internal
circuit_breaker_record_success <- function() {
  .circuit_breaker_state$failures <- 0L
  .circuit_breaker_state$is_open <- FALSE

  log_debug("Circuit breaker reset (success)", .context = "GEMINI_API")

  invisible(NULL)
}

#' Reset Circuit Breaker State (Testing/Admin)
#'
#' Manually reset circuit breaker state. Primarily for testing purposes
#' or administrative intervention.
#'
#' @return invisible(NULL)
#' @keywords internal
circuit_breaker_reset <- function() {
  .circuit_breaker_state$failures <- 0L
  .circuit_breaker_state$last_failure_time <- NULL
  .circuit_breaker_state$is_open <- FALSE

  log_info(
    message = "Circuit breaker manually reset",
    .context = "GEMINI_API"
  )

  invisible(NULL)
}

#' Get Circuit Breaker State (Testing/Debugging)
#'
#' Returns current circuit breaker state for debugging and testing.
#'
#' @return List with circuit breaker state information
#' @keywords internal
circuit_breaker_get_state <- function() {
  list(
    failures = .circuit_breaker_state$failures,
    is_open = .circuit_breaker_state$is_open,
    last_failure_time = .circuit_breaker_state$last_failure_time
  )
}
