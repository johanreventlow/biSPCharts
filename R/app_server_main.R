# app_server.R
# Main server function following Golem conventions

#' Hash session token for secure logging
#'
#' SECURITY: Uses SHA256 (not SHA1) for stronger cryptographic hashing.
#' Returns first 8 characters of the hash for logging identification while
#' preventing session hijacking if logs are compromised.
#'
#' @param token Session token to hash
#' @return First 8 characters of SHA256 hash for logging identification
hash_session_token <- function(token) {
  if (is.null(token) || !is.character(token)) {
    return("unknown")
  }
  # SECURITY: Use SHA256 (upgraded from SHA1) for stronger hashing
  substr(digest::digest(token, algo = "sha256"), 1, 8)
}

#' Main Server Function
#'
#' @param input,output,session Internal Shiny parameters
#'
#' @keywords internal
main_app_server <- function(input, output, session) {
  # Get session token and hash it for secure logging
  session_token <- session$token %||% paste0("session_", Sys.time(), "_", sample(1000:9999, 1))
  hashed_token <- hash_session_token(session_token)

  # Log server initialization (standardiseret til log_debug)
  log_debug(
    paste("SPC App server initialization started - Session ID:", hashed_token),
    .context = "APP_SERVER"
  )

  # Initialize advanced debug system (kun i debug_mode_enabled).
  # get_golem_config() læser inst/golem-config.yml; tryCatch→FALSE hvis nøgle mangler.
  # Matcher mønster i utils_lazy_loading.R (advanced_debug condition).
  debug_mode_on <- isTRUE(tryCatch(
    golem::get_golem_options("debug_mode_enabled"),
    error = function(e) FALSE
  )) || isTRUE(safe_getenv("SPC_DEBUG_MODE", FALSE, "logical"))
  if (debug_mode_on) {
    initialize_advanced_debug(enable_history = TRUE, max_history_entries = 1000)
  }

  # Start session lifecycle debugging (using hashed token)
  session_debugger <- debug_session_lifecycle(hashed_token, session)
  session_debugger$event("server_initialization")

  # SPRINT 1 REFACTORING: Initialize app infrastructure (extracted to helper)
  infrastructure <- initialize_app_infrastructure(session, hashed_token, session_debugger)
  app_state <- infrastructure$app_state
  emit <- infrastructure$emit
  ui_service <- infrastructure$ui_service

  # FASE 5: Memory management setup
  log_debug("Setting up memory management...", .context = "APP_SERVER")
  setup_session_cleanup(session, app_state)
  log_debug("Memory management configured", .context = "APP_SERVER")

  # SPRINT 1 REFACTORING: Setup background tasks (extracted to helper)
  setup_background_tasks(session, app_state, emit)

  # Test Tilstand ------------------------------------------------------------
  # TEST MODE: Auto-indlaes eksempel data hvis aktiveret
  test_mode_auto_load <- get_test_mode_auto_load()

  log_debug(
    paste("TEST_MODE configuration:", test_mode_auto_load),
    .context = "SESSION_LIFECYCLE"
  )

  if (test_mode_auto_load) {
    # Phase 3: Initialize test mode optimization settings
    claudespc_env <- get_claudespc_environment()
    app_state$test_mode$debounce_delay <- claudespc_env$TEST_MODE_STARTUP_DEBOUNCE_MS %||% 500
    app_state$test_mode$lazy_plot_generation <- claudespc_env$TEST_MODE_LAZY_PLOT_GENERATION %||% TRUE
    app_state$test_mode$autoload_completed <- FALSE

    # Phase 4: Memory tracking (now handled by setup_background_tasks)
    # Note: track_memory_usage() moved to profiling utilities with session parameter

    log_debug_kv(
      message = "Test mode optimization configured",
      debounce_delay = shiny::isolate(app_state$test_mode$debounce_delay),
      lazy_plot_generation = shiny::isolate(app_state$test_mode$lazy_plot_generation),
      .context = "[TEST_MODE_STARTUP]"
    )

    test_file_path <- get_test_mode_file_path()

    session$onFlushed(function() {
      if (isTRUE(shiny::isolate(app_state$test_mode$autoload_completed))) {
        log_debug_kv(
          message = "Skipping duplicate test data autoload",
          session_id = hashed_token,
          .context = "[TEST_MODE_STARTUP]"
        )
        return(invisible(NULL))
      }

      shiny::isolate(app_state$test_mode$autoload_completed <- TRUE)

      # Start workflow tracer for auto-load process
      autoload_tracer <- debug_workflow_tracer("test_mode_auto_load", app_state, hashed_token)

      if (!is.null(test_file_path) && file.exists(test_file_path)) {
        autoload_tracer$step("file_validation_complete")

        safe_operation(
          "Test mode auto-load data",
          code = {
            autoload_tracer$step("data_loading_started")
            log_debug_kv(
              message = "Starting test data autoload after UI flush",
              session_id = hashed_token,
              file = test_file_path,
              .context = "[TEST_MODE_STARTUP]"
            )

            # Bestem hvilken loader der skal bruges baseret paa fil-extension
            file_extension <- tools::file_ext(test_file_path)

            if (file_extension %in% c("xlsx", "xls")) {
              # Load Excel file
              test_data <- readxl::read_excel(
                test_file_path,
                sheet = 1, # Laes foerste sheet
                .name_repair = "minimal"
              )
            } else {
              # Load CSV file using readr::read_csv2 (same as working file upload)
              test_data <- readr::read_csv2(
                test_file_path,
                locale = readr::locale(
                  decimal_mark = ",",
                  grouping_mark = ".",
                  encoding = DEFAULT_ENCODING
                ),
                show_col_types = FALSE
              )
            }

            # Ensure standard columns are present
            test_data <- ensure_standard_columns(test_data)
            autoload_tracer$step("data_processing_complete")

            # Set reactive values using dual-state sync
            app_state$data$original_data <- test_data
            # Unified state: Set data using sync helper for compatibility
            set_current_data(app_state, test_data)

            # Emit event to trigger downstream effects
            emit$data_updated("test_data_loaded")
            # Set session flags
            app_state$session$file_uploaded <- TRUE
            app_state$session$user_started_session <- TRUE
            # Reset auto-detection state
            shiny::isolate(app_state$columns$auto_detect$completed <- FALSE)
            # Legacy assignments removed - managed by unified state
            app_state$ui$hide_anhoej_rules <- FALSE

            autoload_tracer$step("state_synchronization_complete")

            # Take state snapshot after auto-load
            debug_state_snapshot("after_test_data_autoload", app_state, session_id = hashed_token)

            # NOTE: Flag saettes efter setup_column_management() for at undgaa race condition

            # Debug output
            log_info(paste("Auto-indl\u00e6st fil:", test_file_path), .context = "TEST_MODE")
            log_info(paste("Data dimensioner:", nrow(test_data), "x", ncol(test_data)), .context = "TEST_MODE")
            log_info(paste("Kolonner:", paste(names(test_data), collapse = ", ")), .context = "TEST_MODE")

            autoload_tracer$step("test_data_autoload_complete")
          },
          fallback = function(e) {
            log_error(paste("Fejl ved indl\u00e6sning af", test_file_path, ":", e$message), .context = "TEST_MODE")
          },
          error_type = "processing"
        )
      } else {
        log_warn(paste("Fil ikke fundet:", test_file_path), .context = "TEST_MODE")
      }

      invisible(NULL)
    }, once = TRUE)
  }


  # Observer Management ------------------------------------------------------
  # Initialiser observer manager til tracking af alle observers
  obs_manager <- observer_manager()


  # Server Setup ------------------------------------------------------------
  # Opsaet alle server-komponenter

  ## Session management logik
  setup_session_management(input, output, session, app_state, emit, ui_service)

  ## Idle session timeout (laest fra security.session_timeout_minutes i golem-config)
  activate_session_timeout_from_config(input, session)

  ## Fil upload logik
  setup_file_upload(input, output, session, app_state, emit, ui_service)

  ## Data tabel logik
  setup_data_table(input, output, session, app_state, emit)

  ## Hjaelpe observers (IMPORTANT: Must be set up before visualization for unified navigation)
  setup_helper_observers(input, output, session, obs_manager, app_state)

  ## Kolonne management logik
  # Pass centralized state to column management via unified event system
  setup_column_management(input, output, session, app_state, emit)

  ## Visualiserings logik
  visualization <- setup_visualization(input, output, session, app_state)

  ## Eksport modul logik
  # Pass app_state (read-only) to export module for chart access
  export_module_status <- mod_export_server("export", app_state, parent_session = session)

  ## Track forrige tab for kontekstuel tilbagenavigation paa hjaelpesider
  current_tab <- shiny::reactiveVal("start")
  previous_tab <- shiny::reactiveVal("start")
  # Issue #536: Konsolideret main_navbar-observer.
  # Tidligere fandtes en duplikeret observer i utils_server_event_listeners.R
  # som emittede navigation_changed. Vi konsoliderer her med STATE_MANAGEMENT-
  # priority for at garantere active_tab er sat FØR navigation_changed-listeners
  # (STATUS_UPDATES = 500) afvikles. Atomisk: state-write → emit.
  shiny::observeEvent(input$main_navbar,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      new_tab <- input$main_navbar
      old_tab <- current_tab()
      help_tabs <- c("app_guide", "hjaelp")
      if (new_tab %in% help_tabs) {
        previous_tab(old_tab)
      }
      current_tab(new_tab)
      # Opdater app_state saa eksport-observere kan gate paa aktiv tab (Issue #394)
      app_state$session$active_tab <- new_tab
      emit$navigation_changed()
    }
  )

  ## App-vejledning modul (tilbagenavigation til forrige tab)
  mod_app_guide_server("app_guide", parent_session = session, previous_tab = previous_tab)

  ## Hjaelpeside modul (tilbagenavigation til forrige tab)
  mod_help_server("help", parent_session = session, previous_tab = previous_tab)

  ## Landing page modul
  mod_landing_server("landing", parent_session = session, app_state = app_state)

  # Wizard-trin skjules ved start via wizard-nav.js (shiny:connected handler)
  # Logo-klik haandteres ogsaa i wizard-nav.js (se logo_home_link handler)

  session_debugger$event("server_setup_complete")
  log_debug("All server components setup completed", .context = "SESSION_LIFECYCLE")

  # FASE 3: Emit session_started event for name-only detection.
  # reactive(TRUE) + once = TRUE + ignoreInit = FALSE er bevidst:
  # observer skal køre én gang straks ved session-start (init-trigger-pattern).
  shiny::observeEvent(shiny::reactive(TRUE),
    {
      emit$session_started()
    },
    once = TRUE,
    ignoreInit = FALSE
  )

  # TEST MODE: Emit test_mode_ready event AFTER all observers are set up
  if (test_mode_auto_load) {
    shiny::observe({
      # Unified state: Use centralized state as primary data source
      current_data_check <- app_state$data$current_data

      if (!is.null(current_data_check)) {
        emit$test_mode_ready()
      }
    }) |> bindEvent(
      {
        # Unified state: Use centralized state for reactive triggers
        app_state$data$current_data
      },
      once = TRUE,
      ignoreNULL = TRUE
    )
  }

  # Initial UI Setup --------------------------------------------------------
  # Saet standard chart_type naar appen starter
  shiny::observe({
    shiny::updateSelectizeInput(session, "chart_type", selected = "run")
  }) |> bindEvent(TRUE, once = TRUE)

  # Session Cleanup ---------------------------------------------------------
  # Additional cleanup naar session lukker
  session$onSessionEnded(function() {
    session_debugger$event("session_cleanup_started")
    log_debug("Session cleanup initiated", .context = "SESSION_LIFECYCLE")

    # Stop background tasks immediately
    if (!is.null(app_state$infrastructure)) {
      app_state$infrastructure$session_active <- FALSE
      app_state$infrastructure$background_tasks_active <- FALSE
    }
    if (!is.null(app_state$session)) {
      app_state$session$cleanup_initiated <- TRUE
    }

    # Cleanup alle observers
    obs_manager$cleanup_all()

    # LOOP PROTECTION CLEANUP: Ensure all flags are cleared and no dangling callbacks
    safe_operation(
      "Clear loop protection flags during session cleanup",
      code = {
        if (!is.null(app_state$ui)) {
          set_ui_updating(app_state, FALSE)
          app_state$ui$flag_reset_scheduled <- TRUE
        }
      },
      fallback = function(e) {
        log_error(paste("Session cleanup: Could not clear loop protection flags:", e$message), .context = "SESSION_CLEANUP")
      },
      error_type = "processing"
    )


    # Complete session lifecycle debugging
    session_lifecycle_result <- session_debugger$complete()

    # Log session statistics
    log_info(paste("Session ended - Observer count:", obs_manager$count()), .context = "APP_SERVER")
    log_debug(
      paste("Session ended - duration:", round(session_lifecycle_result$total_duration, 3), "s"),
      .context = "SESSION_LIFECYCLE"
    )
  })
}
