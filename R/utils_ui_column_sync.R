#' UI Column Synchronization Utilities
#'
#' Ekstraheret fra utils_server_event_system.R for bedre modularity.
#' Denne fil indeholder UI synchronization functions for column choice management.
#'
#' @name utils_ui_column_sync
NULL


#' Sync UI with columns (Unified Event Version)
#'
#' Unified version of UI synchronization that updates UI controls
#' based on detected columns.
#'
#' @param app_state The centralized app state
#' @param input Shiny input
#' @param output Shiny output
#' @param session Shiny session
#'
#' @noRd
sync_ui_with_columns_unified <- function(app_state, input, output, session, ui_service = NULL) {
  safe_operation(
    "UI sync debug block",
    code = {
      log_debug_block("UI_SYNC_UNIFIED", "Starting UI synchronization")
    },
    fallback = NULL,
    session = session,
    error_type = "general"
  )


  # Use shiny::isolate() to access reactive values safely
  current_data <- shiny::isolate(app_state$data$current_data)
  if (is.null(current_data)) {
    return()
  }

  data <- current_data
  col_names <- names(data)
  columns_state <- shiny::isolate(app_state$columns)

  # Update UI controls with detected columns using centralized service
  safe_operation(
    "UI controls update with detected columns",
    code = {
      if (!is.null(ui_service)) {
        # Use centralized UI service with detected selections for all 6 columns
        col_choices <- setNames(c("", col_names), c("V\u00e6lg kolonne...", col_names))
        selected_columns <- list(
          x_column = shiny::isolate(columns_state$mappings$x_column) %||% "",
          y_column = shiny::isolate(columns_state$mappings$y_column) %||% "",
          n_column = shiny::isolate(columns_state$mappings$n_column) %||% "",
          skift_column = shiny::isolate(columns_state$mappings$skift_column) %||% "",
          frys_column = shiny::isolate(columns_state$mappings$frys_column) %||% "",
          kommentar_column = shiny::isolate(columns_state$mappings$kommentar_column) %||% ""
        )

        ui_service$update_column_choices(
          choices = col_choices,
          selected = selected_columns,
          columns = c("x_column", "y_column", "n_column", "skift_column", "frys_column", "kommentar_column")
        )
      } else {
        # SPRINT 2: Use centralized column update helper with state isolation
        standard_choices <- setNames(c("", col_names), c("V\u00e6lg kolonne...", col_names))
        ui_service$update_all_columns_from_state(
          choices = standard_choices,
          columns_state = columns_state,
          log_context = "UI_SYNC_UNIFIED"
        )
      }
    },
    fallback = NULL,
    session = session,
    error_type = "processing",
    emit = emit,
    app_state = app_state
  )
}

#' Update Column Choices (Unified Event Version)
#'
#' Unified version of column choice updates that handles
#' data changes through the event system.
#'
#' @param app_state The centralized app state
#' @param input Shiny input
#' @param output Shiny output
#' @param session Shiny session
#' @param reason Character string describing why the update is happening
#'
#' @noRd
update_column_choices_unified <- function(app_state, input, output, session, ui_service = NULL, reason = "manual") {
  log_debug_block("COLUMN_CHOICES_UNIFIED", "Starting column choices update")


  # Check if we should skip during table operations
  if (state_flag(app_state$data$updating_table)) {
    return()
  }

  # Skip if auto-detect is in progress
  if (state_flag(app_state$columns$auto_detect$in_progress)) {
    return()
  }

  # Skip if UI sync is needed (to avoid race conditions)
  if (state_flag(app_state$columns$ui_sync$needed)) {
    return()
  }

  # Get current data
  if (is.null(app_state$data$current_data)) {
    return()
  }

  data <- app_state$data$current_data
  all_cols <- names(data)
  log_debug_kv(
    available_columns = paste(all_cols, collapse = ", "),
    .context = "COLUMN_CHOICES_UNIFIED"
  )

  if (length(all_cols) > 0) {
    # Create column choices
    col_choices <- setNames(
      c("", all_cols),
      c("V\u00e6lg kolonne...", all_cols)
    )

    # Retain existing selections from both input and app_state
    columns_to_update <- c("x_column", "y_column", "n_column", "skift_column", "frys_column", "kommentar_column")
    current_selections <- list()

    normalize_selection_value <- function(value) {
      if (is.null(value)) {
        return(NULL)
      }

      if (length(value) == 0) {
        return("")
      }

      candidate <- value[[1]]
      if (is.null(candidate)) {
        return(NULL)
      }

      candidate_chr <- as.character(candidate)[1]

      if (length(candidate_chr) == 0) {
        return(NULL)
      }

      if (anyNA(candidate_chr)) {
        return("")
      }

      if (identical(candidate_chr, "")) {
        return("")
      }

      candidate_chr
    }

    non_empty_selection <- function(value) {
      if (!is.null(value) && nzchar(value)) value else NULL
    }

    for (col in columns_to_update) {
      if (identical(reason, "edit")) {
        tryCatch(
          {
            shiny::freezeReactiveValue(input, col)
          },
          error = function(...) NULL
        )
      }

      input_val <- tryCatch(input[[col]], error = function(...) NULL)
      normalized_input <- normalize_selection_value(input_val)

      cache_key <- paste0(col, "_input")
      cache_val_raw <- tryCatch(
        {
          if (!is.null(app_state$ui_cache)) {
            shiny::isolate(app_state$ui_cache[[cache_key]])
          } else {
            NULL
          }
        },
        error = function(...) NULL
      )
      cache_val <- normalize_selection_value(cache_val_raw)

      # FIX: Mappings ligger under app_state$columns$mappings$<col>, ikke
      # app_state$columns$<col>. Den forkerte sti gjorde at state-fallback
      # altid returnerede NULL under session restore og satte selected=""
      # paa selectize-inputs inden restore_metadata fik fyldt dem.
      state_val_raw <- tryCatch(
        shiny::isolate(app_state$columns$mappings[[col]]),
        error = function(...) NULL
      )
      state_val <- normalize_selection_value(state_val_raw)

      candidates <- if (identical(reason, "edit")) {
        list(normalized_input, cache_val)
      } else {
        list(
          non_empty_selection(normalized_input),
          non_empty_selection(cache_val),
          state_val
        )
      }

      selected_val <- NULL
      for (candidate in candidates) {
        if (!is.null(candidate)) {
          selected_val <- candidate
          break
        }
      }

      if (is.null(selected_val)) {
        selected_val <- ""
      }

      current_selections[[col]] <- selected_val
    }

    # Update UI controls using centralized service
    safe_operation(
      "Column choices UI update",
      code = {
        if (!is.null(ui_service)) {
          ui_service$update_column_choices(choices = col_choices, selected = current_selections)
        } else {
          # Fallback to direct updates with retained selections
          for (col in columns_to_update) {
            shiny::updateSelectizeInput(session, col, choices = col_choices, selected = current_selections[[col]])
          }
        }
      },
      fallback = NULL,
      session = session,
      error_type = "processing"
    )
  }
}
