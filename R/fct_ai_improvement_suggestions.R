# fct_ai_improvement_suggestions.R
# Core AI Logic for Improvement Suggestion Generation
#
# Dette modul orkestrerer hele AI suggestion-flowet:
# 1. Extract SPC metadata fra BFHcharts output
# 2. Build Gemini prompt med template + metadata + user context
# 3. Check cache før API call
# 4. Call Gemini API via integration layer
# 5. Validate og sanitize response
# 6. Cache result for future requests
#
# Design princip: Facade pattern der koordinerer alle AI components

#' Extract SPC Metadata for AI Prompt
#'
#' Ekstraherer struktureret SPC metadata fra BFHcharts output til brug i
#' AI prompt generation. Håndterer missing data gracefully med sensible defaults.
#'
#' @param spc_result List returned by compute_spc_results_bfh()
#'   Forventet struktur:
#'   - metadata: list med chart_type, n_points, signals_detected, anhoej_rules
#'   - qic_data: data.frame med x, y, cl, ucl, lcl columns
#'   - plot: ggplot2 object (ikke brugt her)
#'
#' @return Named list with extracted metadata:
#'   - chart_type: Chart type (e.g. "run", "p", "c")
#'   - chart_type_dansk: Danish name for chart type
#'   - n_points: Number of observations
#'   - signals_detected: Count of Anhøj rule violations
#'   - longest_run: Longest run above/below centerline
#'   - n_crossings: Number of centerline crossings
#'   - n_crossings_min: Expected minimum crossings
#'   - centerline: Mean of centerline values
#'   - start_date: First x value (as character)
#'   - end_date: Last x value (as character)
#'   - process_variation: "naturligt" or "ikke naturligt"
#'
#' @keywords internal
#' @examples
#' \dontrun{
#' spc_result <- compute_spc_results_bfh(data, "date", "value", "run")
#' metadata <- extract_spc_metadata(spc_result)
#' # metadata$chart_type == "run"
#' # metadata$process_variation == "naturligt" or "ikke naturligt"
#' }
extract_spc_metadata <- function(spc_result) {
  # Validate input
  if (is.null(spc_result) || !is.list(spc_result)) {
    log_warn("Invalid spc_result: NULL or not a list", .context = "AI_METADATA")
    return(NULL)
  }

  metadata <- list()

  # Extract from metadata component
  if (!is.null(spc_result$metadata)) {
    meta <- spc_result$metadata

    metadata$chart_type <- meta$chart_type %||% "unknown"
    metadata$chart_type_dansk <- map_chart_type_to_danish(metadata$chart_type)
    metadata$n_points <- meta$n_points %||% 0
    metadata$signals_detected <- meta$signals_detected %||% 0

    # Anhøj rules (qicharts2 output struktur)
    if (!is.null(meta$anhoej_rules)) {
      rules <- meta$anhoej_rules
      metadata$longest_run <- rules$longest_run %||% 0
      metadata$n_crossings <- rules$n_crossings %||% 0
      metadata$n_crossings_min <- rules$n_crossings_min %||% 0
    } else {
      # Fallback hvis anhoej_rules mangler
      metadata$longest_run <- 0
      metadata$n_crossings <- 0
      metadata$n_crossings_min <- 0
    }
  } else {
    log_warn("Missing metadata component in spc_result", .context = "AI_METADATA")
    return(NULL)
  }

  # Extract from qic_data (time period + centerline)
  if (!is.null(spc_result$qic_data) && nrow(spc_result$qic_data) > 0) {
    qic <- spc_result$qic_data

    # Centerline (mean of cl column)
    if ("cl" %in% names(qic) && !all(is.na(qic$cl))) {
      metadata$centerline <- round(mean(qic$cl, na.rm = TRUE), 2)
    } else {
      metadata$centerline <- NA_real_
    }

    # Time period (first and last x value)
    if ("x" %in% names(qic) && nrow(qic) > 0) {
      metadata$start_date <- as.character(qic$x[1])
      metadata$end_date <- as.character(qic$x[nrow(qic)])
    } else {
      metadata$start_date <- "Ikke angivet"
      metadata$end_date <- "Ikke angivet"
    }
  } else {
    log_warn("Missing or empty qic_data in spc_result", .context = "AI_METADATA")
    metadata$centerline <- NA_real_
    metadata$start_date <- "Ikke angivet"
    metadata$end_date <- "Ikke angivet"
  }

  # Process variation status baseret på Anhøj signals
  metadata$process_variation <- if (metadata$signals_detected > 0) {
    "ikke naturligt"
  } else {
    "naturligt"
  }

  log_debug("SPC metadata extracted", .context = "AI_METADATA",
    details = list(
      chart_type = metadata$chart_type,
      n_points = metadata$n_points,
      signals = metadata$signals_detected,
      variation = metadata$process_variation
    )
  )

  return(metadata)
}

#' Determine Target Comparison Status
#'
#' Sammenligner centerline med target value og returnerer dansk beskrivelse.
#' Bruger 5% tolerance for "ved målet" klassifikation.
#'
#' @param centerline Numeric centerline value
#' @param target_value Numeric target value (can be NULL, NA, or empty string)
#'
#' @return Character string:
#'   - "over målet" if centerline > target (outside tolerance)
#'   - "under målet" if centerline < target (outside tolerance)
#'   - "ved målet" if within 5% of target
#'   - "ikke angivet" if target is missing or invalid
#'
#' @keywords internal
#' @examples
#' \dontrun{
#' determine_target_comparison(12.5, 10) # "over målet"
#' determine_target_comparison(10.3, 10) # "ved målet" (within 5%)
#' determine_target_comparison(8.5, 10) # "under målet"
#' determine_target_comparison(12.5, NULL) # "ikke angivet"
#' }
determine_target_comparison <- function(centerline, target_value) {
  # Check if target is missing or invalid
  if (is.null(target_value) || length(target_value) == 0) {
    return("ikke angivet")
  }

  # Try to convert to numeric
  target <- suppressWarnings(as.numeric(target_value))

  if (is.na(target) || target_value == "") {
    return("ikke angivet")
  }

  # Check if centerline is missing or invalid
  if (is.null(centerline) || is.na(centerline)) {
    return("ikke angivet")
  }

  # Calculate tolerance (5% of target value)
  tolerance <- abs(target * 0.05)
  diff <- centerline - target

  # Classify based on tolerance
  if (abs(diff) <= tolerance) {
    return("ved målet")
  } else if (centerline > target) {
    return("over målet")
  } else {
    return("under målet")
  }
}

#' Build Gemini Prompt from Metadata and Context
#'
#' Kombinerer SPC metadata med user context og interpolerer prompt template.
#' Tilføjer target comparison baseret på centerline vs target.
#'
#' @param metadata List from extract_spc_metadata()
#' @param context List with user-provided context:
#'   - data_definition: Character string beskrivelse af indikator
#'   - chart_title: Character string graf titel
#'   - y_axis_unit: Character string måleenhed
#'   - target_value: Numeric target værdi (can be NULL)
#'
#' @return Character string with complete Gemini prompt (1500+ chars)
#'   med alle placeholders udfyldt
#'
#' @keywords internal
#' @examples
#' \dontrun{
#' metadata <- extract_spc_metadata(spc_result)
#' context <- list(
#'   data_definition = "Ventetid til operation",
#'   chart_title = "Ventetid 2024",
#'   y_axis_unit = "dage",
#'   target_value = 30
#' )
#' prompt <- build_gemini_prompt(metadata, context)
#' # Returns full prompt ready for Gemini API
#' }
build_gemini_prompt <- function(metadata, context) {
  # Validate inputs
  if (is.null(metadata) || is.null(context)) {
    log_error("Cannot build prompt: metadata or context is NULL", .context = "AI_PROMPT")
    return(NULL)
  }

  # Get template from config
  template <- get_improvement_suggestion_template()

  if (is.null(template) || nchar(template) == 0) {
    log_error("Failed to get prompt template", .context = "AI_PROMPT")
    return(NULL)
  }

  # Determine target comparison
  target_comparison <- determine_target_comparison(
    metadata$centerline,
    context$target_value
  )

  # Combine metadata + context + target comparison
  prompt_data <- c(
    metadata,
    context,
    list(target_comparison = target_comparison)
  )

  # Interpolate template with data
  prompt <- interpolate_prompt(template, prompt_data)

  if (is.null(prompt)) {
    log_error("Prompt interpolation failed", .context = "AI_PROMPT")
    return(NULL)
  }

  log_debug("Prompt built successfully",
    details = list(
      prompt_length = nchar(prompt),
      has_target = !is.null(context$target_value)
    )
  )

  return(prompt)
}

#' Generate AI-Powered Improvement Suggestion
#'
#' Main facade function der orkestrerer hele AI suggestion flowet:
#' 1. Extract SPC metadata fra BFHcharts output
#' 2. Check cache for existing suggestion
#' 3. Build Gemini prompt med metadata + user context
#' 4. Call Gemini API via integration layer
#' 5. Validate og sanitize response
#' 6. Cache result for future requests
#'
#' Funktionen bruger safe_operation() pattern og structured logging.
#' Ved fejl returneres NULL så UI kan håndtere gracefully.
#'
#' @param spc_result List returned by compute_spc_results_bfh()
#'   Skal indeholde metadata og qic_data components
#' @param context Named list with user context:
#'   - data_definition: Character string beskrivelse af indikator
#'   - chart_title: Character string graf titel
#'   - y_axis_unit: Character string måleenhed (e.g. "dage", "antal", "procent")
#'   - target_value: Numeric target værdi (optional, can be NULL)
#' @param session Shiny session object for cache access. Required.
#' @param max_chars Maximum characters in response (default 350).
#'   Typst template constraint.
#'
#' @return Character string with AI-generated improvement suggestion (max 350 chars)
#'   formatted in Danish with structure:
#'   - Context (indicator description)
#'   - Process variation status
#'   - Target comparison
#'   - Concrete suggestions (in italic)
#'   Returns NULL on error (logged with context).
#'
#' @export
#' @examples
#' \dontrun{
#' # Generate suggestion for run chart
#' spc_result <- compute_spc_results_bfh(data, "date", "value", "run")
#' context <- list(
#'   data_definition = "Ventetid til operation i dage",
#'   chart_title = "Ventetid ortopædkirurgi 2024",
#'   y_axis_unit = "dage",
#'   target_value = 30
#' )
#' suggestion <- generate_improvement_suggestion(
#'   spc_result, context, session,
#'   max_chars = 350
#' )
#' # Returns: "Ventetiden til operation varierer mellem... [suggestion text]"
#' }
generate_improvement_suggestion <- function(spc_result, context, session, max_chars = 350) {
  safe_operation(
    operation_name = "AI suggestion generation",
    code = {
      # Step 0: Validate inputs
      if (is.null(spc_result)) {
        log_error("spc_result is NULL", .context = "AI_SUGGESTION")
        return(NULL)
      }

      if (is.null(context)) {
        log_error("context is NULL", .context = "AI_SUGGESTION")
        return(NULL)
      }

      if (is.null(session)) {
        log_error("session is NULL - cache cannot work", .context = "AI_SUGGESTION")
        return(NULL)
      }

      log_info("Starting suggestion generation",
        details = list(
          chart_type = spc_result$metadata$chart_type %||% "unknown",
          has_definition = !is.null(context$data_definition) && nchar(context$data_definition) > 0,
          has_target = !is.null(context$target_value)
        )
      )

      # Step 1: Extract metadata
      metadata <- extract_spc_metadata(spc_result)

      if (is.null(metadata)) {
        log_error("Failed to extract SPC metadata", .context = "AI_SUGGESTION")
        return(NULL)
      }

      # Step 2: Check cache
      cache_key <- generate_ai_cache_key(metadata, context)
      cached <- get_cached_ai_response(cache_key, session)

      if (!is.null(cached)) {
        log_info("Cache hit - returning cached suggestion",
          details = list(cache_key = substr(cache_key, 1, 16))
        )
        return(cached)
      }

      log_debug("Cache miss - will call Gemini API", .context = "AI_SUGGESTION")

      # Step 3: Build prompt
      prompt <- build_gemini_prompt(metadata, context)

      if (is.null(prompt)) {
        log_error("Failed to build prompt", .context = "AI_SUGGESTION")
        return(NULL)
      }

      # Step 4: Call Gemini API
      ai_config <- get_ai_config()

      log_info("Calling Gemini API",
        details = list(
          model = ai_config$model,
          timeout = ai_config$timeout_seconds,
          prompt_length = nchar(prompt),
          prompt_preview = substr(prompt, 1, 200)
        )
      )

      # DEBUG: Log full prompt
      cat("\n========== GEMINI API REQUEST ==========\n")
      cat("PROMPT (", nchar(prompt), " chars):\n", sep = "")
      cat(prompt, "\n")
      cat("========================================\n\n")

      response <- call_gemini_api(
        prompt = prompt,
        model = ai_config$model,
        timeout = ai_config$timeout_seconds
      )

      # DEBUG: Log full response
      cat("\n========== GEMINI API RESPONSE ==========\n")
      if (!is.null(response)) {
        cat("RESPONSE (", nchar(response), " chars):\n", sep = "")
        cat(response, "\n")
      } else {
        cat("RESPONSE: NULL\n")
      }
      cat("=========================================\n\n")

      if (is.null(response)) {
        log_error("Gemini API returned NULL - check logs for error details", .context = "AI_SUGGESTION")
        return(NULL)
      }

      log_info("Gemini API response received",
        details = list(
          response_length = nchar(response),
          response_preview = substr(response, 1, 100)
        )
      )

      # Step 5: Validate response
      log_debug("Validating response",
        details = list(
          response_length = nchar(response),
          max_chars = max_chars
        )
      )

      validated <- validate_gemini_response(response, max_chars)

      # DEBUG: Log validation result
      cat("\n========== VALIDATION RESULT ==========\n")
      if (!is.null(validated)) {
        cat("VALIDATED (", nchar(validated), " chars):\n", sep = "")
        cat(validated, "\n")
      } else {
        cat("VALIDATED: NULL (validation failed)\n")
      }
      cat("=======================================\n\n")

      if (is.null(validated)) {
        log_error("Response validation failed - returning NULL", .context = "AI_SUGGESTION")
        return(NULL)
      }

      log_info("Response validated successfully",
        details = list(validated_length = nchar(validated))
      )

      # Step 6: Cache result
      cache_ai_response(cache_key, validated, session)

      log_info("Suggestion generated successfully",
        details = list(
          cache_key = substr(cache_key, 1, 16),
          response_length = nchar(validated),
          cached = TRUE
        )
      )

      return(validated)
    },
    fallback = NULL,
    show_user = TRUE
  )
}
