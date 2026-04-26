# utils_ui_form_update_service.R
# Form-felt og feedback UI-opdateringer

#' Create Form Update Service
#'
#' Tynd closure der centraliserer form-felt opdateringer, reset,
#' validering og bruger-feedback. Kolonne-opdatering ved reset
#' delegeres til column_service.
#'
#' @param session Shiny session-objekt
#' @param app_state Centraliseret app state
#' @param column_service Valgfri column update service (brug ved reset)
#' @return Liste med form-update-funktioner
#'
#' @keywords internal
create_form_update_service <- function(session, app_state, column_service = NULL) {
  normalize_form_value <- function(value, default = "") {
    value <- sanitize_selection(value)
    if (is.null(value)) {
      return(default)
    }
    as.character(value[[1]])
  }

  normalize_number_value <- function(value, default = NA_real_) {
    value <- normalize_form_value(value, default = "")
    if (!nzchar(value)) {
      return(default)
    }
    suppressWarnings(as.numeric(value))
  }

  # Felter der opdateres ved session restore (komplet liste)
  .default_fields <- c(
    "indicator_title", "unit_select", "unit_custom", "indicator_description",
    "chart_type",
    "x_column", "y_column", "n_column",
    "skift_column", "frys_column", "kommentar_column",
    "target_value", "centerline_value", "y_axis_unit",
    "export_title", "export_hospital", "export_department", "export_footnote", "export_format",
    "pdf_description", "pdf_improvement",
    "png_width", "png_height"
  )

  # Intern helper: opdatér ét form-felt ud fra felttype (fanger session fra closure)
  .update_single_field <- function(field, value) {
    value <- normalize_form_value(value, default = "")

    if (field == "indicator_title") {
      shiny::updateTextInput(session, field, value = value)
    } else if (field == "unit_custom") {
      shiny::updateTextInput(session, field, value = value)
    } else if (field == "indicator_description") {
      shiny::updateTextAreaInput(session, field, value = value)
    } else if (field %in% c("target_value", "centerline_value")) {
      shiny::updateTextInput(session, field, value = value)
    } else if (field %in% c(
      "unit_select", "chart_type",
      "x_column", "y_column", "n_column",
      "skift_column", "frys_column", "kommentar_column",
      "y_axis_unit"
    )) {
      shiny::updateSelectizeInput(session, field, selected = value)
    } else if (field == "export_title") {
      shiny::updateTextAreaInput(session, "export-export_title", value = value)
    } else if (field == "export_hospital") {
      shiny::updateTextInput(session, "export-export_hospital", value = value)
    } else if (field == "export_department") {
      shiny::updateTextInput(session, "export-export_department", value = value)
    } else if (field == "export_footnote") {
      shiny::updateTextInput(session, "export-export_footnote", value = value)
    } else if (field == "export_format") {
      # export_format er hidden input — bruger JS custom message for synkronisering
      # (se Issue #193: updateTextInput virker ikke for hidden inputs)
      if (nzchar(value) && value %in% c("pdf", "png")) {
        session$sendCustomMessage("set-export-format", list(format = value))
      }
    } else if (field == "pdf_description") {
      shiny::updateTextAreaInput(session, "export-pdf_description", value = value)
    } else if (field == "pdf_improvement") {
      shiny::updateTextAreaInput(session, "export-pdf_improvement", value = value)
    } else if (field == "png_width") {
      shiny::updateNumericInput(session, "export-png_width", value = normalize_number_value(value))
    } else if (field == "png_height") {
      shiny::updateNumericInput(session, "export-png_height", value = normalize_number_value(value))
    }
  }

  # Opdatér form-felter fra metadata
  #
  # Bruges til session restore og metadata-indlæsning.
  # Wrappet i safe_programmatic_ui_update for at undgå race conditions
  # (se Issue #193: observers fyrer på halv state under restore).
  #
  # @param metadata Liste med feltværdier der skal opdateres
  # @param fields Vector af feltnavne. NULL = alle standard-felter
  #
  update_form_fields <- function(metadata, fields = NULL) {
    if (is.null(fields)) fields <- .default_fields

    safe_programmatic_ui_update(session, app_state, function() {
      safe_operation(
        "Update form fields from metadata",
        code = {
          for (field in fields) {
            if (!is.null(metadata[[field]])) {
              .update_single_field(field, metadata[[field]])
            }
          }
        },
        fallback = function(e) {
          log_error(paste("Error updating form fields:", e$message), "UI_SERVICE")
        },
        error_type = "processing"
      )
    })
  }

  # Nulstil form-felter til standard-værdier
  #
  # Bruges ved "Start ny session" og lignende reset-operationer.
  # Kolonne-choices ryddes via column_service (hvis angivet).
  #
  reset_form_fields <- function() {
    shiny::isolate({
      safe_operation(
        "Reset form fields to defaults",
        code = {
          shiny::updateTextInput(session, "indicator_title", value = "")
          shiny::updateTextAreaInput(session, "indicator_description", value = "")
          shiny::updateTextInput(session, "unit_custom", value = "")
          shiny::updateTextInput(session, "target_value", value = "")
          shiny::updateTextInput(session, "centerline_value", value = "")

          shiny::updateSelectizeInput(session, "unit_select", selected = "")
          shiny::updateSelectizeInput(session, "chart_type", selected = "run")
          shiny::updateSelectizeInput(session, "y_axis_unit", selected = "count")

          if (!is.null(column_service)) {
            column_service$update_column_choices(clear_selections = TRUE)
          }
        },
        fallback = function(e) {
          log_error(paste("Error resetting form fields:", e$message), "UI_SERVICE")
        },
        error_type = "processing"
      )
    })
  }

  # Vis/skjul UI-element
  #
  # @param element_id Elementets ID
  # @param show TRUE = vis, FALSE = skjul
  #
  toggle_ui_element <- function(element_id, show = TRUE) {
    safe_operation(
      paste("Toggle UI element", element_id),
      code = {
        if (show) {
          shinyjs::show(element_id)
        } else {
          shinyjs::hide(element_id)
        }
      },
      fallback = function(e) {
        log_error(paste("Error toggling element", element_id, ":", e$message), "UI_SERVICE")
      },
      error_type = "processing"
    )
  }

  # Validér form-felter med feedback
  #
  # @param field_rules Named list med valideringsregler per felt
  # @param show_feedback Vis fejl-styling i UI
  # @return Liste med valid (logical) og errors (named list)
  #
  validate_form_fields <- function(field_rules, show_feedback = TRUE) {
    validation_results <- list(valid = TRUE, errors = list())

    safe_operation(
      "Validate form fields",
      code = {
        for (field_name in names(field_rules)) {
          rule <- field_rules[[field_name]]
          field_value <- session$input[[field_name]]

          if (isTRUE(rule$required) && (is.null(field_value) || field_value == "")) {
            validation_results$valid <- FALSE
            validation_results$errors[[field_name]] <- "Dette felt er påkrævet"
            if (show_feedback) shinyjs::addClass(field_name, "has-error")
          }

          if (!is.null(rule$type) && rule$type == "numeric" &&
            !is.null(field_value) && field_value != "") {
            if (is.na(suppressWarnings(as.numeric(field_value)))) {
              validation_results$valid <- FALSE
              validation_results$errors[[field_name]] <- "Skal være et tal"
              if (show_feedback) shinyjs::addClass(field_name, "has-error")
            }
          }

          if (!is.null(rule$validator) && is.function(rule$validator)) {
            custom_result <- rule$validator(field_value)
            if (!isTRUE(custom_result)) {
              validation_results$valid <- FALSE
              validation_results$errors[[field_name]] <- custom_result
              if (show_feedback) shinyjs::addClass(field_name, "has-error")
            }
          }

          if (show_feedback && !field_name %in% names(validation_results$errors)) {
            shinyjs::removeClass(field_name, "has-error")
          }
        }
      },
      fallback = function(e) {
        log_error(paste("Error during form validation:", e$message), "UI_SERVICE")
        validation_results$valid <- FALSE
        validation_results$errors[["general"]] <- "Validationsfejl"
      },
      error_type = "processing"
    )

    validation_results
  }

  # Vis bruger-feedback (notification eller modal)
  #
  # @param message Besked til brugeren
  # @param type "success", "info", "warning" eller "error"
  # @param duration Sekunder (NULL = persistent)
  # @param modal TRUE = modal dialog i stedet for notification
  #
  show_user_feedback <- function(message, type = "info", duration = 3, modal = FALSE) {
    safe_operation(
      "Show user feedback",
      code = {
        if (modal) {
          shiny::showModal(shiny::modalDialog(
            title = switch(type,
              "success" = "Succes",
              "info" = "Information",
              "warning" = "Advarsel",
              "error" = "Fejl",
              "Information"
            ),
            message,
            easyClose = TRUE,
            footer = shiny::modalButton("OK")
          ))
        } else {
          shiny_type <- switch(type,
            "success" = "message",
            "info" = "default",
            "warning" = "warning",
            "error" = "error",
            "default"
          )
          shiny::showNotification(message, type = shiny_type, duration = duration)
        }
      },
      fallback = function(e) {
        log_error(paste("Error showing user feedback:", e$message), "UI_SERVICE")
      },
      error_type = "processing"
    )
  }

  # Opdatér UI betinget baseret på conditions-liste
  #
  # @param conditions Named list med condition-specs (condition, actions)
  #
  update_ui_conditionally <- function(conditions) {
    safe_operation(
      "Update UI conditionally",
      code = {
        for (condition_name in names(conditions)) {
          condition_spec <- conditions[[condition_name]]
          condition_met <- if (is.function(condition_spec$condition)) {
            condition_spec$condition()
          } else {
            condition_spec$condition
          }

          if (isTRUE(condition_met)) {
            if (!is.null(condition_spec$actions$show)) {
              for (element in condition_spec$actions$show) shinyjs::show(element)
            }
            if (!is.null(condition_spec$actions$hide)) {
              for (element in condition_spec$actions$hide) shinyjs::hide(element)
            }
            if (!is.null(condition_spec$actions$enable)) {
              for (element in condition_spec$actions$enable) shinyjs::enable(element)
            }
            if (!is.null(condition_spec$actions$disable)) {
              for (element in condition_spec$actions$disable) shinyjs::disable(element)
            }
            if (!is.null(condition_spec$actions$update)) {
              for (update_spec in condition_spec$actions$update) {
                do.call(update_spec$func, update_spec$args)
              }
            }
          }
        }
      },
      fallback = function(e) {
        log_error(paste("Error in conditional UI updates:", e$message), "UI_SERVICE")
      },
      error_type = "processing"
    )
  }

  list(
    update_form_fields = update_form_fields,
    reset_form_fields = reset_form_fields,
    toggle_ui_element = toggle_ui_element,
    validate_form_fields = validate_form_fields,
    show_user_feedback = show_user_feedback,
    update_ui_conditionally = update_ui_conditionally
  )
}
