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

#' Kræv cookie-samtykke før consent-bundet handling
#'
#' Wrapper omkring brugerhandlinger der kræver cookie-samtykke (fx
#' "Kom i gang"-knap der starter wizard, eller "Gendan session"-knap der
#' triggerer full restore). Hvis brugeren ej har truffet valg endnu, vises
#' modal og handling defereres indtil samtykke-callback fyrer.
#'
#' Flow:
#' 1. Hvis input$analytics_consent allerede sat (TRUE/FALSE) → kør then_do straks
#' 2. Hvis ej besluttet → gem then_do som callback + send spc_show_consent_modal
#' 3. Observer på input$analytics_consent (registreret separat) eksekverer
#'    callback efter modal-valg
#'
#' @param input Shiny input-objekt (typisk session$input)
#' @param session Shiny session-objekt (parent_session for moduler)
#' @param then_do Function() der skal køres når samtykke er truffet
#' @return Invisible TRUE hvis handling kørt straks, FALSE hvis defereret
#' @export
require_consent_or_show_modal <- function(input, session, then_do) {
  if (!is.function(then_do)) {
    stop("require_consent_or_show_modal: 'then_do' skal være en function")
  }
  consent <- tryCatch(
    shiny::isolate(input$analytics_consent),
    error = function(e) NULL # nolint: swallowed_error_linter
  )
  if (!is.null(consent) && !anyNA(consent) && length(consent) > 0L) {
    # Bruger har allerede besluttet — kør straks
    then_do()
    return(invisible(TRUE))
  }
  # Defer: gem callback i session$userData og vis modal
  session$userData$pending_consent_action <- then_do
  session$sendCustomMessage("spc_show_consent_modal", list())
  log_debug(
    "Consent-modal triggered for pending action",
    .context = LOG_CONTEXTS$analytics$consent
  )
  invisible(FALSE)
}

#' Tjek om localStorage-app-state-persistens er tilladt
#'
#' GDPR-binær consent-model: brugerens valg i cookie-modal gater alle
#' ikke-strengt-nødvendige features, inklusive auto-save af data + indstillinger.
#' Persistens er IKKE bundet til analytics-feature-flag (forskellig
#' GDPR-kategori — funktionel vs. statistik), kun til bruger-samtykket.
#'
#' Anvendes af saveDataLocally / loadDataLocally / autoSaveAppState
#' som forhåndskontrol før localStorage-roundtrip startes.
#'
#' @param input Shiny input-objekt (typisk session$input). Forventes at
#'   indeholde `analytics_consent` boolean sat af cookie-consent.js
#'   via Shiny.setInputValue.
#' @return Logical — TRUE hvis bruger har givet consent, ellers FALSE.
#'   Robust over for NULL/NA/manglende felt — defaulter til FALSE
#'   (fail-closed, GDPR-konservativt).
#' @export
is_persistence_allowed <- function(input) {
  # Læs reactive input value via isolate() — vi vil ikke skabe reactive
  # afhængighed på consent-flaget i kald-stedet (typisk en observer der
  # allerede har en anden trigger som debounced data-change).
  # Fail-closed: ved enhver fejl returnerer vi FALSE (GDPR-konservativt).
  # Bevidst stille fejl-håndtering: input kan være NULL i tests + initialisering
  # før Shiny har bundet inputs. Logging af hvert kald ville støje urimeligt
  # da gaten kaldes ved hver auto-save-tick (debounced 2s).
  consent <- tryCatch(
    shiny::isolate(input$analytics_consent),
    error = function(e) NULL # nolint: swallowed_error_linter
  )
  if (is.null(consent) || length(consent) == 0L) {
    return(FALSE)
  }
  if (anyNA(consent)) {
    return(FALSE)
  }
  isTRUE(consent[[1]])
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
    priority = OBSERVER_PRIORITIES$LOGGING,
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
            session$userData$analytics_started <- TRUE
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
              if (isTRUE(session$userData$analytics_revoked)) {
                log_info(
                  "Analytics-aggregering sprunget over — samtykke tilbagetrukket i sessionen",
                  .context = LOG_CONTEXTS$analytics$pins
                )
                return()
              }
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

  # Pending-action callback: kør deferred handling efter modal-valg.
  # Bruges af require_consent_or_show_modal() til at re-trigge fx
  # start_wizard eller restore_saved_session efter brugeren har truffet
  # consent-valg i modal. Observer fyrer ved hver consent-ændring (ej once)
  # så footer-link → revoke → re-accept flow også virker.
  shiny::observeEvent(input$analytics_consent,
    priority = OBSERVER_PRIORITIES$STATUS_UPDATES,
    {
      pending <- session$userData$pending_consent_action
      if (!is.null(pending) && is.function(pending)) {
        session$userData$pending_consent_action <- NULL
        log_debug(
          "Running deferred consent-action after modal decision",
          .context = LOG_CONTEXTS$analytics$consent
        )
        safe_operation(
          "Run deferred consent-action",
          code = pending(),
          fallback = function(e) {
            log_error(
              paste("Deferred consent-action fejlede:", e$message),
              .context = LOG_CONTEXTS$analytics$consent
            )
          },
          error_type = "processing"
        )
      }
    },
    ignoreNULL = TRUE
  )

  # Withdrawal-observer: fanger consent TRUE→FALSE transition EFTER shinylogs
  # allerede er startet. once=TRUE-observeren ovenfor er destrueret efter
  # første fyring — denne continuous observer gater på analytics_started-flag.
  # Stopper klient-side analytics via spc_stop_analytics + gater
  # log-aggregeringen ved session-afslutning (via analytics_revoked-flag).
  shiny::observeEvent(input$analytics_consent,
    priority = OBSERVER_PRIORITIES$LOGGING,
    {
      consent <- input$analytics_consent
      if (!isTRUE(consent) && isTRUE(session$userData$analytics_started) &&
        !isTRUE(session$userData$analytics_revoked)) {
        session$userData$analytics_revoked <- TRUE
        session$sendCustomMessage("spc_stop_analytics", list())
        log_info(
          paste0(
            "Analytics tracking stoppet efter samtykke-tilbagetrækning. ",
            "Klient-side metrics stoppet straks. ",
            "Server-side shinylogs-session kan ikke stoppes midt i session — ",
            "log-aggregering sprunget over ved session-afslutning."
          ),
          .context = LOG_CONTEXTS$analytics$consent
        )
      }
    },
    ignoreNULL = TRUE
  )

  shiny::observeEvent(input$analytics_client_metadata,
    priority = OBSERVER_PRIORITIES$LOGGING,
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
    priority = OBSERVER_PRIORITIES$LOGGING,
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
