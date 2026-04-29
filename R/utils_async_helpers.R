# utils_async_helpers.R
# Hjælpefunktioner til asynkron eksekution i Shiny-observere
#
# Formål: Isolere blocking-kald (AI-generering, PDF-eksport) fra Shiny-
# event-loopet så andre sessions på samme worker ikke blokeres.
#
# Kræver: shiny >= 1.8.0 (ExtendedTask), promises >= 1.3.0
#
# Design:
# - wrap_blocking_call(): synkron wrapper med error-handling (testbar)
# - validate_ai_prerequisites(): guard-funktion for AI-knap
# - make_ai_task(): fabriks-funktion der returnerer ExtendedTask

#' Wrap Blocking Call med Error Handling
#'
#' Kører `expr` synkront og fanger eventuelle fejl via `on_error`.
#' Primær brug: indkapsle eksterne API-kald som kan fejle, og sikre
#' at on_error-callback altid returnerer en kontrolleret værdi.
#'
#' @param expr Expression at evaluere (bruges med `{}` eller enkelt udtryk)
#' @param on_error Function(e) der modtager fejlobjektet og returnerer fallback
#'
#' @return Resultatet af `expr`, eller returnværdien af `on_error(e)` ved fejl
#'
#' @examples
#' \dontrun{
#' result <- wrap_blocking_call(
#'   expr = {
#'     some_api_call()
#'   },
#'   on_error = function(e) {
#'     log_warn(e$message)
#'     NULL
#'   }
#' )
#' }
#' @keywords internal
wrap_blocking_call <- function(expr, on_error = NULL) {
  if (is.null(on_error)) {
    on_error <- function(e) {
      log_debug(
        paste("wrap_blocking_call default error handler:", conditionMessage(e)),
        .context = "ASYNC_HELPER"
      )
      NULL
    }
  }
  tryCatch(
    expr,
    error = on_error
  )
}

#' Valider Forudsætninger for AI-funktion
#'
#' Guard-funktion der tjekker om AI-suggestion-knappen må aktiveres.
#' Adskiller guard-logik fra UI-håndtering for testbarhed.
#'
#' @param has_spc_data logical. TRUE hvis data + kolonner er klar til SPC
#' @param api_available logical. TRUE hvis BFHllm API er tilgængeligt
#'
#' @return logical. TRUE kun hvis BEGGE forudsætninger er opfyldt
#'
#' @keywords internal
validate_ai_prerequisites <- function(has_spc_data, api_available) {
  isTRUE(has_spc_data) && isTRUE(api_available)
}

#' Opret Asynkron AI-Task (ExtendedTask)
#'
#' Fabriks-funktion der opretter en `shiny::ExtendedTask` til asynkron
#' AI-analyse-generering. Kræver Shiny >= 1.8.0 og promises-pakken.
#'
#' Sessionen blokeres IKKE under AI-kaldet: andre sessions på samme
#' Connect-worker kan fortsat sende og modtage beskeder.
#'
#' @param session Shiny session object
#' @param get_spc_result Function() der returnerer SPC-result (synkron)
#' @param get_analysis_metadata Function() der returnerer metadata-liste
#' @param max_chars integer. Max tegn i AI-output (default 375)
#'
#' @return shiny::ExtendedTask objekt med $invoke() og $result() metoder.
#'   Returnerer NULL med log_warn hvis ExtendedTask ikke er tilgængeligt.
#'
#' @keywords internal
make_ai_extended_task <- function(
  session,
  get_spc_result,
  get_analysis_metadata,
  max_chars = 375L
) {
  # ExtendedTask kræver shiny >= 1.8.0
  if (!exists("ExtendedTask", where = asNamespace("shiny"), mode = "function")) {
    log_warn(
      "shiny::ExtendedTask ikke tilgængeligt (kræver shiny >= 1.8.0). Bruger synkron fallback.",
      .context = "ASYNC_HELPERS"
    )
    return(NULL)
  }

  # promises kræves til future_promise()
  if (!requireNamespace("promises", quietly = TRUE)) {
    log_warn(
      "promises-pakken er ikke installeret. Bruger synkron fallback.",
      .context = "ASYNC_HELPERS"
    )
    return(NULL)
  }

  shiny::ExtendedTask$new(function() {
    # Fang input i synkron kontekst FØR future startes
    spc_result <- get_spc_result()
    analysis_metadata <- get_analysis_metadata()

    promises::future_promise({
      wrap_blocking_call(
        expr = {
          if (is.null(spc_result) || is.null(spc_result$bfh_qic_result)) {
            stop("Intet SPC-resultat tilgængeligt til AI-analyse")
          }
          BFHcharts::bfh_generate_analysis(
            spc_result$bfh_qic_result,
            metadata  = analysis_metadata,
            use_ai    = TRUE,
            max_chars = max_chars
          )
        },
        on_error = function(e) {
          # Returnér fejlstruktur i stedet for at crashe task'en
          structure(
            list(error = e$message),
            class = "ai_task_error"
          )
        }
      )
    })
  }) |> shiny::bindToSession(session)
}
