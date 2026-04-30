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

# HJAeLPEFUNKTIONER SETUP ====================================================

## Hovedfunktion for hjaelper
# Opsaetter alle hjaelper observers og status funktioner
setup_helper_observers <- function(input, output, session, obs_manager = NULL, app_state = NULL) {
  state_flag <- function(value, default = FALSE) {
    if (is.null(value) || length(value) == 0 || anyNA(value)) {
      return(default)
    }
    isTRUE(value[[1]])
  }

  # Centralized state is now always available
  # UNIFIED STATE: Empty table initialization now handled through session management events

  # UNIFIED EVENT SYSTEM: Use centralized app_state for dataLoaded status
  # Initialize dataLoaded status in app_state if not already present
  # Use isolate() to safely check reactive value outside reactive context
  current_status <- isolate(app_state$session$dataLoaded_status)
  if (is.null(current_status)) {
    app_state$session$dataLoaded_status <- "FALSE"
  }

  # Helper function to evaluate dataLoaded status (PERFORMANCE OPTIMIZED)
  evaluate_dataLoaded_status <- function() {
    current_data_check <- app_state$data$current_data

    result <- if (is.null(current_data_check)) {
      "FALSE"
    } else {
      # PERFORMANCE OPTIMIZED: Use cached content validator instead of repeated purrr::map_lgl
      meaningful_data <- evaluate_data_content_cached(
        current_data_check,
        cache_key = "dataLoaded_content_check",
        session = session,
        invalidate_events = c("data_loaded", "session_reset", "navigation_changed")
      )

      # Betragt kun data som indlaest hvis:
      # 1. Der er meningsfuldt data, ELLER
      # 2. Bruger har uploadet en fil, ELLER
      # 3. Bruger har eksplicit startet en ny session
      # Use unified state management
      file_uploaded_check <- app_state$session$file_uploaded

      # Use unified state management
      user_started_session_check <- app_state$session$user_started_session

      user_has_started <- file_uploaded_check || user_started_session_check %||% FALSE

      log_debug_kv(
        meaningful_data = meaningful_data,
        file_uploaded_check = file_uploaded_check,
        user_started_session_check = user_started_session_check,
        user_has_started = user_has_started,
        .context = "NAVIGATION_UNIFIED"
      )

      final_result <- if (meaningful_data || user_has_started) "TRUE" else "FALSE"
      final_result
    }
    return(result)
  }

  # UNIFIED EVENT LISTENERS: Update dataLoaded status when relevant events occur
  # SPRINT 4: Migrated from data_loaded to consolidated data_updated event
  shiny::observeEvent(app_state$events$data_updated, ignoreInit = TRUE, priority = OBSERVER_PRIORITIES$DATA_PROCESSING, {
    new_status <- evaluate_dataLoaded_status()
    app_state$session$dataLoaded_status <- new_status
  })

  shiny::observeEvent(app_state$events$session_reset, ignoreInit = TRUE, priority = OBSERVER_PRIORITIES$DATA_PROCESSING, {
    new_status <- evaluate_dataLoaded_status()
    app_state$session$dataLoaded_status <- new_status
  })

  shiny::observeEvent(app_state$events$navigation_changed, ignoreInit = TRUE, priority = OBSERVER_PRIORITIES$DATA_PROCESSING, {
    new_status <- evaluate_dataLoaded_status()
    app_state$session$dataLoaded_status <- new_status
  })

  # Data indlaesnings status flags - foelger BFH UTH moenster
  output$dataLoaded <- shiny::renderText({
    # UNIFIED EVENT SYSTEM: Return value from centralized app_state
    app_state$session$dataLoaded_status
  })
  outputOptions(output, "dataLoaded", suspendWhenHidden = FALSE)

  # UNIFIED EVENT SYSTEM: Use centralized app_state for has_data status
  # Initialize has_data status in app_state if not already present
  # Use isolate() to safely check reactive value outside reactive context
  current_has_data_status <- isolate(app_state$session$has_data_status)
  if (is.null(current_has_data_status)) {
    app_state$session$has_data_status <- "false"
  }

  # Helper function to evaluate has_data status (PERFORMANCE OPTIMIZED)
  evaluate_has_data_status <- function() {
    current_data_check <- app_state$data$current_data

    if (is.null(current_data_check)) {
      "false"
    } else {
      # PERFORMANCE OPTIMIZED: Use shared cached content validator
      meaningful_data <- evaluate_data_content_cached(
        current_data_check,
        cache_key = "has_data_content_check",
        session = session,
        invalidate_events = c("data_loaded", "session_reset", "navigation_changed")
      )
      if (meaningful_data) "true" else "false"
    }
  }

  # UNIFIED EVENT LISTENERS: Update has_data status when relevant events occur
  # SPRINT 4: Migrated from data_loaded to consolidated data_updated event
  shiny::observeEvent(app_state$events$data_updated, ignoreInit = TRUE, priority = OBSERVER_PRIORITIES$DATA_PROCESSING, {
    new_status <- evaluate_has_data_status()
    app_state$session$has_data_status <- new_status
  })

  shiny::observeEvent(app_state$events$session_reset, ignoreInit = TRUE, priority = OBSERVER_PRIORITIES$DATA_PROCESSING, {
    new_status <- evaluate_has_data_status()
    app_state$session$has_data_status <- new_status
  })

  shiny::observeEvent(app_state$events$navigation_changed, ignoreInit = TRUE, priority = OBSERVER_PRIORITIES$DATA_PROCESSING, {
    new_status <- evaluate_has_data_status()
    app_state$session$has_data_status <- new_status
  })

  # Initial evaluation to set correct startup state (once = TRUE: kun ved opstart)
  shiny::observeEvent(TRUE, once = TRUE, priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT, {
    initial_dataLoaded <- evaluate_dataLoaded_status()
    initial_has_data <- evaluate_has_data_status()
    app_state$session$dataLoaded_status <- initial_dataLoaded
    app_state$session$has_data_status <- initial_has_data
  })

  output$has_data <- shiny::renderText({
    # UNIFIED EVENT SYSTEM: Return value from centralized app_state
    app_state$session$has_data_status
  })
  outputOptions(output, "has_data", suspendWhenHidden = FALSE)


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
    app_state$data$table_operation_in_progress <- FALSE
    app_state$data$table_operation_cleanup_needed <- FALSE
  })

  # Register observer with manager (only if created)
  if (!is.null(obs_manager) && !is.null(obs_settings_save)) {
    obs_manager$add(obs_settings_save, "settings_auto_save")
  }

  # Diskret save-status indikator i navbar (Issue #193)
  # R renderer kun containeren; JS (shiny-handlers.js) haandterer
  # tidstaelling client-side hvert 5 s for at undgaa reactiveTimer
  # keepalive-effekt paa Connect Cloud.
  output$session_save_status <- shiny::renderUI({
    # Brug boolean flag i stedet for timestamp for at undgaa re-render
    # ved hvert save-cycle. JS ejer tidsteksten.
    has_saved <- !is.null(app_state$session$last_save_time)
    auto_save_on <- app_state$session$auto_save_enabled

    if (isFALSE(auto_save_on)) {
      return(shiny::span(
        shiny::icon("triangle-exclamation"),
        " Automatisk lagring deaktiveret",
        style = paste0("color: ", get_hospital_colors()$danger, "; font-size: 0.8rem;"),
        title = "Browseren har ikke plads til mere. Din data er stadig i appen."
      ))
    }

    if (!has_saved) {
      return(NULL)
    }

    # Container -- JS (_spcUpdateSaveElapsed) opdaterer teksten loebende
    shiny::span(
      shiny::icon("check"),
      " ",
      shiny::span(id = "save-elapsed-text", "Session gemt"),
      style = paste0("color: ", get_hospital_colors()$lightgrey, "; font-size: 0.8rem;"),
      title = "Indstillinger og data gemmes automatisk i din browser"
    )
  })

  # JS -> R feedback-kanal for localStorage save-result (Issue #193)
  # Lytter paa result fra shiny-handlers.js saveAppState handler.
  # Ved success: opdater last_save_time. Ved fejl: deaktiver auto-save og
  # vis dansk warning til brugeren.
  obs_save_result <- shiny::observeEvent(input$local_storage_save_result, {
    result <- input$local_storage_save_result
    if (is.null(result)) {
      return()
    }

    log_info(
      sprintf("localStorage save result: success=%s", isTRUE(result$success)),
      .context = "LOCAL_STORAGE"
    )

    if (isTRUE(result$success)) {
      app_state$session$last_save_time <- Sys.time()
    } else {
      log_warn(
        "localStorage save failed (quota or permission)",
        .context = "AUTO_SAVE"
      )
      app_state$session$auto_save_enabled <- FALSE
      shiny::showNotification(
        paste0(
          "Browseren kan ikke gemme mere data (lokal lagerplads fuld). ",
          "Automatisk lagring er deaktiveret for denne session."
        ),
        type = "warning",
        duration = 8
      )
    }
  })

  if (!is.null(obs_manager)) {
    obs_manager$add(obs_save_result, "local_storage_save_result")
  }

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
    Kommentar = rep(NA_character_, 20),
    stringsAsFactors = FALSE
  )
}

# ensure_standard_columns funktionen er nu defineret i global.R

## Aktuel organisatorisk enhed
# Reaktiv funktion for nuvaerende organisatoriske enhed
current_unit <- function(input) {
  shiny::reactive({
    # Helper to sanitize input values (same as in visualization server)
    sanitize_input <- function(input_value) {
      if (is.null(input_value) || length(input_value) == 0 || identical(input_value, character(0)) || input_value == "") {
        return("")
      }
      if (length(input_value) > 1) {
        input_value <- input_value[1]
      }
      return(input_value)
    }

    unit_type_safe <- sanitize_input(input$unit_type)
    if (unit_type_safe == "select") {
      unit_names <- list(
        "med" = "Medicinsk Afdeling",
        "kir" = "Kirurgisk Afdeling",
        "icu" = "Intensiv Afdeling",
        "amb" = "Ambulatorie",
        "akut" = "Akutmodtagelse",
        "paed" = "P\u00e6diatrisk Afdeling",
        "gyn" = "Gyn\u00e6kologi/Obstetrik"
      )
      selected_unit <- sanitize_input(input$unit_select)
      if (selected_unit != "" && selected_unit %in% names(unit_names)) {
        return(unit_names[[selected_unit]])
      } else {
        return("")
      }
    } else {
      return(sanitize_input(input$unit_custom))
    }
  })
}

## Komplet chart titel
# Reaktiv funktion for komplet chart titel
chart_title <- function(input) {
  shiny::reactive({
    # Helper to sanitize input values (same pattern throughout app)
    sanitize_input <- function(input_value) {
      if (is.null(input_value) || length(input_value) == 0 || identical(input_value, character(0)) || input_value == "") {
        return("")
      }
      if (length(input_value) > 1) {
        input_value <- input_value[1]
      }
      return(input_value)
    }

    indicator_title_safe <- sanitize_input(input$indicator_title)
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
