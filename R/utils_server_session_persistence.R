# Session persistence helpers.

state_flag <- function(value, default = FALSE) {
  if (is.null(value) || length(value) == 0 || anyNA(value)) {
    return(default)
  }
  isTRUE(value[[1]])
}

register_session_save_status_output <- function(output, app_state) {
  output$session_save_status <- shiny::renderUI({
    has_saved <- !is.null(get_last_save_time(app_state))
    auto_save_on <- is_auto_save_enabled(app_state)

    if (isFALSE(auto_save_on)) {
      return(shiny::span(
        shiny::icon("triangle-exclamation"),
        " Automatisk lagring deaktiveret",
        style = paste0("color: ", get_hospital_colors()$danger, "; font-size: 0.8rem;"),
        title = "Browseren har ikke plads til mere. Din data er stadig i appen."
      ))
    }

    if (!has_saved) {
      return(NULL)
    }

    shiny::span(
      shiny::icon("check"),
      " ",
      shiny::span(id = "save-elapsed-text", "Session gemt"),
      style = paste0("color: ", get_hospital_colors()$lightgrey, "; font-size: 0.8rem;"),
      title = "Indstillinger og data gemmes automatisk i din browser"
    )
  })
}

register_local_storage_save_result_observer <- function(input, obs_manager, app_state) {
  obs_save_result <- shiny::observeEvent(input$local_storage_save_result, {
    result <- input$local_storage_save_result
    if (is.null(result)) {
      return()
    }

    log_info(
      sprintf("localStorage save result: success=%s", isTRUE(result$success)),
      .context = "LOCAL_STORAGE"
    )

    if (isTRUE(result$success)) {
      set_last_save_time(app_state)
    } else {
      log_warn("localStorage save failed (quota or permission)", .context = "AUTO_SAVE")
      set_auto_save_enabled(app_state, FALSE)
      shiny::showNotification(
        paste0(
          "Browseren kan ikke gemme mere data (lokal lagerplads fuld). ",
          "Automatisk lagring er deaktiveret for denne session."
        ),
        type = "warning",
        duration = 8
      )
    }
  })

  if (!is.null(obs_manager)) {
    obs_manager$add(obs_save_result, "local_storage_save_result")
  }

  invisible(obs_save_result)
}
