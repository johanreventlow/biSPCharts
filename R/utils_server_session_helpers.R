# server_helpers.R
# Server hjælpefunktioner og utility observers

# Dependencies ----------------------------------------------------------------

# HJÆLPEFUNKTIONER SETUP ====================================================

## Hovedfunktion for hjælper
# Opsætter alle hjælper observers og status funktioner
setup_helper_observers <- function(input, output, session, obs_manager = NULL, app_state = NULL) {
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

      # Betragt kun data som indlæst hvis:
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
  shiny::observeEvent(app_state$events$data_updated, ignoreInit = TRUE, priority = 1000, {
    new_status <- evaluate_dataLoaded_status()
    app_state$session$dataLoaded_status <- new_status
  })

  shiny::observeEvent(app_state$events$session_reset, ignoreInit = TRUE, priority = 1000, {
    new_status <- evaluate_dataLoaded_status()
    app_state$session$dataLoaded_status <- new_status
  })

  shiny::observeEvent(app_state$events$navigation_changed, ignoreInit = TRUE, priority = 1000, {
    new_status <- evaluate_dataLoaded_status()
    app_state$session$dataLoaded_status <- new_status
  })

  # Data indlæsnings status flags - følger BFH UTH mønster
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
  shiny::observeEvent(app_state$events$data_updated, ignoreInit = TRUE, priority = 1000, {
    new_status <- evaluate_has_data_status()
    app_state$session$has_data_status <- new_status
  })

  shiny::observeEvent(app_state$events$session_reset, ignoreInit = TRUE, priority = 1000, {
    new_status <- evaluate_has_data_status()
    app_state$session$has_data_status <- new_status
  })

  shiny::observeEvent(app_state$events$navigation_changed, ignoreInit = TRUE, priority = 1000, {
    new_status <- evaluate_has_data_status()
    app_state$session$has_data_status <- new_status
  })

  # Initial evaluation to set correct startup state
  shiny::observe(
    {
      initial_dataLoaded <- evaluate_dataLoaded_status()
      initial_has_data <- evaluate_has_data_status()
      app_state$session$dataLoaded_status <- initial_dataLoaded
      app_state$session$has_data_status <- initial_has_data
    },
    priority = 2000
  ) # High priority to run early

  output$has_data <- shiny::renderText({
    # UNIFIED EVENT SYSTEM: Return value from centralized app_state
    app_state$session$has_data_status
  })
  outputOptions(output, "has_data", suspendWhenHidden = FALSE)


  # Data status visning
  output$data_status_display <- shiny::renderUI({
    # Use unified state management
    file_uploaded_check <- app_state$session$file_uploaded

    # UNIFIED EVENT SYSTEM: Direct access to current data
    current_data_check <- app_state$data$current_data

    if (is.null(current_data_check)) {
      shiny::div(
        shiny::span(class = "status-indicator status-warning"),
        "Ingen data",
        style = "font-size: 0.9rem;"
      )
    } else if (file_uploaded_check) {
      data_rows <- sum(!is.na(current_data_check[[1]]))
      shiny::div(
        shiny::span(class = "status-indicator status-ready"),
        paste("Fil uploadet -", data_rows, "datapunkter"),
        style = "font-size: 0.9rem;"
      )
    } else {
      data_rows <- sum(!is.na(current_data_check[[1]]))
      if (data_rows > 0) {
        shiny::div(
          shiny::span(class = "status-indicator status-processing"),
          paste("Manuel indtastning -", data_rows, "datapunkter"),
          style = "font-size: 0.9rem;"
        )
      } else {
        shiny::div(
          shiny::span(class = "status-indicator status-warning"),
          "Tom tabel - indtast data eller upload fil",
          style = "font-size: 0.9rem;"
        )
      }
    }
  })


  # Feature flag guard: Hvis auto-save er deaktiveret i config, springer vi
  # oprettelsen af auto-save observers helt over. Dette gemmer både CPU og
  # gør debugging nemmere når funktionen er slået fra.
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
      updating_table_check <- app_state$data$updating_table

      # Use unified state management
      auto_save_enabled_check <- app_state$session$auto_save_enabled

      # Use unified state management
      restoring_session_check <- app_state$session$restoring_session

      # Use unified state management
      table_operation_check <- app_state$data$table_operation_in_progress

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
          metadata = collect_metadata(input),
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
      # når JS-siden bekræfter success — ikke her.
      autoSaveAppState(session, save_data$data, save_data$metadata,
        app_state = app_state)
    })

    # Register observer with manager
    if (!is.null(obs_manager)) {
      obs_manager$add(obs_data_save, "data_auto_save")
    }
  }

  # PERFORMANCE OPTIMIZED: Reaktiv debounced settings save med performance monitoring
  settings_save_trigger <- shiny::debounce(
    shiny::reactive({
      # Samme guards som data auto-gem
      # Use unified state management
      updating_table_check <- app_state$data$updating_table

      # Use unified state management
      auto_save_enabled_check <- app_state$session$auto_save_enabled

      # Use unified state management
      restoring_session_check <- app_state$session$restoring_session

      # Use unified state management
      table_operation_check_settings <- app_state$data$table_operation_in_progress

      if (!auto_save_enabled_check ||
        updating_table_check ||
        table_operation_check_settings ||
        restoring_session_check) {
        return(NULL)
      }

      # Use unified state management
      current_data_check <- app_state$data$current_data

      if (!is.null(current_data_check)) {
        list(
          data = current_data_check,
          metadata = collect_metadata(input),
          timestamp = Sys.time()
        )
      } else {
        NULL
      }
    }),
    millis = get_settings_save_interval_ms() # Faster debounce for settings
  )

  obs_settings_save <- if (auto_save_feature_enabled) {
    shiny::observe({
      save_data <- settings_save_trigger()
      shiny::req(save_data) # Only proceed if we have valid save data

      # NB: last_save_time opdateres af local_storage_save_result observer
      # når JS-siden bekræfter success — ikke her.
      autoSaveAppState(session, save_data$data, save_data$metadata,
        app_state = app_state)
    }) |> bindEvent(
      {
        list(
          input$indicator_title,
          input$unit_type,
          input$unit_select,
          input$unit_custom,
          input$indicator_description,
          input$x_column,
          input$y_column,
          input$n_column,
          input$skift_column,
          input$frys_column,
          input$kommentar_column,
          input$chart_type,
          input$target_value,
          input$centerline_value,
          input$y_axis_unit
        )
      },
      ignoreInit = TRUE
    )
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

  # Diskret save-status indikator i wizard-bjælken (Issue #193)
  # Viser:
  #   - Intet hvis last_save_time er NULL (ingen save endnu)
  #   - "Gemt · N s siden" / "Gemt · N min siden" ved success
  #   - "Automatisk lagring deaktiveret" når auto_save_enabled er FALSE
  output$session_save_status <- shiny::renderUI({
    last_save <- app_state$session$last_save_time
    auto_save_on <- app_state$session$auto_save_enabled

    if (isFALSE(auto_save_on)) {
      return(shiny::span(
        shiny::icon("triangle-exclamation"),
        " Automatisk lagring deaktiveret",
        style = "color: #b33a3a; font-size: 0.8rem;",
        title = "Browseren har ikke plads til mere. Din data er stadig i appen."
      ))
    }

    if (is.null(last_save)) {
      return(NULL)
    }

    diff_sec <- as.numeric(difftime(Sys.time(), last_save, units = "secs"))
    label <- if (diff_sec < 60) {
      paste0("Gemt \u00b7 ", round(diff_sec), " s siden")
    } else if (diff_sec < 3600) {
      paste0("Gemt \u00b7 ", round(diff_sec / 60), " min siden")
    } else {
      "Gemt \u00b7 tidligere"
    }

    shiny::span(
      shiny::icon("check"),
      " ", label,
      style = "color: #6c757d; font-size: 0.8rem;",
      title = "Indstillinger og data gemmes automatisk i din browser"
    )
  })

  # JS → R feedback-kanal for localStorage save-result (Issue #193)
  # Lytter på result fra shiny-handlers.js saveAppState handler.
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

# HJÆLPEFUNKTIONER ============================================================

## Opret tom session data
# Opretter standarddatastruktur for nye sessioner
create_empty_session_data <- function() {
  data.frame(
    Skift = rep(FALSE, 20),
    Frys = rep(FALSE, 20),
    Dato = rep(NA_character_, 20),
    Tæller = rep(NA_real_, 20),
    Nævner = rep(NA_real_, 20),
    Kommentar = rep(NA_character_, 20),
    stringsAsFactors = FALSE
  )
}

# ensure_standard_columns funktionen er nu defineret i global.R

## Aktuel organisatorisk enhed
# Reaktiv funktion for nuværende organisatoriske enhed
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
        "paed" = "Pædiatrisk Afdeling",
        "gyn" = "Gynækologi/Obstetrik"
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
