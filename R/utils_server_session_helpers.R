# server_helpers.R
# Server hjaelpefunktioner og utility observers

# SESSION TIMEOUT ==============================================================

#' Dansk besked vist til bruger ved session-timeout
#'
#' @return Character string med dansk timeout-besked
#' @keywords internal
session_timeout_message <- function() {
  paste0(
    "Session udl\u00f8bet pga. inaktivitet. ",
    "Genindl\u00e6s siden for at forts\u00e6tte."
  )
}

#' Opsaet idle session timeout
#'
#' Disconnecter Shiny-sessionen efter \code{minutes} minutters inaktivitet.
#' Timeren nulstilles automatisk via \code{result$reset()}.
#'
#' Adfaerd:
#' \itemize{
#'   \item Kaller \code{session$close()} naar timeren udloeber.
#'   \item Dansk notifikation vises til bruger foer disconnect.
#'   \item Testbar via \code{.scheduler}-parameter (dependency injection).
#' }
#'
#' @param session Shiny session-objekt (skal have \code{$close()}-metode)
#' @param minutes Antal minutter til timeout (numerisk, positiv)
#' @param .scheduler Funktion med signatur \code{function(callback, delay_secs)}.
#'   Default: \code{later::later}. Override i tests for synkron eksekvering.
#' @return List med:
#'   \describe{
#'     \item{cancel}{Funktion der annullerer planlagt callback (no-op hvis allerede udlobet)}
#'     \item{reset}{Funktion der nulstiller timer fra dette tidspunkt}
#'   }
#' @keywords internal
setup_session_timeout <- function(session, minutes,
                                  .scheduler = later::later) {
  stopifnot(is.numeric(minutes), length(minutes) == 1L, minutes > 0)
  delay_secs <- as.numeric(minutes) * 60

  # Intern liste af annullerede handles
  cancelled <- FALSE
  handle <- NULL

  schedule_disconnect <- function() {
    cancelled <<- FALSE
    handle <<- .scheduler(
      callback = function() {
        if (cancelled) {
          return(invisible(NULL))
        }
        # Vis dansk notifikation hvis session-context understoetter det
        tryCatch(
          shiny::showNotification(
            session_timeout_message(),
            type     = "error",
            duration = 5,
            session  = session
          ),
          error = function(e) invisible(NULL)
        )
        # Disconnect sessionen
        tryCatch(
          session$close(),
          error = function(e) {
            log_warn(
              paste("setup_session_timeout: session$close() fejlede:", e$message),
              .context = "SESSION_TIMEOUT"
            )
          }
        )
      },
      delay = delay_secs
    )
    invisible(NULL)
  }

  # Plan initial timeout
  schedule_disconnect()

  list(
    cancel = function() {
      cancelled <<- TRUE
      invisible(NULL)
    },
    reset = function() {
      cancelled <<- TRUE # Annuller igangvaerende timer
      schedule_disconnect() # Planlaeg ny timer fra nu
      invisible(NULL)
    }
  )
}

#' Aktiver session timeout baseret paa golem-config
#'
#' Laeses \code{session_timeout_minutes} fra golem-config og opsaetter
#' \code{setup_session_timeout()} for sessionen. Nulstiller timer ved
#' enhver input-aendring.
#'
#' Skal kaldes fra \code{app_server_main.R} efter infrastruktur-init.
#'
#' @param input,session Shiny input og session-objekter
#' @param .scheduler Scheduler-funktion (default: \code{later::later}).
#'   Override i tests.
#' @keywords internal
activate_session_timeout_from_config <- function(input, session,
                                                 .scheduler = later::later) {
  # Hent timeout fra security-blok i golem-config (production: 60 min, dev: 480 min)
  # Kilde: inst/golem-config.yml -> <env>:security:session_timeout_minutes
  timeout_minutes <- tryCatch(
    golem::get_golem_options("security")$session_timeout_minutes,
    error = function(e) {
      log_debug(
        paste("get_golem_config('security') fejlede:", conditionMessage(e)),
        .context = "SESSION_TIMEOUT"
      )
      NULL
    }
  )

  # Ingen konfigureret timeout: deaktiver stiltiende
  if (is.null(timeout_minutes) || !is.numeric(timeout_minutes) || timeout_minutes <= 0) {
    log_debug(
      "Ingen session timeout konfigureret \u2014 deaktiveret",
      .context = "SESSION_TIMEOUT"
    )
    return(invisible(NULL))
  }

  log_info(
    sprintf("Session timeout aktiveret: %d minutter", as.integer(timeout_minutes)),
    .context = "SESSION_TIMEOUT"
  )

  timeout_handle <- setup_session_timeout(
    session    = session,
    minutes    = timeout_minutes,
    .scheduler = .scheduler
  )

  # Nulstil timer ved enhver input-aendring
  shiny::observe({
    # Touch alle inputs for at oprette reaktiv afhaengighed
    shiny::reactiveValuesToList(input)
    timeout_handle$reset()
  })

  # Annuller timer naar session lukker
  session$onSessionEnded(function() {
    timeout_handle$cancel()
  })

  invisible(timeout_handle)
}

# Dependencies ----------------------------------------------------------------

## Hovedfunktion for hjaelper
# Opsaetter alle hjaelper observers og status funktioner
setup_helper_observers <- function(input, output, session, obs_manager = NULL, app_state = NULL) {
  # Centralized state is now always available
  # UNIFIED STATE: Empty table initialization now handled through session management events

  register_session_status_outputs(output, session, app_state)

  # Feature flag guard: Hvis auto-save er deaktiveret i config, springer vi
  # oprettelsen af auto-save observers helt over. Dette gemmer baade CPU og
  # goer debugging nemmere naar funktionen er slaaet fra.
  auto_save_feature_enabled <- isTRUE(get_auto_save_enabled())

  log_info(
    sprintf(
      "Session persistence observers: auto_save=%s, auto_restore=%s, save_interval=%dms",
      auto_save_feature_enabled,
      isTRUE(get_auto_restore_enabled()),
      as.integer(get_save_interval_ms())
    ),
    .context = "AUTO_SAVE"
  )

  # PERFORMANCE OPTIMIZED: Reaktiv debounced auto-save med performance monitoring
  auto_save_trigger <- shiny::debounce(
    shiny::reactive({
      # Guards for at forhindre auto-gem under tabel operationer
      # Use unified state management
      updating_table_check <- state_flag(app_state$data$updating_table)

      # Use unified state management
      auto_save_enabled_check <- state_flag(app_state$session$auto_save_enabled, default = TRUE)

      # Use unified state management
      restoring_session_check <- state_flag(app_state$session$restoring_session)

      # Use unified state management
      table_operation_check <- state_flag(app_state$data$table_operation_in_progress)

      if (!auto_save_enabled_check ||
        updating_table_check ||
        table_operation_check ||
        restoring_session_check) {
        return(NULL)
      }

      # Use unified state management
      current_data_check <- app_state$data$current_data

      if (!is.null(current_data_check) &&
        nrow(current_data_check) > 0 &&
        any(!is.na(current_data_check))) {
        list(
          data = current_data_check,
          metadata = collect_metadata(input, app_state = app_state),
          timestamp = Sys.time()
        )
      } else {
        NULL
      }
    }),
    millis = get_save_interval_ms()
  )

  if (auto_save_feature_enabled) {
    obs_data_save <- shiny::observe({
      save_data <- auto_save_trigger()
      shiny::req(save_data) # Only proceed if we have valid save data

      # NB: last_save_time opdateres af local_storage_save_result observer
      # naar JS-siden bekraefter success -- ikke her.
      autoSaveAppState(session, save_data$data, save_data$metadata,
        app_state = app_state
      )
    })

    # Register observer with manager
    if (!is.null(obs_manager)) {
      obs_manager$add(obs_data_save, "data_auto_save")
    }
  }

  # Debounced target-input til settings-save: forhindrer settings_save per
  # tastetryk i target-feltet. Spejler debounced_target_value i
  # register_chart_type_events() men er en separat reaktiv for at bevare
  # isolation fra plot-render-flowet (fixes #396 target-symptom).
  target_value_save_debounced <- shiny::debounce(
    shiny::reactive(input$target_value %||% ""),
    millis = DEBOUNCE_DELAYS$chart_update # 500ms — matcher #395
  )

  # PERFORMANCE OPTIMIZED: Reaktiv debounced settings save med performance monitoring
  settings_save_trigger <- shiny::debounce(
    shiny::reactive({
      # KRITISK: Skab eksplicitte reactive deps paa input-felterne ved at laese
      # dem HER, udenfor isolate. Uden disse reads bliver reactiven kun
      # invalideret af app_state-deps, og collect_metadata(input, app_state = app_state) returnerer
      # stale metadata fordi alle input-reads inde i funktionen er isolated.
      # Dette er aarsagen til at fx export_title og active_tab ikke blev
      # persisteret selv om bindEvent korrekt fyrede observeren.
      force(input$main_navbar)
      force(input$indicator_title)
      force(input$unit_type)
      force(input$unit_select)
      force(input$unit_custom)
      force(input$indicator_description)
      force(input$x_column)
      force(input$y_column)
      force(input$n_column)
      force(input$skift_column)
      force(input$frys_column)
      force(input$kommentar_column)
      force(input$chart_type)
      force(target_value_save_debounced()) # debounced — undgaar save per tastetryk
      force(input$centerline_value)
      force(input$y_axis_unit)
      force(input[["export-export_title"]])
      force(input[["export-export_hospital"]])
      force(input[["export-export_department"]])
      force(input[["export-export_footnote"]])
      force(input[["export-export_format"]])
      force(input[["export-pdf_description"]])
      force(input[["export-pdf_improvement"]])
      force(input[["export-png_width"]])
      force(input[["export-png_height"]])

      # Samme guards som data auto-gem
      # Use unified state management
      updating_table_check <- state_flag(app_state$data$updating_table)

      # Use unified state management
      auto_save_enabled_check <- state_flag(app_state$session$auto_save_enabled, default = TRUE)

      # Use unified state management
      restoring_session_check <- state_flag(app_state$session$restoring_session)

      # Use unified state management
      table_operation_check_settings <- state_flag(app_state$data$table_operation_in_progress)

      if (!auto_save_enabled_check ||
        updating_table_check ||
        table_operation_check_settings ||
        restoring_session_check) {
        return(NULL)
      }

      # Use unified state management
      current_data_check <- app_state$data$current_data

      if (!is.null(current_data_check)) {
        md <- collect_metadata(input, app_state = app_state)
        # Diagnostik (Issue #193): verificer at felter rent faktisk fanges ved
        # save-tidspunkt -- baade target, trin 3-felter og active_tab.
        log_info(
          sprintf(
            paste0(
              "settings_save capture: active_tab='%s', target='%s', ",
              "export_title='%s', export_hospital='%s', export_department='%s', export_footnote='%s', export_format='%s', ",
              "pdf_description='%s', pdf_improvement='%s', ",
              "png_width='%s', png_height='%s'"
            ),
            md$active_tab %||% "<NULL>",
            md$target_value %||% "<NULL>",
            md$export_title %||% "<NULL>",
            md$export_hospital %||% "<NULL>",
            md$export_department %||% "<NULL>",
            md$export_footnote %||% "<NULL>",
            md$export_format %||% "<NULL>",
            md$pdf_description %||% "<NULL>",
            md$pdf_improvement %||% "<NULL>",
            md$png_width %||% "<NULL>",
            md$png_height %||% "<NULL>"
          ),
          .context = "AUTO_SAVE"
        )
        list(
          data = current_data_check,
          metadata = md,
          timestamp = Sys.time()
        )
      } else {
        NULL
      }
    }),
    millis = get_settings_save_interval_ms() # Faster debounce for settings
  )

  # Diff-check: undgaar duplicate localStorage-writes naar payload er identisk.
  # Eksempel: tab-revisit uden aendringer fyrer settings_save_trigger to gange
  # med identisk metadata. last_settings_payload fanges i closure (per session).
  # NB: sammenligner kun metadata, IKKE data + timestamp — timestamp aendres
  # hver gang og ville goere diff-checket virkningslost.
  last_settings_payload <- NULL

  obs_settings_save <- if (auto_save_feature_enabled) {
    # Ingen bindEvent her: settings_save_trigger har nu selv eksplicitte
    # input-deps, saa den fyrer via sin egen debounce naar inputs aendres.
    # Observeren reagerer paa trigger-invalidering og sparer dermed ikke stale
    # metadata (tidligere fejl: bindEvent fyrede observer foer debounce kunne
    # re-computere reactiven -> stale cached value blev gemt).
    shiny::observe({
      # Guard: spring over mens autogen overskriver pdf_improvement
      # programmatisk — undgår dobbeltsave (NULL + auto-tekst) ved tab-skift.
      if (isTRUE(app_state$session$autogen_active)) {
        return(invisible(NULL))
      }

      save_data <- settings_save_trigger()
      shiny::req(save_data) # Only proceed if we have valid save data

      # Diff-check: spring over hvis metadata er identisk med sidst gemte.
      # Fanger duplikater ved tab-revisit, identisk input-reaafiring o.l.
      # NB: de to events i #396-loggen (NULL → genereret tekst) har FORSKELLIG
      # metadata og passerer begge igennem — det er intentionelt korrekt adfaerd.
      current_payload <- jsonlite::toJSON(save_data$metadata, auto_unbox = TRUE)
      if (identical(last_settings_payload, current_payload)) {
        log_debug(
          "settings_save sprunget over: payload uaendret",
          .context = "AUTO_SAVE"
        )
        return(invisible(NULL))
      }
      last_settings_payload <<- current_payload

      # NB: last_save_time opdateres af local_storage_save_result observer
      # naar JS-siden bekraefter success -- ikke her.
      autoSaveAppState(session, save_data$data, save_data$metadata,
        app_state = app_state
      )
    })
  } else {
    NULL
  }

  # PERFORMANCE OPTIMIZED: Event-driven table operation cleanup med monitoring
  table_cleanup_trigger <- shiny::debounce(
    shiny::reactive({
      # Use unified state management
      table_operation_cleanup_needed_check <- app_state$data$table_operation_cleanup_needed

      if (table_operation_cleanup_needed_check) {
        Sys.time() # Return timestamp to trigger cleanup
      } else {
        NULL
      }
    }),
    millis = DEBOUNCE_DELAYS$table_cleanup
  )

  shiny::observe({
    cleanup_time <- table_cleanup_trigger()
    shiny::req(cleanup_time) # Only proceed if cleanup is needed

    # Clear the table operation flag and reset cleanup request
    # Use unified state management
    set_table_op_in_progress(app_state, FALSE)
    set_table_op_cleanup_needed(app_state, FALSE)
  })

  # Register observer with manager (only if created)
  if (!is.null(obs_manager) && !is.null(obs_settings_save)) {
    obs_manager$add(obs_settings_save, "settings_auto_save")
  }

  register_session_save_status_output(output, app_state)
  register_local_storage_save_result_observer(input, obs_manager, app_state)

  # UNIFIED EVENT SYSTEM: No return value needed - all navigation handled via events
  # Navigation is now managed through unified event system with dataLoaded_status and has_data_status
  return(NULL)
}

# HJAeLPEFUNKTIONER ============================================================

## Opret tom session data
# Opretter standarddatastruktur for nye sessioner
create_empty_session_data <- function() {
  data.frame(
    Skift = rep(FALSE, 20),
    Frys = rep(FALSE, 20),
    Dato = rep(NA_character_, 20),
    "T\u00e6ller" = rep(NA_real_, 20),
    "N\u00e6vner" = rep(NA_real_, 20),
    Kommentar = rep(NA_character_, 20)
  )
}

# ensure_standard_columns funktionen er nu defineret i global.R

## Aktuel organisatorisk enhed
# Reaktiv funktion for nuvaerende organisatoriske enhed
current_unit <- function(input) {
  shiny::reactive({
    unit_type_safe <- input_scalar(input$unit_type)
    if (unit_type_safe == "select") {
      selected_unit <- input_scalar(input$unit_select)
      if (nzchar(selected_unit) && selected_unit %in% names(UNIT_TYPE_LABELS)) {
        return(UNIT_TYPE_LABELS[[selected_unit]])
      } else {
        return("")
      }
    } else {
      return(input_scalar(input$unit_custom))
    }
  })
}

## Komplet chart titel
# Reaktiv funktion for komplet chart titel
chart_title <- function(input) {
  shiny::reactive({
    indicator_title_safe <- input_scalar(input$indicator_title)
    base_title <- if (indicator_title_safe == "") "SPC Analyse" else indicator_title_safe
    unit_name <- current_unit(input)()

    if (base_title != "SPC Analyse" && unit_name != "") {
      return(paste(base_title, "-", unit_name))
    } else if (base_title != "SPC Analyse") {
      return(base_title)
    } else if (unit_name != "") {
      return(paste("SPC Analyse -", unit_name))
    } else {
      return("SPC Analyse")
    }
  })
}
