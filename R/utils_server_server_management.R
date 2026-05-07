# server_session_management.R
# Server logik for session management inklusive auto-gendannelse og manuel gem/ryd

# Dependencies ----------------------------------------------------------------

# SESSION MANAGEMENT SETUP ====================================================

## Hovedfunktion for session management
# Opsaetter al server logik relateret til session haandtering
setup_session_management <- function(input, output, session, app_state, emit, ui_service = NULL) {
  log_debug_block("SESSION_MGMT", "Initializing session management observers")

  # Check if centralized state is available
  use_centralized_state <- !is.null(app_state)
  # Log auto-restore feature flag ved session start (diagnostik)
  log_info(
    sprintf(
      "auto_restore_data observer registered (auto_restore_enabled=%s)",
      isTRUE(get_auto_restore_enabled())
    ),
    .context = "SESSION_RESTORE"
  )

  # Peek-observer: modtager metadata-subset fra JS ved session-init.
  # Saetter app_state$session$peek_result saa landing-modulet kan vise
  # restore-card eller default-landing. Ingen aendring af auto_restore_data
  # observer -- den trigges nu via performSessionRestore custom message.
  shiny::observeEvent(input$session_peek,
    ignoreNULL = TRUE,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      peek <- input$session_peek

      # has_payload = FALSE (eller mangler) -> default landing
      if (!isTRUE(peek$has_payload)) {
        log_info("session_peek: ingen gemt session", .context = "SESSION_RESTORE")
        set_session_peek_result(app_state, list(has_payload = FALSE))
        return()
      }

      # Feature flag off -> ryd lydloest og vis default landing
      if (!get_auto_restore_enabled()) {
        log_info(
          "session_peek: auto_restore deaktiveret \u2014 ryder localStorage",
          .context = "SESSION_RESTORE"
        )
        clearDataLocally(session)
        session$sendCustomMessage("discardPendingRestore", list())
        set_session_peek_result(app_state, list(has_payload = FALSE))
        return()
      }

      # Silent forward-migration 2.0 -> 3.0 (time -> time_minutes)
      peek <- migrate_time_yaxis_unit(peek)

      # Schema version-check -> ryd lydloest og vis default landing
      saved_version <- peek$version %||% "unknown"
      if (!identical(saved_version, LOCAL_STORAGE_SCHEMA_VERSION)) {
        log_info(
          paste(
            "session_peek: version mismatch", saved_version, "\u2260", LOCAL_STORAGE_SCHEMA_VERSION,
            "\u2014 ryder localStorage lydl\u00f8st"
          ),
          .context = "SESSION_RESTORE"
        )
        clearDataLocally(session)
        session$sendCustomMessage("discardPendingRestore", list())
        set_session_peek_result(app_state, list(has_payload = FALSE))
        return()
      }

      # Gyldig peek -- gem metadata til landing-modulet
      log_info(
        "session_peek: gyldig gemt session fundet \u2014 afventer brugervalg",
        .context = "SESSION_RESTORE",
        details = list(
          nrows = peek$nrows,
          ncols = peek$ncols,
          active_tab = peek$active_tab
        )
      )
      set_session_peek_result(app_state, list(
        has_payload = TRUE,
        timestamp = peek$timestamp,
        nrows = peek$nrows,
        ncols = peek$ncols,
        indicator_title = peek$indicator_title %||% "",
        active_tab = peek$active_tab
      ))
    }
  )

  # Auto-gendan session data naar tilgaengelig (hvis aktiveret)
  shiny::observeEvent(input$auto_restore_data,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
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

          # Silent forward-migration 2.0 -> 3.0 (time -> time_minutes)
          saved_state <- migrate_time_yaxis_unit(saved_state)

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

            # Saet gendannelses guards for at forhindre interferens
            set_session_restoring(app_state, TRUE)
            set_table_updating(app_state, TRUE)
            set_table_op_in_progress(app_state, TRUE)
            app_state$session$auto_save_enabled <- FALSE

            # Oprydningsfunktion til at nulstille guards.
            # VIGTIGT: restoring_session skal IKKE nulstilles her.
            # wizard_gates-observeren paa data_updated fyrer i NAeSTE flush,
            # og vi skal bevare restoring_session = TRUE saa den skipper
            # auto-nav til "analyser". Cleanup af restoring_session sker
            # i session$onFlushed nedenfor.
            on.exit(
              {
                set_table_updating(app_state, FALSE)
                # auto_save_enabled genaktiveres i session$onFlushed() nedenfor
                # for at undgaa at stale input$main_navbar overskriver active_tab
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
              matrix(nrow = saved_data$nrows, ncol = saved_data$ncols)
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

            # Saet data og completion flags FOeR emit saa downstream listeners
            # ser korrekt state (men metadata restore sker EFTER flush).
            set_current_data(app_state, reconstructed_data)
            app_state$data$original_data <- reconstructed_data
            app_state$session$file_uploaded <- TRUE
            app_state$columns$auto_detect$completed <- TRUE

            # FUND #1: Skriv kolonne-mappings til centraliseret state FOeR
            # emit, saa listeners paa data_updated (priority HIGH) ser korrekt
            # mapping-state i foerste iteration. Selve selectize-selected
            # opdateringen sker stadig i onFlushed nedenfor, fordi choices
            # skal vaere populeret foerst.
            if (!is.null(saved_state$metadata)) {
              saved_meta <- saved_state$metadata
              for (field in c(
                "x_column", "y_column", "n_column",
                "skift_column", "frys_column", "kommentar_column"
              )) {
                val <- saved_meta[[field]]
                if (!is.null(val) && nzchar(val)) {
                  app_state$columns$mappings[[field]] <- val
                }
              }

              # FIX #393: Skriv chart_type til mappings FoER emit$data_updated()
              # saa column_config-reaktiven kan bruge den korrekte chart_type under
              # session-restore. chart_type-observeren springer over under
              # restoring_session (guard i utils_server_events_chart.R), saa
              # vi maa skrive til mappings eksplicit her.
              # get_qic_chart_type() konverterer baade danske labels og
              # engelske koder til kanonisk qic-kode (fx "run", "p", "i").
              if (!is.null(saved_meta$chart_type) && nzchar(saved_meta$chart_type)) {
                app_state$columns$mappings$chart_type <- get_qic_chart_type(saved_meta$chart_type)
              }

              # CRITICAL: Metadata restore skal ske EFTER selectize choices
              # er populeret (sker i observer paa data_updated). Vi bruger
              # session$onFlushed(once = TRUE) saa update-kaldene koerer efter
              # Shiny har flushed UI-opdateringer. Ellers peger
              # updateSelectizeInput(selected="Dato") paa en tom choices-liste
              # og effekten er nul.
              session$onFlushed(
                function() {
                  shiny::isolate({
                    log_debug(
                      "Restoring metadata after UI flush",
                      .context = "SESSION_RESTORE"
                    )
                    restore_metadata(session, saved_meta, ui_service)
                  })
                },
                once = TRUE
              )
            }

            # Wizard-integration: Skip landing page og aktiver wizard-navigation.
            # Landing page har body class "wizard-nav-active" skjult som default,
            # hvilket skjuler navbar-trin. Vi skal eksplicit aktivere wizard-mode
            # efter restore saa navbar-trin er synlige.
            session$sendCustomMessage("activate-wizard-mode", list())

            # Naviger til korrekt tab baseret paa gemt active_tab.
            # Valider: kun kendte string-tab-navne accepteres.
            # Numeriske vaerdier (fx 36 = nrows fra korrupt metadata) afvises
            # -> fallback til "analyser" saa plot vises med det samme.
            valid_restore_tabs <- c("analyser", "eksporter", "upload")
            saved_tab_raw <- saved_state$metadata$active_tab
            saved_tab <- if (
              is.character(saved_tab_raw) &&
                length(saved_tab_raw) == 1 &&
                saved_tab_raw %in% valid_restore_tabs
            ) {
              saved_tab_raw
            } else {
              "analyser"
            }

            # Unlock wizard-trin 2 og naviger (goer det synligt straks)
            session$sendCustomMessage("wizard-complete-step", 1)
            session$sendCustomMessage("wizard-unlock-step", 2)
            if (saved_tab == "eksporter") {
              session$sendCustomMessage("wizard-complete-step", 2)
              session$sendCustomMessage("wizard-unlock-step", 3)
            }
            bslib::nav_select("main_navbar", selected = saved_tab, session = session)

            # FINALLY emit event (listeners ser nu korrekt state)
            emit$data_updated(context = "session_restore")

            # Cleanup restoring_session flag AFTER alle data_updated-listeners
            # har koert. wizard_gates-observeren paa data_updated fyrer i naeste
            # flush og maa se restoring_session = TRUE saa den skipper auto-nav
            # til "analyser". onFlushed(once=TRUE) koerer efter flush er done.
            session$onFlushed(
              function() {
                shiny::isolate({
                  set_session_restoring(app_state, FALSE)
                  app_state$session$auto_save_enabled <- TRUE
                  log_info(
                    "restoring_session flag cleared and auto_save re-enabled after flush",
                    .context = "SESSION_RESTORE"
                  )
                })
              },
              once = TRUE
            )

            # Show notification about auto restore
            data_rows <- saved_data$nrows %||% nrow(reconstructed_data)

            shiny::showNotification(
              paste(
                "Session genoprettet:", data_rows,
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
          set_table_updating(app_state, FALSE)
          # Unified state assignment only
          set_session_restoring(app_state, FALSE)
          # Unified state assignment only
          app_state$session$auto_save_enabled <- TRUE
          # Unified state assignment only
          set_table_op_in_progress(app_state, FALSE)
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

  # Clear saved handler — STATUS_UPDATES (åbner confirm-modal).
  shiny::observeEvent(input$clear_saved,
    priority = OBSERVER_PRIORITIES$STATUS_UPDATES,
    {
      handle_clear_saved_request(input, session, app_state, emit, ui_service)
    }
  )

  # Confirm clear saved handler — STATE_MANAGEMENT (rydder localStorage + state).
  shiny::observeEvent(input$confirm_clear_saved,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      handle_confirm_clear_saved(session, app_state, emit, ui_service)
    }
  )

  # NOTE: output$dataLoaded is now handled in server_helpers.R with smart logic
  # NOTE: manual_save, show_upload_modal og save_status_display observers
  # blev fjernet i Issue #193 (OpenSpec add-session-persistence-autosave).
  # Auto-save hvert 2s goer manuel save-knap overfloedig; status-display erstattes
  # af en diskret indikator i wizard-bjaelken (se Fase 5).
}

# Helper functions for session management
restore_metadata <- function(session, metadata, ui_service = NULL) {
  shiny::isolate({
    # Diagnostisk: log hvilke felter der faktisk er gemt
    present_fields <- names(metadata)[
      vapply(metadata, function(v) !is.null(v) && !identical(v, ""), logical(1))
    ]
    log_info(
      sprintf(
        "restore_metadata called with %d non-empty fields: %s",
        length(present_fields), paste(present_fields, collapse = ", ")
      ),
      .context = "SESSION_RESTORE"
    )

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

    # Naviger til gemt tab (eller "analyser" som fallback)
    # Samme validerede tab-liste som auto-restore observer (linje 247)
    valid_restore_tabs <- c("analyser", "eksporter", "upload")
    active_tab <- metadata$active_tab
    if (!is.null(active_tab) && nzchar(active_tab) &&
      active_tab %in% valid_restore_tabs) {
      bslib::nav_select("main_navbar", selected = active_tab, session = session)
    } else {
      bslib::nav_select("main_navbar", selected = "analyser", session = session)
    }
  })
}

collect_metadata <- function(input, app_state = NULL) {
  shiny::isolate({
    scalar_text <- function(value, default = "") {
      value <- sanitize_selection(value)
      if (is.null(value)) {
        return(default)
      }
      as.character(value[[1]])
    }

    # Hjaelper: prefer input, fallback til app_state$columns$mappings naar input
    # er NULL eller "". Dette undgaar race condition under session restore hvor
    # updateSelectizeInput round-trip ikke er faerdig, og vi ellers ville
    # overskrive localStorage med tomme kolonner.
    col_val <- function(input_key, mapping_key = input_key) {
      v <- scalar_text(input[[input_key]], default = "")
      if (nzchar(v)) {
        return(v)
      }
      if (!is.null(app_state)) {
        m <- scalar_text(app_state$columns$mappings[[mapping_key]], default = "")
        if (nzchar(m)) {
          return(m)
        }
      }
      ""
    }

    list(
      # Trin 2 (Analyser) -- kolonne-mapping og chart-indstillinger
      x_column = col_val("x_column"),
      y_column = col_val("y_column"),
      n_column = col_val("n_column"),
      skift_column = col_val("skift_column"),
      frys_column = col_val("frys_column"),
      kommentar_column = col_val("kommentar_column"),
      chart_type = scalar_text(input$chart_type, default = "run"),
      # NULL-safe: jsonlite::toJSON dropper list-elementer med NULL, saa vi
      # falder tilbage til "" for at sikre roundtrip ved tomme felter.
      target_value = scalar_text(input$target_value),
      centerline_value = scalar_text(input$centerline_value),
      y_axis_unit = scalar_text(input$y_axis_unit, default = "count"),
      # Unit-type system (select/custom) og tilhoerende vaerdier.
      # Disse triggerer autosave og opdateres i update_form_fields(),
      # saa de skal ogsaa gemmes i metadata for korrekt roundtrip.
      # NULL-safe: jsonlite::toJSON serialiserer NULL som {} (tomt object)
      # selvom auto_unbox = TRUE, hvilket giver uforudsigelig decoding i JS.
      # Fallback til "" sikrer korrekt roundtrip.
      unit_type = scalar_text(input$unit_type),
      unit_select = scalar_text(input$unit_select),
      unit_custom = scalar_text(input$unit_custom),
      indicator_title = scalar_text(input$indicator_title),
      indicator_description = scalar_text(input$indicator_description),

      # Trin 3 (Eksporter) -- export-modulets felter (namespaced med "export-")
      # NULL-safe: ellers dropper jsonlite::toJSON elementerne naar modulet
      # endnu ikke er renderet (inputs = NULL foer foerste visning af trin 3).
      export_title = scalar_text(input[["export-export_title"]]),
      export_hospital = scalar_text(input[["export-export_hospital"]]),
      export_department = scalar_text(input[["export-export_department"]]),
      export_footnote = scalar_text(input[["export-export_footnote"]]),
      export_format = scalar_text(input[["export-export_format"]]),
      pdf_description = scalar_text(input[["export-pdf_description"]]),
      pdf_improvement = scalar_text(input[["export-pdf_improvement"]]),
      png_width = scalar_text(input[["export-png_width"]]),
      png_height = scalar_text(input[["export-png_height"]]),

      # Wizard navigation state (Issue #193)
      # Valider: kun kendte string-vaerdier gemmes for at undgaa at nrows (36)
      # eller andre numeriske vaerdier sniger sig ind via reactive edge cases.
      active_tab = {
        tab <- scalar_text(input$main_navbar, default = "analyser")
        valid_nav_tabs <- c("analyser", "eksporter", "upload", "start")
        if (is.character(tab) && length(tab) == 1 && tab %in% valid_nav_tabs) tab else "analyser"
      }
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
  app_state$session$pending_excel_upload <- NULL

  # Unified state only
  set_table_updating(app_state, TRUE)

  # Force hide Anhoej rules until real data is loaded
  # Unified state assignment only
  app_state$ui$hide_anhoej_rules <- TRUE

  # Reset to standard column order using helper function
  # Sync current_data to both old and new state management
  # Brug synlige standarddata (saa tabel er synlig) men force name-only detection
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
        col_choices <- c("V\u00e6lg kolonne" = "", col_choices)

        for (column_input in c(
          "x_column", "y_column", "n_column",
          "skift_column", "frys_column", "kommentar_column"
        )) {
          shiny::updateSelectizeInput(
            session,
            column_input,
            choices = col_choices,
            selected = ""
          )
        }
      } else {
        for (column_input in c(
          "x_column", "y_column", "n_column",
          "skift_column", "frys_column", "kommentar_column"
        )) {
          shiny::updateSelectizeInput(
            session,
            column_input,
            choices = c("V\u00e6lg kolonne" = ""),
            selected = ""
          )
        }
      }

      shiny::updateTextInput(session, "target_value", value = "")
      shiny::updateTextInput(session, "centerline_value", value = "")
    }

    shinyjs::reset("direct_file_upload")
  })

  # Force name-only detection paa de nye standardkolonner efter UI opdatering
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
  set_table_updating(app_state, FALSE)
}

show_clear_confirmation_modal <- function(has_data, has_settings, app_state) {
  shiny::showModal(shiny::modalDialog(
    title = "Start ny session?",
    size = "m",
    shiny::div(
      shiny::icon("refresh"),
      " Er du sikker p\u00e5 at du vil starte en helt ny session?",
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
