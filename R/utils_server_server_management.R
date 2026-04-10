# server_session_management.R
# Server logik for session management inklusive auto-gendannelse og manuel gem/ryd

# Dependencies ----------------------------------------------------------------

# SESSION MANAGEMENT SETUP ====================================================

## Hovedfunktion for session management
# Opsætter al server logik relateret til session håndtering
setup_session_management <- function(input, output, session, app_state, emit, ui_service = NULL) {
  log_debug_block("SESSION_MGMT", "Initializing session management observers")

  # Check if centralized state is available
  use_centralized_state <- !is.null(app_state)
  # Log auto-restore feature flag ved session start (diagnostik)
  log_info(
    sprintf("auto_restore_data observer registered (auto_restore_enabled=%s)",
      isTRUE(get_auto_restore_enabled())),
    .context = "SESSION_RESTORE"
  )

  # Auto-gendan session data når tilgængelig (hvis aktiveret)
  shiny::observeEvent(input$auto_restore_data,
    {
      shiny::req(input$auto_restore_data)

      log_info(
        "auto_restore_data observer triggered",
        .context = "SESSION_RESTORE"
      )

      # Tjek om auto-gendannelse er aktiveret
      if (!get_auto_restore_enabled()) {
        log_info(
          "Auto-restore disabled via config - skipping restore",
          .context = "SESSION_RESTORE"
        )
        return()
      }

      safe_operation(
        "Auto restore session data",
        code = {
          saved_state <- input$auto_restore_data

          if (!is.null(saved_state$data)) {
            # Version-check: Ryd inkompatibel data og spring restore over
            saved_version <- saved_state$version %||% "unknown"
            if (!identical(saved_version, LOCAL_STORAGE_SCHEMA_VERSION)) {
              log_info(
                paste("Ryder inkompatibel localStorage session version:", saved_version),
                .context = "SESSION_RESTORE",
                details = list(
                  found_version = saved_version,
                  expected_version = LOCAL_STORAGE_SCHEMA_VERSION
                )
              )
              clearDataLocally(session)
              return(invisible(NULL))
            }

            # Sæt gendannelses guards for at forhindre interferens
            app_state$session$restoring_session <- TRUE
            app_state$data$updating_table <- TRUE
            app_state$data$table_operation_in_progress <- TRUE
            app_state$session$auto_save_enabled <- FALSE

            # Oprydningsfunktion til at nulstille guards
            on.exit(
              {
                app_state$data$updating_table <- FALSE
                app_state$session$restoring_session <- FALSE
                app_state$session$auto_save_enabled <- TRUE
                app_state$data$table_operation_cleanup_needed <- TRUE
              },
              add = TRUE
            )

            # Rekonstruer data.frame fra gemt struktur
            saved_data <- saved_state$data

            # K5 FIX: Bounds checking to prevent DoS via unbounded memory allocation
            max_rows <- 1e6 # 1 million rows max
            max_cols <- 1000 # 1000 columns max
            max_cells <- 1e7 # 10 million total cells max

            if (is.null(saved_data$values) || is.null(saved_data$nrows) ||
              is.null(saved_data$ncols)) {
              stop("Invalid saved data format - missing required fields")
            }

            # Validate dimensions before reconstruction
            if (!is.numeric(saved_data$nrows) || !is.numeric(saved_data$ncols) ||
              saved_data$nrows < 0 || saved_data$ncols < 0 ||
              saved_data$nrows > max_rows || saved_data$ncols > max_cols ||
              (saved_data$nrows * saved_data$ncols) > max_cells ||
              length(saved_data$values) != saved_data$ncols) {
              stop("Invalid data dimensions or structure - rejecting restoration payload")
            }

            # Reconstruct data.frame manually med class-preservation
            reconstructed_data <- data.frame(
              matrix(nrow = saved_data$nrows, ncol = saved_data$ncols),
              stringsAsFactors = FALSE
            )

            # Set column names first if available
            if (!is.null(saved_data$col_names)) {
              names(reconstructed_data) <- saved_data$col_names
            }

            # Populate columns med udvidet class-restoration
            for (i in seq_along(saved_data$values)) {
              col_name <- names(reconstructed_data)[i]
              raw_values <- saved_data$values[[i]]
              col_class_info <- if (!is.null(saved_data$class_info)) {
                saved_data$class_info[[col_name]]
              } else {
                NULL
              }

              reconstructed_data[[i]] <- restore_column_class(
                raw_values,
                class_info = col_class_info
              )
            }

            # Sæt data og completion flags FØR emit så downstream listeners
            # ser korrekt state (men metadata restore sker EFTER flush).
            set_current_data(app_state, reconstructed_data)
            app_state$data$original_data <- reconstructed_data
            app_state$session$file_uploaded <- TRUE
            app_state$columns$auto_detect$completed <- TRUE

            # CRITICAL: Metadata restore skal ske EFTER selectize choices er
            # populeret (sker i observer på data_updated). Vi bruger
            # session$onFlushed(once = TRUE) så update-kaldene kører efter
            # Shiny har flushed UI-opdateringer. Ellers peger
            # updateSelectizeInput(selected="Dato") på en tom choices-liste
            # og effekten er nul.
            if (!is.null(saved_state$metadata)) {
              saved_meta <- saved_state$metadata
              session$onFlushed(
                function() {
                  shiny::isolate({
                    log_info(
                      "Restoring metadata after UI flush",
                      .context = "SESSION_RESTORE"
                    )
                    restore_metadata(session, saved_meta, ui_service)

                    # Kopier mappings ind i centraliseret state så reactive
                    # chain ikke resetter dem ved næste render.
                    # NB: writes til reactiveValues kræver ikke reactive
                    # context, men reads gør — derfor isolate() wrapper.
                    for (field in c("x_column", "y_column", "n_column",
                      "skift_column", "frys_column", "kommentar_column")) {
                      val <- saved_meta[[field]]
                      if (!is.null(val) && nzchar(val)) {
                        app_state$columns$mappings[[field]] <- val
                      }
                    }
                  })
                },
                once = TRUE
              )
            }

            # Wizard-integration: Skip landing page og aktivér wizard-navigation.
            # Landing page har body class "wizard-nav-active" skjult som default,
            # hvilket skjuler navbar-trin. Vi skal eksplicit aktivere wizard-mode
            # efter restore så navbar-trin er synlige.
            session$sendCustomMessage("activate-wizard-mode", list())

            # Navigér til korrekt tab baseret på gemt active_tab.
            # Hvis active_tab er "start" (landing page), hop til "analyser" som
            # sensible default siden der er data. Ellers brug gemt tab.
            saved_tab <- saved_state$metadata$active_tab %||% "analyser"
            if (saved_tab == "start" || is.null(saved_tab) || saved_tab == "") {
              saved_tab <- "analyser"
            }

            # Unlock wizard-trin 2 og navigér (gør det synligt straks)
            session$sendCustomMessage("wizard-complete-step", 1)
            session$sendCustomMessage("wizard-unlock-step", 2)
            if (saved_tab == "eksporter") {
              session$sendCustomMessage("wizard-complete-step", 2)
              session$sendCustomMessage("wizard-unlock-step", 3)
            }
            bslib::nav_select("main_navbar", selected = saved_tab, session = session)

            # FINALLY emit event (listeners ser nu korrekt state)
            emit$data_updated(context = "session_restore")

            # Show notification about auto restore
            data_rows <- saved_data$nrows %||% nrow(reconstructed_data)

            shiny::showNotification(
              paste(
                "Tidligere session automatisk genindl\u00e6st:", data_rows,
                "datapunkter fra",
                format(as.POSIXct(saved_state$timestamp), "%d-%m-%Y %H:%M")
              ),
              type = "message",
              duration = 5
            )
          }
        },
        fallback = {
          # Reset guards even on error
          # Unified state assignment only
          app_state$data$updating_table <- FALSE
          # Unified state assignment only
          app_state$session$restoring_session <- FALSE
          # Unified state assignment only
          app_state$session$auto_save_enabled <- TRUE
          # Unified state assignment only
          app_state$data$table_operation_in_progress <- FALSE
        },
        session = session,
        error_type = "processing",
        show_user = TRUE,
        emit = emit,
        app_state = app_state
      )
    },
    once = TRUE
  )

  # Clear saved handler
  shiny::observeEvent(input$clear_saved, {
    handle_clear_saved_request(input, session, app_state, emit, ui_service)
  })

  # Confirm clear saved handler
  shiny::observeEvent(input$confirm_clear_saved, {
    handle_confirm_clear_saved(session, app_state, emit, ui_service)
  })

  # NOTE: output$dataLoaded is now handled in server_helpers.R with smart logic
  # NOTE: manual_save, show_upload_modal og save_status_display observers
  # blev fjernet i Issue #193 (OpenSpec add-session-persistence-autosave).
  # Auto-save hvert 2s gør manuel save-knap overflødig; status-display erstattes
  # af en diskret indikator i wizard-bjælken (se Fase 5).
}

# Helper functions for session management
restore_metadata <- function(session, metadata, ui_service = NULL) {
  shiny::isolate({
    if (!is.null(ui_service)) {
      # Use centralized UI service for metadata restoration
      ui_service$update_form_fields(metadata)
    } else {
      # Fallback to direct updates
      if (!is.null(metadata$chart_type)) {
        shiny::updateSelectizeInput(session, "chart_type", selected = metadata$chart_type)
      }
      # Kolonne-mappings (inkl. avancerede: skift, frys, kommentar)
      column_fields <- c(
        "x_column", "y_column", "n_column",
        "skift_column", "frys_column", "kommentar_column"
      )
      has_columns <- any(vapply(
        column_fields,
        function(f) !is.null(metadata[[f]]),
        logical(1)
      ))
      if (has_columns) {
        if (!is.null(ui_service)) {
          ui_service$update_form_fields(
            metadata = metadata,
            fields = column_fields
          )
        } else {
          for (f in column_fields) {
            if (!is.null(metadata[[f]])) {
              shiny::updateSelectizeInput(
                session, f,
                selected = metadata[[f]]
              )
            }
          }
        }
      }
      if (!is.null(metadata$target_value)) {
        shiny::updateTextInput(session, "target_value", value = metadata$target_value)
      }
      if (!is.null(metadata$centerline_value)) {
        shiny::updateTextInput(session, "centerline_value", value = metadata$centerline_value)
      }
      if (!is.null(metadata$y_axis_unit)) {
        shiny::updateSelectizeInput(session, "y_axis_unit", selected = metadata$y_axis_unit)
      }
      if (!is.null(metadata$indicator_title)) {
        shiny::updateTextInput(session, "indicator_title", value = metadata$indicator_title)
      }
      if (!is.null(metadata$indicator_description)) {
        shiny::updateTextAreaInput(session, "indicator_description", value = metadata$indicator_description)
      }
    }
  })
}

collect_metadata <- function(input) {
  shiny::isolate({
    list(
      x_column = if (is.null(input$x_column) || input$x_column == "") "" else input$x_column,
      y_column = if (is.null(input$y_column) || input$y_column == "") "" else input$y_column,
      n_column = if (is.null(input$n_column) || input$n_column == "") "" else input$n_column,
      skift_column = if (is.null(input$skift_column) || input$skift_column == "") "" else input$skift_column,
      frys_column = if (is.null(input$frys_column) || input$frys_column == "") "" else input$frys_column,
      kommentar_column = if (is.null(input$kommentar_column) || input$kommentar_column == "") "" else input$kommentar_column,
      chart_type = input$chart_type,
      target_value = input$target_value,
      centerline_value = input$centerline_value,
      y_axis_unit = if (is.null(input$y_axis_unit) || input$y_axis_unit == "") "count" else input$y_axis_unit,
      indicator_title = input$indicator_title,
      indicator_description = input$indicator_description,
      # Wizard navigation state (Issue #193)
      active_tab = input$main_navbar %||% "analyser"
    )
  })
}

handle_clear_saved_request <- function(input, session, app_state, emit, ui_service = NULL) {
  # Check if there's data or settings to lose - Use unified state
  current_data_check <- app_state$data$current_data
  has_data <- !is.null(current_data_check) &&
    any(!is.na(current_data_check), na.rm = TRUE) &&
    nrow(current_data_check) > 0

  has_settings <- !is.null(app_state$session$last_save_time)

  # If no data or settings, start new session directly
  if (!has_data && !has_settings) {
    reset_to_empty_session(session, app_state, emit, ui_service)
    shiny::showNotification("Ny session startet", type = "message", duration = 2)
    return()
  }

  # If there IS data or settings, show confirmation dialog
  show_clear_confirmation_modal(has_data, has_settings, app_state)
}

handle_confirm_clear_saved <- function(session, app_state, emit, ui_service = NULL) {
  reset_to_empty_session(session, app_state, emit, ui_service)
  shiny::updateTextAreaInput(session, "paste_data_input", value = "")
  shiny::removeModal()
  shiny::showNotification("Ny session startet - alt data og indstillinger nulstillet", type = "message", duration = 4)
}

reset_to_empty_session <- function(session, app_state, emit, ui_service = NULL) {
  # Unified state: App state is always available
  use_centralized_state <- !is.null(app_state)
  log_debug_kv(
    session_reset_started = TRUE,
    centralized_state_available = use_centralized_state,
    app_state_hash_before = if (!is.null(app_state)) digest::digest(app_state$data$current_data) else "NULL",
    .context = "SESSION_RESET"
  )
  clearDataLocally(session)
  # Unified state assignment only
  app_state$session$last_save_time <- NULL

  # Unified state only
  app_state$data$updating_table <- TRUE

  # Force hide Anhøj rules until real data is loaded
  # Unified state assignment only
  app_state$ui$hide_anhoej_rules <- TRUE

  # Reset to standard column order using helper function
  # Sync current_data to both old and new state management
  # Brug synlige standarddata (så tabel er synlig) men force name-only detection
  standard_data <- create_empty_session_data()

  # Unified state assignment only
  app_state$data$current_data <- standard_data
  # Emit consolidated event with context
  emit$data_updated(context = "new_session")

  # UNIFIED EVENTS: Trigger navigation change through event system
  emit$navigation_changed()

  # Unified state assignment only
  app_state$session$file_uploaded <- FALSE
  # Unified state assignment only
  app_state$session$user_started_session <- TRUE # NEW: Set flag that user has started
  # Unified state assignment only
  app_state$data$original_data <- NULL
  # Unified state assignment only
  app_state$columns$auto_detect$completed <- FALSE

  # Unified state: Get new standard session data
  new_data <- app_state$data$current_data

  # Reset UI inputs using centralized service
  shiny::isolate({
    if (!is.null(ui_service)) {
      # Use centralized UI service for all form resets
      ui_service$reset_form_fields()
    } else {
      # Fallback to direct updates
      shiny::updateSelectizeInput(session, "chart_type", selected = "run")
      shiny::updateSelectizeInput(session, "y_axis_unit", selected = "count")

      # Opdater kolonnevalg med nye standardkolonner fra empty session data
      if (!is.null(new_data) && ncol(new_data) > 0) {
        new_col_names <- names(new_data)
        col_choices <- setNames(new_col_names, new_col_names)
        col_choices <- c("Vælg kolonne" = "", col_choices)

        ui_service$update_all_columns(
          choices = col_choices,
          selected = list()
        )
      } else {
        ui_service$update_all_columns(
          choices = c("Vælg kolonne" = ""),
          selected = list()
        )
      }

      shiny::updateTextInput(session, "target_value", value = "")
      shiny::updateTextInput(session, "centerline_value", value = "")
    }

    shinyjs::reset("data_file")
  })

  # Force name-only detection på de nye standardkolonner efter UI opdatering
  if (!is.null(new_data) && ncol(new_data) > 0) {
    log_debug_kv(
      new_data_dimensions = paste(dim(new_data), collapse = "x"),
      new_data_columns = paste(names(new_data), collapse = ", "),
      .context = "SESSION_RESET"
    )

    # Kald den unified autodetect_engine for session reset
    # Dette sikrer konsistent event-logik og unified state management
    autodetect_result <- autodetect_engine(
      data = new_data,
      trigger_type = "session_start", # Session reset behandles som ny session start
      app_state = app_state,
      emit = emit
    )
  }

  # Unified state only
  app_state$data$updating_table <- FALSE
}

show_clear_confirmation_modal <- function(has_data, has_settings, app_state) {
  shiny::showModal(shiny::modalDialog(
    title = "Start ny session?",
    size = "m",
    shiny::div(
      shiny::icon("refresh"),
      " Er du sikker på at du vil starte en helt ny session?",
      shiny::br(), shiny::br(),
      shiny::p("Dette vil:"),
      shiny::tags$ul(
        if (has_data) shiny::tags$li("Slette eksisterende data i tabellen"),
        if (has_settings) shiny::tags$li("Nulstille titel, beskrivelse og andre indstillinger"),
        # Unified state: Check centralized state for last save time
        if (!is.null(app_state$session$last_save_time)) shiny::tags$li("Fjerne gemt session fra lokal storage"),
        shiny::tags$li("Oprette en tom standardtabel")
      ),
      shiny::br(),
      shiny::p("Denne handling kan ikke fortrydes.")
    ),
    footer = shiny::tagList(
      shiny::modalButton("Annuller"),
      shiny::actionButton("confirm_clear_saved", "Ja, start ny session", class = "btn-warning")
    ),
    easyClose = FALSE
  ))
}
