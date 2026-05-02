# utils_column_management.R
# Server utilities for column management including auto-detection and validation
# Migrated from fct_data_processing.R - contains only active functions

# Dependencies ----------------------------------------------------------------

# KOLONNEHAaNDTERING SETUP ====================================================

#' Opsaet kolonnehaandtering for SPC app
#'
#' Hovedfunktion der opsaetter al server-side logik relateret til kolonne-management,
#' inklusive auto-detektion, validering og reactive observers for kolonnevalg.
#' Understoetter baade legacy values-baseret og ny centraliseret state management.
#'
#' @param input Shiny input object med brugerinteraktioner
#' @param output Shiny output object for rendering
#' @param session Shiny session object for server kommunikation
#' @param values Reactive values list med app state (legacy system)
#' @param app_state List med centraliseret app state (Phase 4 system), optional
#'
#' @details
#' Funktionen opsaetter foelgende observers:
#' \itemize{
#'   \item Kolonneopdatering ved data aendringer
#'   \item Auto-detektion trigger ved file upload
#'   \item UI synkronisering efter auto-detektion
#'   \item Fejlhaandtering og user feedback
#' }
#'
#' Compatibility: Funktionen detekterer automatisk om centraliseret
#' state management er tilgaengeligt og tilpasser sig entsprechend.
#'
#' @return NULL (side effects via observers)
#'
#' @examples
#' \dontrun{
#' # I Shiny server function:
#' setup_column_management(input, output, session, values, app_state)
#' }
#'
#' @seealso \code{\link{autodetect_engine}}, \code{\link{ensure_standard_columns}}
#' @noRd
setup_column_management <- function(input, output, session, app_state, emit) {
  log_debug_block("COLUMN_MGMT", "Setting up column management")

  # Auto-detekterings knap handler - koerer altid naar bruger trykker
  shiny::observeEvent(input$auto_detect_columns, {
    # FASE 3: Use event-driven manual trigger for consistency
    safe_operation(
      "Manual auto-detection trigger",
      code = {
        emit$manual_autodetect_button() # This triggers the event listener with frozen state bypass
      },
      fallback = NULL,
      session = session,
      show_user = TRUE,
      error_type = "processing",
      emit = emit,
      app_state = app_state
    )
  })

  # Rediger kolonnenavne modal
  shiny::observeEvent(input$edit_column_names, {
    show_column_edit_modal(session, app_state)
  })

  # Bekraeft kolonnenavn aendringer
  shiny::observeEvent(input$confirm_column_names, {
    handle_column_name_changes(input, session, app_state, emit)
  })

  # Tilfoej kolonne
  shiny::observeEvent(input$add_column, {
    show_add_column_modal()
  })

  shiny::observeEvent(input$confirm_add_col, {
    handle_add_column(input, session, app_state, emit)
  })

  # UNIFIED EVENT SYSTEM: No longer returning autodetect_trigger
  # Auto-detection is handled through emit$auto_detection_started() events
  # log_debug("Auto-detection now handled by unified event system", .context = "COLUMN_MGMT")
}

# MODAL FUNKTIONER ============================================================

## Vis kolonne-redigere modal
# Viser modal dialog for redigering af kolonnenavne
show_column_edit_modal <- function(session, app_state = NULL) {
  # Use unified state management
  current_data_check <- app_state$data$current_data
  shiny::req(current_data_check)

  current_names <- names(current_data_check)

  name_inputs <- lapply(1:length(current_names), function(i) {
    shiny::textInput(
      paste0("col_name_", i),
      paste("Kolonne", i, ":"),
      value = current_names[i],
      placeholder = paste("Navn for kolonne", i)
    )
  })

  shiny::showModal(shiny::modalDialog(
    title = "Redig\u00e9r kolonnenavne",
    size = "m",
    shiny::div(
      style = "margin-bottom: 15px;",
      shiny::h6("Nuv\u00e6rende kolonnenavne:", style = "font-weight: 500;"),
      shiny::p(paste(current_names, collapse = ", "), style = "color: #666; font-style: italic;")
    ),
    shiny::div(
      style = "max-height: 300px; overflow-y: auto;",
      name_inputs
    ),
    footer = shiny::tagList(
      shiny::modalButton("Annuller"),
      shiny::actionButton("confirm_column_names", "Gem \u00e6ndringer", class = "btn-primary")
    )
  ))
}

## Haandter kolonnenavn aendringer
# Behandler aendringer af kolonnenavne fra modal dialog
handle_column_name_changes <- function(input, session, app_state = NULL, emit = NULL) {
  # Use unified state management
  current_data_check <- app_state$data$current_data
  shiny::req(current_data_check)

  current_names <- names(current_data_check)
  new_names <- character(length(current_names))

  for (i in 1:length(current_names)) {
    input_value <- input[[paste0("col_name_", i)]]
    if (!is.null(input_value) && input_value != "") {
      new_names[i] <- trimws(input_value)
    } else {
      new_names[i] <- current_names[i]
    }
  }

  # Check for duplicates using tidyverse approach
  if (length(new_names) != length(unique(new_names))) {
    shiny::showNotification(
      "Kolonnenavne skal v\u00e6re unikke. Ret duplikater og pr\u00f8v igen.",
      type = "error",
      duration = 5
    )
    return()
  }

  # Unified state assignment only
  names(app_state$data$current_data) <- new_names

  # Emit event to trigger downstream effects
  if (!is.null(emit)) {
    emit$data_updated("column_changed")
  }

  shiny::removeModal()

  if (!identical(current_names, new_names)) {
    changed_cols <- which(current_names != new_names)
    # K2 FIX: Sanitize column names to prevent XSS via <script> injection in notifications
    safe_old_names <- sapply(current_names[changed_cols], htmltools::htmlEscape)
    safe_new_names <- sapply(new_names[changed_cols], htmltools::htmlEscape)
    change_summary <- paste(
      paste0("'", safe_old_names, "' -> '", safe_new_names, "'"),
      collapse = ", "
    )

    shiny::showNotification(
      paste("Kolonnenavne opdateret:", change_summary),
      type = "message",
      duration = 4
    )
  } else {
    shiny::showNotification("Ingen \u00e6ndringer i kolonnenavne", type = "message", duration = 2)
  }
}

## Vis tilfoej kolonne modal
# Viser modal dialog for tilfoejelse af nye kolonner
show_add_column_modal <- function() {
  shiny::showModal(shiny::modalDialog(
    title = "Tilf\u00f8j ny kolonne",
    shiny::textInput("new_col_name", "Kolonnenavn:", value = "Ny_kolonne"),
    shiny::selectInput("new_col_type", "Type:",
      choices = list("Numerisk" = "numeric", "Tekst" = "text", "Dato" = "date")
    ),
    footer = shiny::tagList(
      shiny::modalButton("Annuller"),
      shiny::actionButton("confirm_add_col", "Tilf\u00f8j", class = "btn-primary")
    )
  ))
}

## Haandter tilfoejelse af kolonne
# Behandler tilfoejelse af nye kolonner til data
handle_add_column <- function(input, session, app_state = NULL, emit = NULL) {
  # Use unified state management
  current_data_check <- app_state$data$current_data
  shiny::req(input$new_col_name, current_data_check)

  new_col_name <- input$new_col_name
  new_col_type <- input$new_col_type

  if (new_col_type == "numeric") {
    # Unified state assignment only
    app_state$data$current_data[[new_col_name]] <- rep(NA_real_, nrow(current_data_check))
  } else if (new_col_type == "date") {
    # Unified state assignment only
    app_state$data$current_data[[new_col_name]] <- rep(NA_character_, nrow(current_data_check))
  } else {
    # Unified state assignment only
    app_state$data$current_data[[new_col_name]] <- rep(NA_character_, nrow(current_data_check))
  }

  # Emit event to trigger downstream effects
  if (!is.null(emit)) {
    emit$data_updated("column_changed")
  }

  shiny::removeModal()
  # K2 FIX: Sanitize column name to prevent XSS
  safe_col_name <- htmltools::htmlEscape(new_col_name)
  shiny::showNotification(paste("Kolonne", safe_col_name, "tilf\u00f8jet"), type = "message")
}

# DATA TABLE FUNKTIONER ======================================================

## Hovedfunktion for datatabel
# Opsaetter al server logik relateret til data-tabel haandtering
setup_data_table <- function(input, output, session, app_state, emit) {
  log_debug_block("DATA_TABLE", "Setting up data table with unified state")

  # UNIFIED EVENT SYSTEM: Direct access to app_state data instead of reactive pattern
  # log_debug("Using unified event system for data table setup", .context = "DATA_TABLE")

  # Hovedtabel rendering med excelR
  output$main_data_table <- excelR::renderExcel({
    # UNIFIED EVENT SYSTEM: Direct access to current data
    current_data_check <- app_state$data$current_data
    shiny::req(current_data_check)

    # log_debug("Rendering table with data dimensions:", paste(dim(current_data_check), collapse = "x"), .context = "DATA_TABLE")

    # Inkluder table_version for at tvinge re-render efter gendannelse
    # (rettet fra app_state$session til app_state$data — korrekt sti)
    version_trigger <- app_state$data$table_version

    # Formater data til visning (konverter numeriske til dansk format)
    data <- format_data_for_excelr(current_data_check)

    excelR::excelTable(
      data = data,
      columns = data.frame(
        title = names(data),
        type = dplyr::case_when(
          names(data) == "Skift" ~ "checkbox",
          names(data) == "Frys" ~ "radio",
          TRUE ~ "text"
        ),
        width = dplyr::case_when(
          names(data) == "Skift" ~ 60,
          names(data) == "Frys" ~ 60,
          names(data) == "Dato" ~ 100,
          names(data) %in% c("T\u00e6ller", "N\u00e6vner") ~ 80,
          names(data) == "Kommentar" ~ 300,
          TRUE ~ 120
        ),
        stringsAsFactors = FALSE
      ),
      allowInsertRow = FALSE,
      allowInsertColumn = FALSE,
      allowDeleteRow = FALSE,
      allowDeleteColumn = FALSE,
      allowRenameColumn = FALSE,
      columnSorting = FALSE,
      rowDrag = FALSE,
      columnDrag = FALSE,
      autoFill = TRUE
    )
  })

  # Haandter excelR tabel aendringer
  shiny::observeEvent(input$main_data_table,
    {
      # Use unified state management
      updating_table_check <- app_state$data$updating_table

      # Use unified state management
      restoring_session_check <- app_state$session$restoring_session

      if (updating_table_check || restoring_session_check) {
        return()
      }

      # Use unified state management
      set_table_updating(app_state, TRUE)
      # Use unified state management
      set_table_op_in_progress(app_state, TRUE)

      on.exit(
        {
          set_table_updating(app_state, FALSE)
          set_table_op_in_progress(app_state, FALSE)
        },
        add = TRUE
      )

      # Trigger event-driven cleanup instead of timing-based
      # Use unified state management
      app_state$data$table_operation_cleanup_needed <- TRUE

      safe_operation(
        operation_name = "ExcelR tabel data opdatering",
        code = {
          new_data <- input$main_data_table

          if (is.null(new_data) || length(new_data) == 0) {
            return()
          }


          # excelR sender data i new_data$data som liste af raekker
          if (!is.null(new_data$data) && length(new_data$data) > 0) {
            # Hent kolonnenavne fra colHeaders
            col_names <- unlist(new_data$colHeaders)

            # Konverter liste af raekker til data frame ved navn-baseret matching
            row_list <- new_data$data

            # Sikker rekonstruktion med tidyverse - navne-baseret i stedet for positions-baseret
            new_df <- purrr::map_dfr(row_list, function(row_data) {
              # Pad row_data til at matche col_names laengde hvis noedvendigt
              if (length(row_data) < length(col_names)) {
                row_data <- c(row_data, rep(NA, length(col_names) - length(row_data)))
              }
              # Konverter alle til character foerst for at undgaa type-konflikter
              row_data_char <- as.character(row_data[seq_along(col_names)])
              # Opret navngivet vektor og konverter til tibble row
              named_row <- stats::setNames(row_data_char, col_names)
              tibble::as_tibble_row(named_row)
            })

            # Konverter datatyper korrekt med tidyverse patterns
            new_df <- new_df |>
              dplyr::mutate(
                # Logiske kolonner - alle er nu character, saa konverter direkte
                dplyr::across(
                  dplyr::any_of(c("Skift", "Frys")),
                  ~ .x %in% c("TRUE", "true")
                ),
                # Numeriske kolonner -- brug parse_danish_number for at haandtere
                # baade dansk (komma-decimal) og engelsk (punkt-decimal) format
                dplyr::across(
                  dplyr::any_of(c("T\u00e6ller", "N\u00e6vner")),
                  ~ parse_danish_number(.x)
                ),
                # Karakter kolonner (allerede character, men eksplicit for tydelighed)
                dplyr::across(
                  dplyr::any_of(c("Dato", "Kommentar")),
                  ~ as.character(.x)
                )
              )
          } else {
            return()
          }

          # Dual-state sync for compatibility during migration
          set_current_data(app_state, new_df)

          # Emit event to trigger downstream effects
          emit$data_updated("table_cells_edited")

          # Stille opdatering -- ingen notification ved hver celleredigering
        },
        error_type = "processing",
        emit = emit,
        app_state = app_state,
        show_user = TRUE,
        session = session
      )
    },
    ignoreInit = TRUE
  )

  # Tilfoej raekke
  shiny::observeEvent(input$add_row, {
    # UNIFIED EVENT SYSTEM: Direct access to current data
    current_data_check <- app_state$data$current_data
    shiny::req(current_data_check)

    # Saet vedvarende flag for at forhindre auto-save interferens
    # Use unified state management
    set_table_op_in_progress(app_state, TRUE)

    new_row <- current_data_check[1, ]
    new_row[1, ] <- NA

    # Dual-state sync for compatibility during migration
    current_data <- get_current_data(app_state)
    set_current_data(app_state, rbind(current_data, new_row))

    # Emit event to trigger downstream effects
    emit$data_updated("column_changed")

    shiny::showNotification("Ny r\u00e6kke tilf\u00f8jet", type = "message")

    # Trigger event-driven cleanup instead of timing-based
    # Use unified state management
    app_state$data$table_operation_cleanup_needed <- TRUE
  })

  # UNIFIED STATE: Table reset functionality moved to utils_server_management.R
  # Uses emit$session_reset() events and unified app_state management
}
