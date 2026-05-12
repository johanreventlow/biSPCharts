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
#' Registrerer også observers for Annullér- og Nulstil-knapper i modal.
#'
#' @param app_state Hierarchical reactiveValues (environment)
#' @param emit Emit-API fra create_emit_api()
#' @param session Shiny session
#' @param input Shiny input-object (til cancel- og confirm-observers)
#' @return Invisibly NULL (side-effect: registers observers)
#' @keywords internal
#' @noRd
setup_navigation_guard_listener <- function(app_state, emit, session, input) {
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

  # Cancel action — luk modal, gendan state
  shiny::observeEvent(
    input$nav_guard_cancel,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      shiny::removeModal(session = session)
      app_state$navigation$guard_pending_target <- NULL
      app_state$navigation$guard_modal_open <- FALSE
    }
  )

  # Confirm action — download (opt-in) + reset + naviger
  shiny::observeEvent(
    input$nav_guard_confirm,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      handle_nav_guard_confirm(app_state, emit, session, input)
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

#' Handle nav_guard_confirm action
#'
#' Hvis input$nav_guard_download er TRUE: bygger Excel-blob fra state,
#' sender til browser via sendCustomMessage("download_blob"), så reset.
#' Hvis FALSE: reset direkte. Begge paths kalder reset_to_empty_session
#' + nav_select til pending_target.
#'
#' @param app_state Hierarchical reactiveValues (environment)
#' @param emit Emit-API fra create_emit_api()
#' @param session Shiny session
#' @param input Shiny input-object
#' @keywords internal
#' @noRd
handle_nav_guard_confirm <- function(app_state, emit, session, input) {
  target <- shiny::isolate(app_state$navigation$guard_pending_target)
  download_first <- isTRUE(input$nav_guard_download)

  safe_operation(
    "Navigation guard confirm",
    code = {
      if (download_first) {
        blob <- build_spc_excel_blob(app_state, input)
        session$sendCustomMessage(
          "download_blob",
          list(
            filename = generate_spc_filename(app_state),
            data_b64 = base64enc::base64encode(blob),
            mime_type = paste0(
              "application/vnd.openxmlformats-officedocument.",
              "spreadsheetml.sheet"
            )
          )
        )
      }

      reset_to_empty_session(session, app_state, emit)

      session$sendCustomMessage(
        "set_in_app_navigating",
        list(value = TRUE)
      )

      bslib::nav_select(
        id = "main_navbar",
        selected = target,
        session = session
      )
      shiny::removeModal(session = session)

      app_state$navigation$guard_pending_target <- NULL
      app_state$navigation$guard_modal_open <- FALSE

      session$sendCustomMessage(
        "schedule_clear_in_app_navigating",
        list(delay_ms = 500)
      )
    },
    fallback = {
      shiny::showNotification(
        "Kunne ikke nulstille — prøv igen",
        type = "error", duration = 5
      )
      shiny::removeModal(session = session)
      app_state$navigation$guard_pending_target <- NULL
      app_state$navigation$guard_modal_open <- FALSE
    }
  )
}

#' Build in-memory Excel-blob fra current app_state
#'
#' Genbruger eksisterende build_spc_excel() (3-ark: Data + Indstillinger +
#' SPC-analyse) som returnerer en tempfil-sti. Læser bytes tilbage via
#' readBin og rydder op via on.exit.
#'
#' current_data bruges som original_data fordi det er det eneste tilgængelige
#' datasæt i nav-guard-flowet (ingen separat original ved dette tidspunkt).
#'
#' @param app_state Hierarchical reactiveValues
#' @param input Shiny input (kræves af collect_metadata)
#' @return Raw bytes — XLSX file content
#' @keywords internal
#' @noRd
build_spc_excel_blob <- function(app_state, input) {
  data <- shiny::isolate(app_state$data$current_data)
  metadata <- collect_metadata(input, app_state)

  temp_path <- build_spc_excel(
    data = data,
    metadata = metadata,
    qic_data = NULL,
    original_data = data,
    analysis_options = list()
  )
  on.exit(unlink(temp_path), add = TRUE)

  readBin(temp_path, what = "raw", n = file.info(temp_path)$size)
}

#' Generer brugervenligt filnavn til nav-guard download
#'
#' Format: "spc-data_YYYY-MM-DD_HHMMSS.xlsx"
#'
#' @param app_state Hierarchical reactiveValues (reserveret til fremtidig
#'   brug af file_info.name)
#' @return Character — filnavn
#' @keywords internal
#' @noRd
generate_spc_filename <- function(app_state) {
  ts <- format(Sys.time(), "%Y-%m-%d_%H%M%S")
  paste0("spc-data_", ts, ".xlsx")
}
