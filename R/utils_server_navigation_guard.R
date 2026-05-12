# utils_server_navigation_guard.R
#
# Navigation guard for trin 2/3 -> trin 1/forside.
# Vises modal hvis app_state$data$current_data findes; ellers direct nav.
#
# Spec: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md

#' Setup navigation guard listener
#'
#' Lytter på `emit$navigation_requested()`. Hvis data findes, vises modal
#' med valgmulighed for download + reset. Hvis ikke, navigeres direkte.
#'
#' @param app_state Hierarchical reactiveValues (environment)
#' @param emit Emit-API fra create_emit_api()
#' @param session Shiny session
#' @return Invisibly NULL (side-effect: registers observers)
#' @keywords internal
#' @noRd
setup_navigation_guard_listener <- function(app_state, emit, session) {
  # Primary listener — fires when emit$navigation_requested() called
  shiny::observeEvent(
    app_state$events$navigation_requested,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      target <- shiny::isolate(app_state$navigation$guard_pending_target)

      # Race-guard: ignore if modal already open
      if (isTRUE(shiny::isolate(app_state$navigation$guard_modal_open))) {
        return(invisible(NULL))
      }

      data_present <- !is.null(shiny::isolate(app_state$data$current_data)) &&
        nrow(shiny::isolate(app_state$data$current_data)) > 0

      if (!data_present) {
        # Empty session — direct navigation
        bslib::nav_select(
          id = "main_navbar",
          selected = target,
          session = session
        )
        app_state$navigation$guard_pending_target <- NULL
        return(invisible(NULL))
      }

      # Data present — show modal (implemented in Task 4)
      app_state$navigation$guard_modal_open <- TRUE
      shiny::showModal(navigation_guard_modal(), session = session)
    }
  )

  invisible(NULL)
}

#' Build navigation guard modal-dialog
#'
#' Vises når brugeren forsøger destruktiv navigation fra trin 2/3.
#' 2 knapper (Annullér / Nulstil) + checkbox til download-opt-in.
#'
#' @return shiny::modalDialog
#' @keywords internal
#' @noRd
navigation_guard_modal <- function() {
  shiny::modalDialog(
    title = "Forlad arbejde og start forfra?",
    shiny::tagList(
      shiny::tags$p("Du har data + indstillinger på arbejdsbordet."),
      shiny::tags$p(
        "Vil du starte forfra uden gemte ændringer?",
        " Du kan ikke fortryde denne handling."
      ),
      shiny::checkboxInput(
        inputId = "nav_guard_download",
        label = "Download kopi af data + indstillinger først",
        value = FALSE
      )
    ),
    footer = shiny::tagList(
      shiny::actionButton(
        inputId = "nav_guard_cancel",
        label = "Annullér"
      ),
      shiny::actionButton(
        inputId = "nav_guard_confirm",
        label = "Nulstil",
        class = "btn btn-danger"
      )
    ),
    size = "m",
    easyClose = FALSE,
    fade = TRUE
  )
}
