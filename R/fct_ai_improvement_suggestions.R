# fct_ai_improvement_suggestions.R
# AI Improvement Suggestion Generation (BFHllm Integration)
#
# This module is now a thin wrapper around BFHllm package.
# All heavy lifting (metadata extraction, RAG, prompt building, LLM calls)
# is delegated to BFHllm::bfhllm_spc_suggestion().
#
# Migration: 2025-12-02 - Extracted AI functionality to BFHllm package

#' Generate AI-Powered Improvement Suggestion
#'
#' Main facade function der orkestrerer hele AI suggestion flowet via
#' BFHllm package. Delegerer metadata extraction, RAG query, prompt building,
#' og LLM call til BFHllm::bfhllm_spc_suggestion().
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
#' @param max_chars Maximum characters in response (default from config)
#'
#' @return Character string with AI-generated improvement suggestion (max 350 chars)
#'   formatted in Danish with structure:
#'   - Context (indicator description)
#'   - Process variation status
#'   - Target comparison
#'   - Concrete suggestions (in bold)
#'   Returns NULL on error (logged with context).
#'
#' @keywords internal
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
generate_improvement_suggestion <- function(spc_result, context, session, max_chars = NULL) {
  safe_operation(
    operation_name = "AI suggestion generation",
    code = {
      # Validate inputs
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

      log_info("Starting AI suggestion generation (via BFHllm)",
        details = list(
          chart_type = spc_result$metadata$chart_type %||% "unknown",
          has_definition = !is.null(context$data_definition) && nchar(context$data_definition) > 0,
          has_target = !is.null(context$target_value)
        )
      )

      # Delegate to BFHllm integration layer
      suggestion <- generate_bfhllm_suggestion(
        spc_result = spc_result,
        context = context,
        session = session,
        max_chars = max_chars
      )

      if (is.null(suggestion)) {
        log_warn("BFHllm returned NULL - AI suggestion unavailable", .context = "AI_SUGGESTION")
        return(NULL)
      }

      log_info("AI suggestion generated successfully via BFHllm",
        details = list(suggestion_length = nchar(suggestion))
      )

      return(suggestion)
    },
    fallback = NULL,
    show_user = TRUE
  )
}
