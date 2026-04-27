# utils_ui_column_update_service.R
# Kolonne-relaterede UI-opdateringer (selectizeInput for datakort)

#' Create Column Update Service
#'
#' Tynd closure der centraliserer kolonne-selectize-input opdateringer.
#' Deler loop-protection med `safe_programmatic_ui_update()`.
#'
#' @param session Shiny session-objekt
#' @param app_state Centraliseret app state
#' @return Liste med kolonne-update-funktioner
#'
#' @keywords internal
create_column_update_service <- function(session, app_state) {
  normalize_select_value <- function(value, default = "") {
    value <- sanitize_selection(value)
    if (is.null(value)) {
      return(default)
    }
    as.character(value[[1]])
  }

  # Opdater kolonne-choices (enkelt eller batch)
  #
  # Unified funktion for opdatering af kolonne-selectize inputs.
  # Genererer choices fra current_data hvis ikke angivet.
  #
  # @param choices Named vector med choices. NULL = generer fra current_data
  # @param selected Named list med valgte vaerdier per kolonne
  # @param columns Vector af input IDs der skal opdateres
  # @param clear_selections TRUE = ryd alle valg
  #
  update_column_choices <- function(choices = NULL,
                                    selected = NULL,
                                    columns = c(
                                      "x_column", "y_column", "n_column",
                                      "skift_column", "frys_column", "kommentar_column"
                                    ),
                                    clear_selections = FALSE) {
    if (is.null(choices)) {
      current_data <- app_state$data$current_data
      if (!is.null(current_data)) {
        all_cols <- names(current_data)
        choices <- setNames(
          c("", all_cols),
          c("V\u00e6lg kolonne...", all_cols)
        )
      } else {
        choices <- setNames("", "V\u00e6lg kolonne...")
      }
    }

    if (clear_selections) {
      selected <- setNames(rep("", length(columns)), columns)
    } else if (is.null(selected)) {
      selected <- list()
      for (col in columns) {
        current_val <- safe_operation(
          paste("Read column value for", col),
          code = {
            session_input_val <- normalize_select_value(session$input[[col]], default = "")
            if (nzchar(session_input_val)) {
              session_input_val
            } else {
              state_val <- normalize_select_value(
                shiny::isolate(app_state$columns$mappings[[col]]),
                default = ""
              )
              state_val
            }
          },
          fallback = "",
          session = session,
          error_type = "general"
        )
        selected[[col]] <- current_val
      }
    }

    safe_programmatic_ui_update(session, app_state, function() {
      for (col in columns) {
        selected_value <- if (!is.null(selected) && col %in% names(selected)) {
          normalize_select_value(selected[[col]], default = "")
        } else {
          ""
        }
        shiny::updateSelectizeInput(session, col, choices = choices, selected = selected_value)
      }
    })
  }

  # Batch-opdater alle kolonne-inputs med samme choices
  #
  # @param choices Named vector med choices
  # @param selected Named list med valgte vaerdier
  # @param columns Vector af input IDs (default: alle SPC-kolonner)
  #
  update_all_columns <- function(choices,
                                 selected = list(),
                                 columns = c(
                                   "x_column", "y_column", "n_column",
                                   "skift_column", "frys_column", "kommentar_column"
                                 )) {
    safe_programmatic_ui_update(session, app_state, function() {
      for (col in columns) {
        selected_value <- if (col %in% names(selected)) normalize_select_value(selected[[col]], default = "") else ""
        shiny::updateSelectizeInput(
          session = session,
          inputId = col,
          choices = choices,
          selected = selected_value
        )
      }
    })
  }

  # Opdater alle kolonner fra app_state med isolate()
  #
  # Avanceret variant der laeser valgte vaerdier fra app_state med isolate().
  # Bruges i event-listeners hvor reaktiv isolation er noedvendig.
  #
  # @param choices Named vector med choices
  # @param columns_state reactiveValues med kolonne-mappings (app_state$columns$mappings)
  # @param log_context Valgfri log-kontekst-streng
  #
  update_all_columns_from_state <- function(choices, columns_state, log_context = "UI_SYNC_UNIFIED") {
    spc_cols <- c("x_column", "y_column", "n_column", "skift_column", "frys_column", "kommentar_column")

    safe_programmatic_ui_update(session, app_state, function() {
      for (col_id in spc_cols) {
        col_val <- normalize_select_value(shiny::isolate(columns_state[[col_id]]), default = "")
        if (!is.null(col_val)) {
          shiny::updateSelectizeInput(
            session = session,
            inputId = col_id,
            choices = choices,
            selected = col_val
          )
          log_debug_kv_args <- list(.context = log_context)
          log_debug_kv_args[[paste0("updated_", col_id, "_ui")]] <- col_val
          do.call(log_debug_kv, log_debug_kv_args)
        }
      }
    })
  }

  list(
    update_column_choices = update_column_choices,
    update_all_columns = update_all_columns,
    update_all_columns_from_state = update_all_columns_from_state
  )
}
