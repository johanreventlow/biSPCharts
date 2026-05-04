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
#' Ved fejl returneres NULL saa UI kan haandtere gracefully.
#'
#' @param spc_result List returned by compute_spc_results_bfh()
#'   Skal indeholde metadata og qic_data components
#' @param context Named list with user context:
#'   - data_definition: Character string beskrivelse af indikator
#'   - chart_title: Character string graf titel
#'   - y_axis_unit: Character string maaleenhed (e.g. "dage", "antal", "procent")
#'   - target_value: Numeric target vaerdi (optional, can be NULL)
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
#'   chart_title = "Ventetid ortopaedkirurgi 2024",
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

      # #489: Server-side cap paa free-text-felter foer LLM-kald for at undgaa
      # cost-amplification + Gemini rate-limit ved meget store inputs.
      # Bruger samme limit som EXPORT_DESCRIPTION_MAX_LENGTH (2000) for
      # konsistens med PDF-eksport-validering. Truncation logges; ingen
      # user-warning i denne sti (UI-laget validerer separat via
      # validate_export_inputs).
      context <- truncate_llm_context_fields(context)

      # PHI-check: CPR-moenstre i data_definition -> modal advarsel foer afsendelse.
      # Pattern matcher dansk CPR-format: 6 cifre + valgfri bindestreg + 4 cifre.
      data_def_text <- context$data_definition %||% ""
      if (nchar(data_def_text) > 0 &&
        grepl("\\d{6}-?\\d{4}", data_def_text, perl = TRUE)) {
        log_warn(
          "CPR-m\u00f8nster fundet i data_definition \u2014 viser advarsel, afbryder AI-kald",
          .context = "AI_SUGGESTION"
        )
        tryCatch(
          shiny::showModal(shiny::modalDialog(
            title = "Mulig patientdata opdaget",
            shiny::p(
              "Beskrivelsesfeltet ser ud til at indeholde et CPR-nummer eller ",
              "lignende personidentifikation. Patientdata m\u00e5 ikke sendes til AI."
            ),
            shiny::p(
              "Fjern venligst persondataene fra indikatorbeskrivelsen og pr\u00f8v igen."
            ),
            footer = shiny::modalButton("Luk"),
            easyClose = TRUE
          )),
          error = function(e) {
            log_debug(
              paste("showModal fejlede (sandsynligvis uden for Shiny-kontekst):", e$message),
              .context = "AI_SUGGESTION"
            )
          }
        )
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

# Truncate free-text-felter i LLM-context til EXPORT_DESCRIPTION_MAX_LENGTH
# (#489). Beskytter mod cost-amplification og Gemini rate-limit ved meget
# lange inputs. Truncation logges paa info-niveau saa server-operatør kan
# spore mønstre. Returnerer modificeret context med samme keys.
truncate_llm_context_fields <- function(context,
                                        max_length = EXPORT_DESCRIPTION_MAX_LENGTH) {
  if (!is.list(context) || length(context) == 0) {
    return(context)
  }

  # Felter der kan rumme bruger-skrevet free-text. y_axis_unit og target er
  # korte enum/numeric — udelades.
  freetext_fields <- c(
    "data_definition", "chart_title", "department",
    "baseline_analysis", "signal_examples", "target_text",
    "target_display", "action_text", "y_axis_unit"
  )

  for (field in freetext_fields) {
    val <- context[[field]]
    if (!is.null(val) && is.character(val) && length(val) == 1L &&
      !is.na(val) && nchar(val) > max_length) {
      log_info(
        message = sprintf(
          "LLM-context: truncating %s fra %d til %d tegn (#489)",
          field, nchar(val), max_length
        ),
        .context = "AI_SUGGESTION"
      )
      context[[field]] <- substr(val, 1L, max_length)
    }
  }

  context
}
