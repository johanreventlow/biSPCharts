# server_file_upload.R
# Server logik til håndtering af fil uploads og import

# Dependencies ----------------------------------------------------------------
# Bruger readxl og readr til fil-import

#' Læs tekstfil med automatisk encoding-detection
#'
#' Prøver UTF-8 først, derefter Latin1 som fallback for danske filer
#' fra Windows-systemer.
#'
#' @param file_path Sti til fil
#' @return Character vector med filens linjer (altid UTF-8)
#' @noRd
read_csv_detect_encoding <- function(file_path) {
  # Læs som UTF-8 først (mest sandsynligt)
  text <- readLines(file_path, warn = FALSE, encoding = "UTF-8")

  # Tjek om resultatet er valid UTF-8 — hvis ikke, er filen sandsynligvis Latin1
  # (typisk for danske CSV-filer eksporteret fra Windows/Excel)
  if (length(text) > 0 && !all(validEnc(text))) {
    text <- readLines(file_path, warn = FALSE, encoding = "latin1")
  }

  text
}

#' Upload-successnotifikation med kolonnenavne
#' @param source_label Kildelabel (fx "CSV", "Excel", "Indsatte data")
#' @param data Data frame der blev indlæst
#' @noRd
notify_upload_success <- function(source_label, data) {
  col_names <- names(data)
  col_preview <- if (length(col_names) <= 6) {
    paste(col_names, collapse = ", ")
  } else {
    paste0(
      paste(col_names[1:5], collapse = ", "),
      " (+", length(col_names) - 5, " mere)"
    )
  }

  msg <- paste0(
    source_label, " indl\u00e6st: ",
    nrow(data), " r\u00e6kker, ",
    ncol(data), " kolonner (",
    col_preview, ")"
  )

  tryCatch(
    shiny::showNotification(msg, type = "message", duration = 4),
    error = function(e) invisible(NULL)
  )
}

#' Validate safe file path for uploads
#' Enhanced path traversal protection for file uploads
#' @param uploaded_path Path from file upload input
#' @return Validated safe file path
#' @noRd
validate_safe_file_path <- function(uploaded_path) {
  # Input validation
  if (is.null(uploaded_path) || !is.character(uploaded_path) || length(uploaded_path) != 1) {
    log_error(
      component = "[SECURITY]",
      message = "Ugyldig filsti",
      details = list(
        input_type = typeof(uploaded_path),
        input_length = length(uploaded_path)
      )
    )
    stop("Sikkerhedsfejl: Ugyldig fil input")
  }

  # Normalize path with enhanced error handling
  file_path <- tryCatch(
    {
      normalizePath(uploaded_path, mustWork = TRUE)
    },
    error = function(e) {
      log_error(
        component = "[SECURITY]",
        message = "Kunne ikke normalisere filsti",
        details = list(
          attempted_path = uploaded_path,
          error = e$message
        )
      )
      stop("Sikkerhedsfejl: Kunne ikke validere fil sti")
    }
  )

  # Define comprehensive allowed base paths
  allowed_bases <- c(
    normalizePath(tempdir(), mustWork = FALSE),
    normalizePath(dirname(tempfile()), mustWork = FALSE),
    # Shiny's default upload location
    normalizePath(file.path(tempdir(), "shiny-uploads"), mustWork = FALSE)
  )

  # Add current working directory data folder if it exists
  if (dir.exists("./data")) {
    allowed_bases <- c(allowed_bases, normalizePath("./data", mustWork = FALSE))
  }

  # Validate path is within allowed directories with enhanced checking
  # Normalize paths to forward slashes for consistent cross-platform comparison
  safe_path <- any(vapply(allowed_bases, function(base) {
    # Normalize both paths to forward slashes for comparison
    base_norm <- gsub("\\\\", "/", base)
    file_norm <- gsub("\\\\", "/", file_path)

    # Remove trailing slashes for consistent comparison
    base_norm <- sub("/$", "", base_norm)
    file_norm <- sub("/$", "", file_norm)

    # Check if file is under base directory or is the base itself
    startsWith(file_norm, paste0(base_norm, "/")) || identical(file_norm, base_norm)
  }, logical(1)))

  if (!safe_path) {
    log_error(
      component = "[SECURITY]",
      message = "Path traversal attempt blocked",
      details = list(
        attempted_path = uploaded_path,
        normalized_path = file_path,
        allowed_bases = allowed_bases,
        session_id = "REDACTED" # Don't log actual session ID
      )
    )
    stop("Sikkerhedsfejl: Ugyldig fil sti")
  }

  return(file_path)
}

# UPLOAD HÅNDTERING ===========================================================

## Setup fil upload funktionalitet
setup_file_upload <- function(input, output, session, app_state, emit, ui_service = NULL) {
  # Unified state: App state is always available

  # File upload handler
  shiny::observeEvent(input$data_file, {
    # RATE LIMITING: Prevent DoS via rapid uploads
    # Uses RATE_LIMITS$file_upload_seconds for centralized security configuration
    last_upload_time <- shiny::isolate(app_state$session$last_upload_time)
    if (!is.null(last_upload_time)) {
      time_since_upload <- as.numeric(difftime(Sys.time(), last_upload_time, units = "secs"))
      min_upload_interval <- RATE_LIMITS$file_upload_seconds

      if (time_since_upload < min_upload_interval) {
        shiny::showNotification(
          "Vent venligst et \u00f8jeblik, f\u00f8r du uploader en ny fil.",
          type = "warning",
          duration = 3
        )
        log_warn(
          paste("Upload rate limit triggered - last upload", round(time_since_upload, 1), "seconds ago"),
          .context = "FILE_UPLOAD_SECURITY",
          session_id = sanitize_session_token(session$token)
        )
        return()
      }
    }

    # Enhanced debug tracking for comprehensive testing
    # SPRINT 1 SECURITY FIX: Sanitize session token before logging
    debug_user_interaction(
      "file_upload_initiated",
      list(
        filename = input$data_file$name,
        size = input$data_file$size,
        type = input$data_file$type
      ),
      sanitize_session_token(session$token)
    )

    shiny::req(input$data_file)

    # Luk upload-modal automatisk når fil er valgt (#167)
    shiny::removeModal()

    # Start workflow tracer for file upload
    # SPRINT 1 SECURITY FIX: Sanitize session token before logging
    upload_tracer <- debug_workflow_tracer("file_upload_workflow", app_state, sanitize_session_token(session$token))
    upload_tracer$step("upload_initiated")


    debug_log("File upload started", "FILE_UPLOAD_FLOW",
      level = "INFO",
      context = list(
        filename = input$data_file$name,
        size_bytes = input$data_file$size,
        file_type = input$data_file$type
      ),
      session_id = sanitize_session_token(session$token)
    )

    upload_tracer$step("file_validation")

    # ENHANCED FILE VALIDATION
    # SPRINT 1 SECURITY FIX: Sanitize session token before logging
    validation_result <- validate_uploaded_file(input$data_file, sanitize_session_token(session$token))
    if (!validation_result$valid) {
      upload_tracer$complete("file_validation_failed")
      debug_log("File validation failed", "ERROR_HANDLING",
        level = "ERROR",
        context = list(
          validation_errors = validation_result$errors,
          filename = input$data_file$name
        ),
        session_id = sanitize_session_token(session$token)
      )

      shiny::showNotification(
        paste("Filvalidering fejlede:", paste(validation_result$errors, collapse = "; ")),
        type = "error",
        duration = 8
      )
      return()
    }

    upload_tracer$step("file_validation_complete")

    # Show loading indicator (replaced waiter with simple logging)

    # Close upload modal automatically
    on.exit(
      {
        shiny::removeModal()
      },
      add = TRUE
    )

    upload_tracer$step("state_management_setup")

    # Unified state assignment only - Set table updating flag
    app_state$data$updating_table <- TRUE

    debug_log("File upload state flags set", "FILE_UPLOAD_FLOW",
      level = "TRACE",
      context = list(updating_table = TRUE),
      session_id = sanitize_session_token(session$token)
    )
    on.exit(
      {
        # Unified state assignment only - Clear table updating flag
        app_state$data$updating_table <- FALSE
      },
      add = TRUE
    )

    # Enhanced path traversal protection
    file_path <- validate_safe_file_path(input$data_file$datapath)

    file_ext <- tools::file_ext(input$data_file$name)


    if (file.exists(file_path)) {
      file_info <- file.info(file_path)
    }

    safe_operation(
      operation_name = "Fil upload processing",
      code = {
        upload_tracer$step("file_processing_started")

        if (file_ext %in% c("xlsx", "xls")) {
          debug_log("Starting Excel file processing", "FILE_UPLOAD_FLOW", level = "INFO", session_id = sanitize_session_token(session$token))
          handle_excel_upload(file_path, session, app_state, emit, ui_service)
          upload_tracer$step("excel_processing_complete")
        } else {
          debug_log("Starting CSV file processing", "FILE_UPLOAD_FLOW", level = "INFO", session_id = sanitize_session_token(session$token))
          # SPRINT 1 SECURITY FIX: Sanitize token passed to handle_csv_upload
          handle_csv_upload(file_path, app_state, sanitize_session_token(session$token), emit)
          upload_tracer$step("csv_processing_complete")
        }

        # Complete workflow tracing
        upload_tracer$complete("file_upload_workflow_complete")
        debug_log("File upload workflow completed successfully", "FILE_UPLOAD_FLOW", level = "INFO", session_id = sanitize_session_token(session$token))

        # Update rate limiting timestamp after successful upload
        app_state$session$last_upload_time <- Sys.time()
      },
      error_type = "network",
      emit = emit,
      app_state = app_state,
      session = session,
      show_user = TRUE
    )
  })

  # UNIFIED EVENT SYSTEM: Auto-detection is now handled by data_loaded events
  # The event system automatically triggers auto-detection when new data is loaded
}

## Håndter Excel fil upload
handle_excel_upload <- function(file_path, session, app_state, emit, ui_service = NULL) {
  excel_sheets <- readxl::excel_sheets(file_path)

  # Nyt biSPCharts gem-format: "Data" + "Indstillinger"
  if ("Data" %in% excel_sheets && "Indstillinger" %in% excel_sheets) {
    data <- readxl::read_excel(file_path, sheet = "Data", col_names = TRUE)
    data <- ensure_standard_columns(data)
    metadata <- parse_spc_excel(file_path, sheets = excel_sheets)

    data_frame <- as.data.frame(data)

    if (!is.null(metadata) && !is.null(ui_service)) {
      # Fuld restore: spejl localStorage-session_restore-flowet så auto-detect
      # IKKE kører og gemte mappings ikke overskrives. Rækkefølge er kritisk:
      # 1) Guard-flag sættes FØR state-skriv så listeners suppresses korrekt.
      # 2) Kolonne-mappings skrives til app_state FØR emit, så downstream-
      #    listeners ser korrekt state i første iteration.
      # 3) restore_metadata() scheduleres via session$onFlushed — den må IKKE
      #    køre synkront, da selectize-choices først populeres af
      #    handle_session_restore_context().
      # 4) emit("session_restore") router til session_restore-handler (exact
      #    match), som kalder update_column_choices_unified + navigation +
      #    visualization_update_needed. Dette erstatter emit("file_loaded")
      #    der ellers ville trigge auto_detection_started.
      # 5) Cleanup af restoring_session-flag scheduleres efter flush.
      app_state$session$restoring_session <- TRUE

      set_current_data(app_state, data_frame)
      app_state$data$original_data <- data_frame
      app_state$session$file_uploaded <- TRUE
      app_state$columns$auto_detect$completed <- TRUE
      app_state$ui$hide_anhoej_rules <- FALSE

      for (field in c("x_column", "y_column", "n_column",
                      "skift_column", "frys_column", "kommentar_column")) {
        val <- metadata[[field]]
        if (!is.null(val) && nzchar(val)) {
          app_state$columns$mappings[[field]] <- val
        }
      }

      session$onFlushed(
        function() {
          shiny::isolate({
            log_debug(
              "Restoring metadata after UI flush (Excel upload)",
              .context = "SESSION_RESTORE"
            )
            restore_metadata(session, metadata, ui_service)
          })
        },
        once = TRUE
      )

      emit$data_updated("session_restore")

      session$onFlushed(
        function() {
          shiny::isolate({
            app_state$session$restoring_session <- FALSE
            log_debug(
              "restoring_session flag cleared after Excel upload restore",
              .context = "SESSION_RESTORE"
            )
          })
        },
        once = TRUE
      )

      besked <- paste0("Gendannet: ", nrow(data_frame), " r\u00e6kker, ",
                       ncol(data_frame), " kolonner + indstillinger")
    } else {
      # Fallback: Indstillinger-ark kunne ikke parses. Behandl som almindelig
      # data-upload og kør auto-detection i stedet.
      set_current_data(app_state, data_frame)
      app_state$data$original_data <- data_frame
      app_state$session$file_uploaded <- TRUE
      app_state$columns$auto_detect$completed <- FALSE
      app_state$ui$hide_anhoej_rules <- FALSE

      emit$data_updated("file_loaded")
      emit$navigation_changed()

      besked <- paste0("Data indl\u00e6st: ", nrow(data_frame), " r\u00e6kker \u2014 ",
                       "indstillinger kunne ikke gendannes")
    }

    shiny::showNotification(besked, type = "message", duration = 4)
    return(invisible(NULL))
  }

  # Standard Excel file (uden Indstillinger-ark)
  data <- readxl::read_excel(file_path, col_names = TRUE)

  # Ensure standard columns are present and in correct order
  data <- ensure_standard_columns(data)

  # Dual-state sync during migration - Excel file loading
  data_frame <- as.data.frame(data)
  set_current_data(app_state, data_frame)
  app_state$data$original_data <- data_frame

  # Emit unified data_updated event (replaces legacy data_loaded)
  emit$data_updated("file_loaded")

  # Unified state assignment only - Set file uploaded flag
  app_state$session$file_uploaded <- TRUE
  # Unified state assignment only - Set auto detect flag
  app_state$columns$auto_detect$completed <- FALSE
  # Unified state assignment only - Re-enable Anhøj rules when real data is uploaded
  app_state$ui$hide_anhoej_rules <- FALSE

  # NAVIGATION TRIGGER: Navigation events are now handled by the unified event system
  emit$navigation_changed()

  notify_upload_success("Excel", data)
}

#' Håndter CSV fil upload med dansk formattering
#'
#' Indlæser og processer CSV filer med danske standarder inklusive
#' encoding, decimal separatorer og standard kolonner. Funktionen
#' håndterer fejl robust og opdaterer app state accordingly.
#'
#' @param file_path Character string med sti til CSV fil
#' @param values Reactive values list til opdatering af app state
#'
#' @details
#' CSV læsning konfiguration:
#' \itemize{
#'   \item Encoding: UTF-8 (danske karakterer)
#'   \item Decimal mark: komma (,)
#'   \item Grouping mark: punktum (.)
#'   \item Separator: semikolon (;) - CSV2 format
#' }
#'
#' Behandling proces:
#' \enumerate{
#'   \item Læs CSV med readr::read_csv2 og dansk locale
#'   \item Tilføj standard SPC kolonner hvis manglende
#'   \item Opdater reactive values med ny data
#'   \item Sæt file_uploaded flag til TRUE
#'   \item Vis success notification til bruger
#' }
#'
#' @return NULL ved success, character string med fejlbesked ved fejl
#'
#' @examples
#' \dontrun{
#' # Upload CSV fil
#' result <- handle_csv_upload("data/spc_data.csv", values)
#' if (is.null(result)) {
#'   message("CSV uploaded successfully")
#' } else {
#'   message("Error:", result)
#' }
#' }
#'
#' @seealso \code{\link{handle_excel_upload}}, \code{\link{ensure_standard_columns}}
handle_csv_upload <- function(file_path, app_state, session_id = NULL, emit = NULL) {
  debug_log("CSV upload processing started", "FILE_UPLOAD_FLOW",
    level = "INFO",
    context = list(file_path = file_path),
    session_id = session_id
  )

  # CSV behandling med auto-detection af separator (#124)
  # 1. Dansk standard (semikolon + komma-decimal)
  # 2. Fallback: auto-detect
  # 3. Fallback: engelsk (komma + punkt-decimal)

  data <- tryCatch(
    {
      result <- readr::read_csv2(
        file_path,
        locale = readr::locale(
          decimal_mark = ",",
          grouping_mark = ".",
          encoding = UTF8_ENCODING
        ),
        show_col_types = FALSE
      )
      if (ncol(result) >= 2) result else NULL
    },
    error = function(e) NULL
  )

  if (is.null(data)) {
    # Fallback: auto-detect separator
    data <- tryCatch(
      {
        result <- readr::read_delim(
          file_path,
          delim = NULL,
          locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
          show_col_types = FALSE,
          trim_ws = TRUE
        )
        if (ncol(result) >= 2) result else NULL
      },
      error = function(e) NULL
    )
  }

  if (is.null(data)) {
    # Fallback: engelsk CSV (komma + punkt-decimal)
    data <- tryCatch(
      readr::read_csv(
        file_path,
        locale = readr::locale(
          decimal_mark = ".",
          grouping_mark = ",",
          encoding = UTF8_ENCODING
        ),
        show_col_types = FALSE
      ),
      error = function(e) NULL
    )
  }

  if (is.null(data) || ncol(data) < 2 || nrow(data) < 1) {
    shiny::showNotification(
      "Kunne ikke parse CSV-filen. Kontroll\u00e9r format og encoding.",
      type = "error", duration = 5
    )
    return(invisible(NULL))
  }


  debug_log("CSV data loaded successfully", "FILE_UPLOAD_FLOW",
    level = "INFO",
    context = list(
      rows = nrow(data),
      columns = ncol(data),
      column_names = names(data)
    ),
    session_id = session_id
  )

  # ENHANCED DATA PREPROCESSING: Clean and validate data
  preprocessing_result <- preprocess_uploaded_data(
    data,
    list(name = basename(file_path), size = file.info(file_path)$size),
    session_id
  )
  data <- preprocessing_result$data

  # Show user notification if significant cleaning occurred
  if (!is.null(preprocessing_result$cleaning_log)) {
    cleaning_messages <- character(0)
    if (!is.null(preprocessing_result$cleaning_log$empty_rows_removed)) {
      cleaning_messages <- c(
        cleaning_messages,
        paste(preprocessing_result$cleaning_log$empty_rows_removed, "empty rows removed")
      )
    }
    if (!is.null(preprocessing_result$cleaning_log$column_names_cleaned)) {
      cleaning_messages <- c(cleaning_messages, "column names cleaned")
    }

    if (length(cleaning_messages) > 0) {
      shiny::showNotification(
        paste("Data renset:", paste(cleaning_messages, collapse = ", ")),
        type = "message",
        duration = 5
      )
    }
  }

  # Ensure standard columns are present and in correct order
  data <- ensure_standard_columns(data)


  # Take state snapshot before data assignment
  if (!is.null(app_state)) {
    debug_state_snapshot("before_csv_data_assignment", app_state, session_id = session_id)
  }

  # Unified state assignment only - CSV file loading
  data_frame <- as.data.frame(data)

  # Enhanced debugging: Data structure analysis before assignment


  # Enhanced state change tracking
  debug_state_change(
    "CSV_UPLOAD", "app_state$data$current_data",
    app_state$data$current_data, data_frame,
    "file_upload_processing", session_id
  )

  set_current_data(app_state, data_frame)
  app_state$data$original_data <- data_frame

  # Verify state assignment success
  if (is.null(app_state$data$current_data)) {
    warning("State assignment failed: current_data is NULL")
  }

  # Emit unified data_updated event (replaces legacy data_loaded)
  emit$data_updated(context = "session_file_loaded")

  # Unified state assignment - Set file uploaded flag
  app_state$session$file_uploaded <- TRUE
  # Unified state assignment - Set auto detect flag
  app_state$columns$auto_detect$completed <- FALSE
  # Unified state assignment - Re-enable Anhøj rules when real data is uploaded
  app_state$ui$hide_anhoej_rules <- FALSE

  # NAVIGATION TRIGGER: Navigation events are now handled by the unified event system
  emit$navigation_changed()


  # ROBUST AUTO-DETECT: Enhanced auto-detection triggering with validation

  debug_log("Data loaded event emitted successfully", "FILE_UPLOAD_FLOW",
    level = "INFO",
    context = list(
      rows = nrow(data),
      columns = ncol(data),
      event_system = "unified_event_bus"
    ),
    session_id = session_id
  )

  # Take state snapshot after all state is set
  if (!is.null(app_state)) {
    debug_state_snapshot("after_csv_upload_complete", app_state, session_id = session_id)
  }

  notify_upload_success("CSV", data)
}

#' Haandter indsatte (pasted) data fra textAreaInput
#'
#' Parser tekst-data med auto-detected separator (tab, semikolon, komma).
#' Bruger readr::read_delim med delim = NULL for auto-detection.
#'
#' @param text_data Character string med indsatte data
#' @param app_state Centraliseret app state
#' @param session_id Hashed session token (valgfri)
#' @param emit Event emit API
#' @return Usynligt NULL, opdaterer app_state som side-effekt
#' @keywords internal
handle_paste_data <- function(text_data, app_state, session_id = NULL, emit = NULL) {
  # Valider input
  if (is.null(text_data) || !nzchar(trimws(text_data))) {
    shiny::showNotification("Indsæt data først", type = "warning", duration = 3)
    return(invisible(NULL))
  }

  # Smart separator detection: prøv eksplicitte separatorer først
  # read_delim(delim=NULL) auto-detect fejler på semikolon-filer med mellemrum
  # i kolonnenavne (fx "Uge tekst"), så vi prøver dansk standard først.
  data <- NULL
  best_fallback <- NULL
  for (sep in c(";", "\t", ",")) {
    attempt <- tryCatch(
      readr::read_delim(
        I(text_data),
        delim = sep,
        locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
        show_col_types = FALSE,
        trim_ws = TRUE
      ),
      error = function(e) NULL
    )
    if (!is.null(attempt) && ncol(attempt) >= 3) {
      data <- attempt
      break
    }
    if (!is.null(attempt) && ncol(attempt) >= 2 && is.null(best_fallback)) {
      best_fallback <- attempt
    }
  }
  if (is.null(data)) {
    data <- best_fallback
  }

  # Valider resultat — fang ustruktureret fritekst uden kolonner/separatorer
  if (is.null(data) || ncol(data) < 2 || nrow(data) < 1) {
    shiny::showNotification(
      paste0(
        "Data kunne ikke l\u00e6ses. S\u00f8rg for at data har kolonneoverskrifter ",
        "adskilt med semikolon eller tabulator."
      ),
      type = "error", duration = 6
    )
    return(invisible(NULL))
  }

  # Fritekst med tilfældige separatorer kan passere strukturel validering
  has_numeric <- any(vapply(data, is_column_numeric, logical(1), threshold = 0))

  if (!has_numeric) {
    shiny::showNotification(
      paste0(
        "Data kunne ikke l\u00e6ses. Mindst \u00e9n kolonne skal indeholde tal. ",
        "S\u00f8rg for at data har kolonneoverskrifter adskilt med semikolon eller tabulator."
      ),
      type = "error", duration = 6
    )
    return(invisible(NULL))
  }

  # Preprocessing (genbrug eksisterende)
  preprocessing_result <- tryCatch(
    preprocess_uploaded_data(
      data,
      list(name = "pasted_data", size = nchar(text_data)),
      session_id
    ),
    error = function(e) {
      log_error(
        paste("Preprocessing af paste-data fejlede:", e$message),
        .context = "PASTE_DATA"
      )
      NULL
    }
  )

  if (is.null(preprocessing_result)) {
    shiny::showNotification(
      paste0(
        "Data kunne ikke behandles. S\u00f8rg for at data har kolonneoverskrifter ",
        "adskilt med semikolon eller tabulator."
      ),
      type = "error", duration = 6
    )
    return(invisible(NULL))
  }

  data <- preprocessing_result$data

  # Tilføj Skift/Frys kolonner hvis de mangler
  data <- ensure_standard_columns(data)

  # Gem i app state (samme moenster som handle_csv_upload)
  data_frame <- as.data.frame(data)
  set_current_data(app_state, data_frame)
  app_state$data$original_data <- data_frame

  # Emit events
  emit$data_updated(context = "paste_data")
  app_state$session$file_uploaded <- TRUE
  app_state$columns$auto_detect$completed <- FALSE
  app_state$ui$hide_anhoej_rules <- FALSE
  emit$navigation_changed()

  notify_upload_success("Indsatte data", data)

  invisible(NULL)
}


# Validering, fejlhåndtering og preprocessing er udtrukket til fct_file_validation.R
