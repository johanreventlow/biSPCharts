# utils_shinylogs_config.R
# Advanced web-based logging configuration using shinylogs package

# SHINYLOGS CONFIGURATION ==================================================

#' Setup Advanced Web Logging with shinylogs
#'
#' Konfigurerer shinylogs til avanceret web-baseret logging og monitoring
#' af Shiny applikationen. Integrerer med eksisterende logging system.
#'
#' @param enable_tracking Aktiver automatisk tracking af brugerinteraktioner
#' @param enable_errors Aktiver fejl-tracking og rapportering
#' @param enable_performances Aktiver performance monitoring
#' @param log_directory Directory til log filer (default: "logs/")
#'
#' @details
#' shinylogs giver foelgende funktionaliteter:
#' - Real-time web-baseret log viewer
#' - Automatisk tracking af inputs, outputs og fejl
#' - Performance metrics og timing
#' - Session management og brugerstatistikker
#' - Export af logs til forskellige formater
#'
setup_shinylogs <- function(enable_tracking = TRUE,
                            enable_errors = TRUE,
                            enable_performances = TRUE,
                            log_directory = "logs/") {
  # log_info will be available when this is called from app_server

  # Ensure log directory exists
  if (!dir.exists(log_directory)) {
    dir.create(log_directory, recursive = TRUE)
    # Directory created
  }

  # Configure shinylogs options
  options(
    # Basic shinylogs configuration
    shinylogs.save_inputs = enable_tracking,
    shinylogs.save_outputs = enable_tracking,
    shinylogs.save_errors = enable_errors,
    shinylogs.save_performances = enable_performances,

    # Storage configuration
    shinylogs.storage_mode = "file", # Can be "file" or "database"
    shinylogs.log_dir = log_directory,

    # Performance thresholds
    shinylogs.performance_threshold = 0.5, # 500ms threshold for slow operations

    # Additional tracking
    shinylogs.max_entries = 10000, # Maximum log entries to keep
    shinylogs.compress = TRUE # Compress old log files
  )

  # Configuration completed - logging will be available when called from app_server

  return(invisible(TRUE))
}

#' Initialize shinylogs tracking for app
#'
#' Starter shinylogs tracking naar applikationen initialiseres.
#' Skal kaldes i app_server funktionen.
#'
#' @param session Shiny session object
#' @param custom_fields List med custom felter til logging
#' @param app_name Navn paa applikationen (default: "SPC_APP")
#'
#' @noRd
initialize_shinylogs_tracking <- function(session,
                                          app_name = "SPC_APP",
                                          log_directory = "logs/") {
  if (!requireNamespace("shinylogs", quietly = TRUE)) {
    log_warn("shinylogs ikke installeret \u2014 analytics tracking deaktiveret", .context = "ANALYTICS")
    return(invisible(FALSE))
  }

  # Initializing shinylogs tracking

  # Start tracking with correct API
  # Filtrerer stoej fra: excelR tabeldata, interne session-inputs,
  # Shiny clientdata, og analytics-egne inputs
  shinylogs::track_usage(
    storage_mode = shinylogs::store_json(path = log_directory),
    what = c("session", "input", "output", "error"),
    exclude_input_id = c(
      "main_data_table", # excelR tabeldata (stor payload, hyppige updates)
      "auto_restore_data", # Session restore payload (kan vaere stor)
      "loaded_app_state", # localStorage payload
      "session_peek", # Session metadata peek
      "local_storage_save_result", # Save result callback
      "paste_data_input" # Indsæt-data felt: kan indeholde CPR, navne, PHI
    ),
    exclude_input_regex = paste0(
      "^(\\.clientdata|", # Shiny interne clientdata inputs
      "analytics_consent)" # Analytics consent input (ikke data)
    ),
    app_name = app_name,
    session = session
  )

  # Tracking started successfully

  return(invisible(TRUE))
}

#' Opløs analytics-konfiguration fra kill-switch, golem-config og legacy env-var
#'
#' Returnerer `list(enabled, source)` hvor `source` beskriver hvilken konfigurationskilde
#' der vandt. Prioritetsrækkefølge: `BISPC_DISABLE_ANALYTICS` > golem-config >
#' `ENABLE_SHINYLOGS` (legacy).
#'
#' @return Named list med `enabled` (logical) og `source` (character)
#' @keywords internal
resolve_analytics_config <- function() {
  if (toupper(Sys.getenv("BISPC_DISABLE_ANALYTICS", "")) %in% c("TRUE", "1", "YES", "ON")) {
    return(list(enabled = FALSE, source = "env:BISPC_DISABLE_ANALYTICS"))
  }
  config_val <- tryCatch(
    golem::get_golem_options("analytics.shinylogs_enabled"),
    error = function(e) NULL # nolint: swallowed_error_linter. Golem-config kan mangle uden for app-kontekst
  )
  if (!is.null(config_val)) {
    return(list(enabled = isTRUE(config_val), source = "golem-config"))
  }
  enable_flag <- Sys.getenv("ENABLE_SHINYLOGS", "TRUE")
  list(
    enabled = toupper(enable_flag) %in% c("TRUE", "1", "YES", "ON"),
    source = "env:ENABLE_SHINYLOGS (legacy)"
  )
}

#' Environment variable configuration for shinylogs
#'
#' Tjekker environment variable for at kontrollere shinylogs funktioner
#'
should_enable_shinylogs <- function() {
  resolve_analytics_config()$enabled
}

#' Initialize shinylogs logging announcement
#'
#' Displays shinylogs status information during application initialization.
#' This function should be called explicitly during server startup, not at parse-time.
#'
#' @keywords internal
initialize_shinylogs_announcement <- function() {
  if (should_enable_shinylogs()) {
    log_debug("=====================================", .context = "SHINYLOGS")
    log_debug("SHINYLOGS ADVANCED LOGGING ACTIVE", .context = "SHINYLOGS")
    log_debug("=====================================", .context = "SHINYLOGS")
    log_debug("Real-time web-based log viewer", .context = "SHINYLOGS")
    log_debug("Performance monitoring", .context = "SHINYLOGS")
    log_debug("Session management statistics", .context = "SHINYLOGS")
    log_debug("Export capabilities", .context = "SHINYLOGS")
    log_debug("", .context = "SHINYLOGS")
    log_debug("Access logs dashboard at: /logs (when implemented in UI)", .context = "SHINYLOGS")
    log_debug("Control via: ENABLE_SHINYLOGS environment variable", .context = "SHINYLOGS")
    log_debug("=====================================", .context = "SHINYLOGS")
  } else {
    log_debug("Shinylogs advanced logging disabled", .context = "SHINYLOGS")
  }

  invisible(NULL)
}
