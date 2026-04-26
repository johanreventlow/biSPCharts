# utils_analytics_consent.R
# Server-side analytics consent gate og metadata haandtering

#' Tjek om analytics tracking skal vaere aktiv
#'
#' Verificerer baade bruger-consent og feature flag.
#'
#' @param consent Logical eller NULL — brugerens consent-status
#' @return Logical — TRUE hvis tracking er tilladt
#' @export
should_track_analytics <- function(consent = NULL) {
  analytics_enabled <- getOption("spc.analytics.enabled", default = ANALYTICS_CONFIG$enabled)
  if (!analytics_enabled) {
    return(FALSE)
  }
  if (is.null(consent) || !isTRUE(consent)) {
    return(FALSE)
  }
  TRUE
}

#' Formatér client metadata fra JavaScript
#'
#' Konverterer raa metadata fra JS til struktureret R-format.
#'
#' @param raw_metadata List fra Shiny.setInputValue('analytics_client_metadata')
#' @return List med formateret metadata, eller NULL
#' @keywords internal
format_analytics_metadata <- function(raw_metadata) {
  if (is.null(raw_metadata)) {
    return(NULL)
  }
  list(
    visitor_id = raw_metadata$visitor_id,
    browser = raw_metadata$user_agent,
    screen_width = raw_metadata$screen_width,
    screen_height = raw_metadata$screen_height,
    window_width = raw_metadata$window_width,
    window_height = raw_metadata$window_height,
    is_touch = isTRUE(raw_metadata$is_touch),
    language = raw_metadata$language,
    timezone = raw_metadata$timezone,
    referrer = raw_metadata$referrer,
    timestamp = raw_metadata$timestamp
  )
}

#' Setup analytics consent observer i Shiny server
#'
#' Registrerer observer paa input$analytics_consent og initialiserer
#' shinylogs KUN naar brugeren har accepteret.
#'
#' @param input Shiny input object
#' @param session Shiny session object
#' @param hashed_token Hashed session token for logging
#' @param log_directory Directory for shinylogs output
#' @return Invisible NULL
#' @keywords internal
setup_analytics_consent <- function(input, session, hashed_token, log_directory = "logs/") {
  config <- get_analytics_config()
  session$sendCustomMessage("spc_set_consent_version", config$consent_version)

  shiny::observeEvent(input$analytics_consent,
    {
      consent <- input$analytics_consent

      if (should_track_analytics(consent)) {
        safe_operation(
          "Initialize shinylogs after consent",
          code = {
            setup_shinylogs(
              enable_tracking = TRUE,
              enable_errors = TRUE,
              enable_performances = TRUE,
              log_directory = log_directory
            )
            initialize_shinylogs_tracking(
              session = session,
              app_name = "SPC_Analysis_Tool"
            )
            session$sendCustomMessage("spc_start_analytics", list())
            log_info("Analytics tracking aktiveret efter consent",
              .context = LOG_CONTEXTS$analytics$consent
            )

            # Registrer pin-sync EFTER shinylogs::track_usage har
            # registreret sin egen onSessionEnded — ellers loeber
            # vores callback foer shinylogs har skrevet JSON-filerne
            # til disk, og vi laeser tom logs/ mappe.
            # Silent-fail korrekt: session$token kan mangle før session er initialiseret
            session_token <- tryCatch(session$token, error = function(e) NULL) # nolint: swallowed_error_linter
            session$onSessionEnded(function() {
              safe_operation(
                "Aggregate analytics on session end",
                code = {
                  aggregate_and_pin_logs(log_directory, session_id = session_token)
                },
                fallback = function(e) {
                  log_error(paste("Log aggregering fejlede:", e$message),
                    .context = LOG_CONTEXTS$analytics$pins
                  )
                },
                error_type = "processing"
              )
            })
          },
          fallback = function(e) {
            log_error(paste("shinylogs init fejlede:", e$message),
              .context = LOG_CONTEXTS$analytics$consent
            )
          },
          error_type = "processing"
        )
      } else {
        log_debug("Analytics afvist af bruger",
          .context = LOG_CONTEXTS$analytics$consent
        )
      }
    },
    once = TRUE,
    ignoreNULL = TRUE
  )

  shiny::observeEvent(input$analytics_client_metadata,
    {
      metadata <- format_analytics_metadata(input$analytics_client_metadata)
      if (!is.null(metadata)) {
        log_info("Client metadata modtaget",
          .context = LOG_CONTEXTS$analytics$metadata
        )
        session$userData$analytics_metadata <- metadata
      }
    },
    once = TRUE,
    ignoreNULL = TRUE
  )

  shiny::observeEvent(input$analytics_performance,
    {
      perf <- input$analytics_performance
      if (!is.null(perf)) {
        log_debug_kv(
          message = paste("Performance:", perf$type),
          .context = LOG_CONTEXTS$analytics$performance,
          type = perf$type,
          duration_ms = perf$duration_ms %||% NA_real_
        )
      }
    },
    ignoreNULL = TRUE
  )

  invisible(NULL)
}
