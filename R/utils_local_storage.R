# local_storage_functions.R
# Server-side funktioner til localStorage integration og databehandling

# Dependencies ----------------------------------------------------------------

# SCHEMA VERSION ==============================================================
# Bumpes når payload-struktur ændres. Load-logik rydder ved version-mismatch.
# 3.0: y_axis_unit "time" splittet til time_minutes/time_hours/time_days.
#      Silent forward-migration via migrate_time_yaxis_unit().
LOCAL_STORAGE_SCHEMA_VERSION <- "3.0"

# MIGRATION ==================================================================

#' Silent forward-migration: "time" → "time_minutes"
#'
#' Version 2.0 payloads har y_axis_unit = "time" med implicit antagelse
#' om minutter. Version 3.0 kræver eksplicit time_minutes/time_hours/time_days.
#' Migrationen bevarer klinisk data ved at mappe den implicitte antagelse
#' til den eksplicitte `time_minutes`-enhed.
#'
#' Migrationen er idempotent: 3.0 payloads returneres uændret. Ukendte
#' versioner (< 2.0) passeres igennem uændret — det er load-logikkens
#' ansvar at rydde ved full schema-mismatch.
#'
#' @param saved_state List med 'version' og evt. 'metadata'. NULL returneres.
#' @return Opdateret list med version = LOCAL_STORAGE_SCHEMA_VERSION for 2.0
#'   payloads; ellers uændret.
#' @keywords internal
migrate_time_yaxis_unit <- function(saved_state) {
  if (is.null(saved_state)) {
    return(saved_state)
  }

  src_version <- saved_state$version %||% "unknown"

  # Kun migrér 2.0 → 3.0. Nyere versioner returneres uændret.
  if (identical(src_version, "2.0")) {
    if (!is.null(saved_state$metadata) &&
      !is.null(saved_state$metadata$y_axis_unit) &&
      identical(saved_state$metadata$y_axis_unit, "time")) {
      saved_state$metadata$y_axis_unit <- "time_minutes"
    }
    saved_state$version <- LOCAL_STORAGE_SCHEMA_VERSION
  }

  saved_state
}

# CLASS PRESERVATION HELPERS =================================================

#' Ekstraherer class-metadata for hver kolonne i et data.frame
#'
#' Producerer en named list pr. kolonne med nok information til at rekonstruere
#' den præcise R-type efter JSON roundtrip. Understøtter numeric, integer,
#' character, logical, Date, POSIXct (med tz) og factor (med levels).
#'
#' @param data data.frame hvis kolonner skal beskrives
#' @return Named list indekseret på kolonnenavne
#' @keywords internal
extract_class_info <- function(data) {
  if (is.null(data) || ncol(data) == 0) {
    return(list())
  }

  info <- lapply(data, function(col) {
    cls <- class(col)
    list(
      primary = cls[1],
      is_date = inherits(col, "Date"),
      is_posixct = inherits(col, "POSIXct"),
      is_factor = is.factor(col),
      levels = if (is.factor(col)) levels(col) else NULL,
      tz = if (inherits(col, "POSIXct")) {
        tz_attr <- attr(col, "tzone")
        if (is.null(tz_attr) || identical(tz_attr, "")) "UTC" else tz_attr
      } else {
        NULL
      }
    )
  })

  names(info) <- colnames(data)
  info
}

#' Gendanner en kolonne til dens oprindelige R-klasse
#'
#' Modtager rå værdier efter JSON roundtrip og class_info genereret af
#' extract_class_info(). Håndterer Date, POSIXct med tz, integer, factor
#' med levels, samt basis-typer numeric/character/logical.
#'
#' @param values Rå værdier efter fromJSON (typisk character eller numeric)
#' @param class_info Class-metadata fra extract_class_info() for denne kolonne
#' @return Vector gendannet til korrekt R-klasse
#' @keywords internal
restore_column_class <- function(values, class_info) {
  if (is.null(class_info)) {
    return(values)
  }

  # NULL→NA konvertering: jsonlite::fromJSON(simplifyVector = FALSE)
  # giver lister hvor NA-elementer bliver NULL. Downstream coercion
  # (as.numeric, as.Date, etc.) fejler på list med NULL-elementer, så
  # vi konverterer her til en atomic vector med NA på NULL-positioner.
  # NB: Vi kan IKKE bruge vapply(FUN.VALUE = NA) fordi logical NA ville
  # coerce alt til logical. unlist() bestemmer common type selv.
  if (is.list(values)) {
    cleaned <- lapply(values, function(x) {
      if (is.null(x) || length(x) == 0) NA else x
    })
    values <- unlist(cleaned, use.names = FALSE)
  }

  primary <- class_info$primary %||% "character"

  # Factor: brug gemte levels for at bevare rækkefølge
  if (isTRUE(class_info$is_factor)) {
    char_values <- as.character(values)
    return(factor(char_values, levels = class_info$levels))
  }

  # Date: parse ISO8601
  if (isTRUE(class_info$is_date)) {
    if (is.numeric(values)) {
      # jsonlite kan serialisere Date som numeric (days since 1970)
      return(as.Date(values, origin = "1970-01-01"))
    }
    return(as.Date(as.character(values)))
  }

  # POSIXct: parse med original tidszone
  if (isTRUE(class_info$is_posixct)) {
    tz <- class_info$tz %||% "UTC"
    if (is.numeric(values)) {
      return(as.POSIXct(values, origin = "1970-01-01", tz = tz))
    }
    return(as.POSIXct(as.character(values), tz = tz))
  }

  # Basis-typer
  switch(primary,
    "integer" = as.integer(values),
    "numeric" = as.numeric(values),
    "double" = as.numeric(values),
    "character" = as.character(values),
    "logical" = as.logical(values),
    values
  )
}

# Null-coalesce helper (defineret her hvis ikke globalt tilgængelig)
`%||%` <- function(a, b) if (is.null(a)) b else a

# LOCAL STORAGE FUNKTIONER ===================================================

## Local Storage funktioner til server med datastruktur preservation
saveDataLocally <- function(session, data, metadata = NULL) {
  safe_operation(
    "Save data to local storage",
    code = {
      # CRITICAL: Preserve data structure explicitly med udvidet class-info
      data_to_save <- list(
        values = lapply(data, function(x) as.vector(x)), # Convert each column to vector
        col_names = colnames(data),
        nrows = nrow(data),
        ncols = ncol(data),
        class_info = extract_class_info(data)
      )

      app_state <- list(
        data = data_to_save, # Use structured data
        metadata = metadata,
        timestamp = Sys.time(),
        version = LOCAL_STORAGE_SCHEMA_VERSION
      )

      # Konverter til JSON med bedre indstillinger for data preservation
      json_data <- jsonlite::toJSON(
        app_state,
        auto_unbox = TRUE,
        pretty = FALSE,
        digits = NA, # Preserve all digits
        na = "null" # Handle NA values properly
      )

      # CRITICAL: Strip jsonlite 'json' class før vi sender til Shiny.
      # Shiny's interne message serializer håndterer ikke 'json' class korrekt
      # og kan konvertere sådanne objekter til literal null. Ved at caste til
      # ren character får vi en almindelig string der serialiseres som JS-string.
      json_data_raw <- as.character(json_data)

      if (is.null(json_data_raw) || length(json_data_raw) == 0 ||
        nchar(json_data_raw) == 0) {
        stop("JSON konvertering resulterede i tomme data")
      }

      log_debug(
        sprintf("Sending %d bytes to browser localStorage", nchar(json_data_raw)),
        .context = "LOCAL_STORAGE"
      )

      # Send til browser localStorage
      session$sendCustomMessage(
        type = "saveAppState",
        message = list(
          key = "current_session",
          data = json_data_raw
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

#' Auto-save Application State
#'
#' Auto-save funktion med eksplicit app_state dependency injection.
#'
#' @param session Shiny session objekt
#' @param current_data data.frame der skal gemmes
#' @param metadata Named list med UI-state (kolonne-mapping, chart_type, etc.)
#' @param app_state Centraliseret app_state (reactiveValues) - paakraevet for at
#'   kunne deaktivere auto-save ved persistent fejl. Hvis NULL, springes
#'   graceful disable-logik over.
#' @return NULL, invisibly.
#' @keywords internal
autoSaveAppState <- function(session, current_data, metadata, app_state = NULL) {
  # Guard: Respektér auto_save_enabled flag
  if (!is.null(app_state)) {
    enabled <- shiny::isolate(app_state$session$auto_save_enabled)
    if (!isTRUE(enabled)) {
      log_debug(
        "Auto-save sprunget over: app_state$session$auto_save_enabled er FALSE",
        .context = "AUTO_SAVE"
      )
      return(invisible(NULL))
    }
  }

  if (is.null(current_data)) {
    log_debug("Auto-save sprunget over: current_data er NULL", .context = "AUTO_SAVE")
    return(invisible(NULL))
  }

  # Kun gem hvis der er meaningful data
  if (nrow(current_data) == 0 || !any(!is.na(current_data))) {
    log_debug(
      sprintf("Auto-save sprunget over: tomt datas\u00e6t (nrow=%d)", nrow(current_data)),
      .context = "AUTO_SAVE"
    )
    return(invisible(NULL))
  }

  log_info(
    sprintf(
      "Auto-saving %d rows x %d cols to localStorage",
      nrow(current_data), ncol(current_data)
    ),
    .context = "AUTO_SAVE"
  )

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
