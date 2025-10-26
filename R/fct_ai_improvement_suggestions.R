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
    log_warn("[AI_METADATA]", "Invalid spc_result: NULL or not a list")
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
    log_warn("[AI_METADATA]", "Missing metadata component in spc_result")
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
    log_warn("[AI_METADATA]", "Missing or empty qic_data in spc_result")
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

  log_debug("[AI_METADATA]", "SPC metadata extracted",
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
    log_error("[AI_PROMPT]", "Cannot build prompt: metadata or context is NULL")
    return(NULL)
  }

  # Get template from config
  template <- get_improvement_suggestion_template()

  if (is.null(template) || nchar(template) == 0) {
    log_error("[AI_PROMPT]", "Failed to get prompt template")
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
    log_error("[AI_PROMPT]", "Prompt interpolation failed")
    return(NULL)
  }

  log_debug("[AI_PROMPT]", "Prompt built successfully",
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
        log_error("[AI_SUGGESTION]", "spc_result is NULL")
        return(NULL)
      }

      if (is.null(context)) {
        log_error("[AI_SUGGESTION]", "context is NULL")
        return(NULL)
      }

      if (is.null(session)) {
        log_error("[AI_SUGGESTION]", "session is NULL - cache cannot work")
        return(NULL)
      }

      log_info("[AI_SUGGESTION]", "Starting suggestion generation",
        details = list(
          chart_type = spc_result$metadata$chart_type %||% "unknown",
          has_definition = !is.null(context$data_definition) && nchar(context$data_definition) > 0,
          has_target = !is.null(context$target_value)
        )
      )

      # Step 1: Extract metadata
      metadata <- extract_spc_metadata(spc_result)

      if (is.null(metadata)) {
        log_error("[AI_SUGGESTION]", "Failed to extract SPC metadata")
        return(NULL)
      }

      # Step 2: Check cache
      cache_key <- generate_ai_cache_key(metadata, context)
      cached <- get_cached_ai_response(cache_key, session)

      if (!is.null(cached)) {
        log_info("[AI_SUGGESTION]", "Cache hit - returning cached suggestion",
          details = list(cache_key = substr(cache_key, 1, 16))
        )
        return(cached)
      }

      log_debug("[AI_SUGGESTION]", "Cache miss - will call Gemini API")

      # Step 3: Build prompt
      prompt <- build_gemini_prompt(metadata, context)

      if (is.null(prompt)) {
        log_error("[AI_SUGGESTION]", "Failed to build prompt")
        return(NULL)
      }

      # Step 4: Call Gemini API
      ai_config <- get_ai_config()
      response <- call_gemini_api(
        prompt = prompt,
        model = ai_config$model,
        timeout = ai_config$timeout_seconds
      )

      if (is.null(response)) {
        log_warn("[AI_SUGGESTION]", "Gemini API returned NULL - check logs for error details")
        return(NULL)
      }

      # Step 5: Validate response
      validated <- validate_gemini_response(response, max_chars)

      if (is.null(validated)) {
        log_warn("[AI_SUGGESTION]", "Response validation failed")
        return(NULL)
      }

      # Step 6: Cache result
      cache_ai_response(cache_key, validated, session)

      log_info("[AI_SUGGESTION]", "Suggestion generated successfully",
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
