# local_storage_functions.R
# Server-side funktioner til localStorage integration og databehandling

# Dependencies ----------------------------------------------------------------
# LOCAL STORAGE FUNKTIONER ===================================================

## Local Storage funktioner til server med datastruktur preservation
saveDataLocally <- function(session, data, metadata = NULL) {
  safe_operation(
    "Save data to local storage",
    code = {
      # CRITICAL: Preserve data structure explicitly - improved method
      data_to_save <- list(
        values = lapply(data, function(x) as.vector(x)), # Convert each column to vector
        col_names = colnames(data),
        nrows = nrow(data),
        ncols = ncol(data),
        class_info = sapply(data, function(x) class(x)[1]) # Take first class only
      )

      app_state <- list(
        data = data_to_save, # Use structured data
        metadata = metadata,
        timestamp = Sys.time(),
        version = "1.2" # Bumped for data structure fix
      )

      # Konverter til JSON med bedre indstillinger for data preservation
      json_data <- jsonlite::toJSON(
        app_state,
        auto_unbox = TRUE,
        pretty = FALSE,
        digits = NA, # Preserve all digits
        na = "null" # Handle NA values properly
      )

      if (is.null(json_data) || nchar(json_data) == 0) {
        stop("JSON konvertering resulterede i tomme data")
      }

      # Send til browser localStorage
      session$sendCustomMessage(
        type = "saveAppState",
        message = list(
          key = "current_session",
          data = json_data
        )
      )
    },
    fallback = function(e) {
      # H7: Robust error handling - return FALSE instead of stop()
      log_error(
        paste("Kunne ikke gemme data lokalt:", e$message),
        .context = "LOCAL_STORAGE"
      )
      return(FALSE)
    },
    error_type = "local_storage",
    session = session,
    show_user = FALSE # Manual saves will show user message separately
  )
}

## Load data med logging
loadDataLocally <- function(session) {
  safe_operation(
    "Load data from local storage",
    code = {
      # Anmod om data fra localStorage
      session$sendCustomMessage(
        type = "loadAppState",
        message = list(key = "current_session")
      )
    },
    fallback = function(e) {
      # Load failed silently
    },
    error_type = "processing"
  )
}

## Clear data med logging
clearDataLocally <- function(session) {
  safe_operation(
    "Clear data from local storage",
    code = {
      session$sendCustomMessage(
        type = "clearAppState",
        message = list(key = "current_session")
      )
    },
    fallback = function(e) {
      # Clear failed silently
    },
    error_type = "processing"
  )
}

## Auto-save funktion med eksplicit app_state dependency injection
#' @param session Shiny session objekt
#' @param current_data data.frame der skal gemmes
#' @param metadata Named list med UI-state (kolonne-mapping, chart_type, etc.)
#' @param app_state Centraliseret app_state (reactiveValues) — påkrævet for at
#'   kunne deaktivere auto-save ved persistent fejl. Hvis NULL, springes
#'   graceful disable-logik over.
autoSaveAppState <- function(session, current_data, metadata, app_state = NULL) {
  # Guard: Respektér auto_save_enabled flag
  if (!is.null(app_state)) {
    enabled <- shiny::isolate(app_state$session$auto_save_enabled)
    if (!isTRUE(enabled)) {
      return(invisible(NULL))
    }
  }

  if (is.null(current_data)) {
    return(invisible(NULL))
  }

  # Kun gem hvis der er meaningful data
  if (nrow(current_data) == 0 || !any(!is.na(current_data))) {
    return(invisible(NULL))
  }

  # Begræns data størrelse for localStorage (typisk 5-10 MB quota, men vi
  # holder os konservativt under 1 MB for at efterlade plads til metadata)
  data_size <- object.size(current_data)
  if (data_size >= 1000000) {
    shiny::showNotification(
      paste0(
        "Datas\u00e6ttet er for stort til automatisk lagring. ",
        "Brug Download-knappen for at gemme manuelt."
      ),
      type = "warning",
      duration = 5
    )
    return(invisible(NULL))
  }

  result <- safe_operation(
    "Auto-save application state",
    code = {
      saveDataLocally(session, current_data, metadata)
    },
    fallback = function(e) {
      log_error(
        paste("Auto-gem fejlede:", e$message),
        .context = "AUTO_SAVE"
      )
      shiny::showNotification(
        paste0(
          "Din data er stadig tilg\u00e6ngelig i appen. ",
          "Automatisk lagring er midlertidigt deaktiveret."
        ),
        type = "warning",
        duration = 8
      )
      return(FALSE)
    },
    error_type = "local_storage"
  )

  # Graceful disable ved persistent fejl — kræver eksplicit app_state
  if (identical(result, FALSE) && !is.null(app_state)) {
    app_state$session$auto_save_enabled <- FALSE
  }

  invisible(result)
}
