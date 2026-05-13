# utils_server_navigation_guard.R
#
# Navigation guard for trin 2/3 -> trin 1/forside.
# Vises modal hvis app_state$data$current_data findes; ellers direct nav.
#
# Spec: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md # nolint: commented_code_linter.

#' Setup navigation guard listener
#'
#' Lytter p\u00e5 `emit$navigation_requested()`. Hvis data findes, vises modal
#' med valgmulighed for download + reset. Hvis ikke, navigeres direkte.
#' Registrerer ogs\u00e5 observers for Annull\u00e9r- og Nulstil-knapper i modal.
#'
#' @param app_state Hierarchical reactiveValues (environment)
#' @param emit Emit-API fra create_emit_api()
#' @param session Shiny session
#' @param input Shiny input-object (til cancel- og confirm-observers)
#' @return Invisibly NULL (side-effect: registers observers)
#' @keywords internal
#' @noRd
setup_nav_guard_listener <- function(app_state, emit, session, input) {
  # Primary listener \u2014 fires when emit$navigation_requested() called
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

      data_present <- has_real_data(app_state)

      if (!data_present) {
        # Empty session \u2014 direct navigation
        bslib::nav_select(
          id = "main_navbar",
          selected = target,
          session = session
        )
        app_state$navigation$guard_pending_target <- NULL
        return(invisible(NULL))
      }

      # Data present \u2014 show modal (implemented in Task 4)
      app_state$navigation$guard_modal_open <- TRUE
      shiny::showModal(navigation_guard_modal(), session = session)
    }
  )

  # Cancel action \u2014 luk modal, gendan state
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

  # Confirm action \u2014 download (opt-in) + reset + naviger
  shiny::observeEvent(
    input$nav_guard_confirm,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      handle_nav_guard_confirm(app_state, emit, session, input)
    }
  )

  # Push has_data-flag to JS on every current_data / file_uploaded change.
  # Explicit reactive deps: lookup begge felter direkte saa reactive system
  # tracker dem (has_real_data() bruger isolate internt).
  shiny::observe({
    # Force reactive deps
    invisible(app_state$data$current_data)
    invisible(app_state$session$file_uploaded)

    has_data <- has_real_data(app_state)
    app_state$navigation$guard_has_data_flag <- has_data
    session$sendCustomMessage(
      type = "nav_guard_has_data_update",
      message = list(value = has_data)
    )
  })

  # Server-side relay: JS-trigger -> emit
  shiny::observeEvent(
    input$nav_guard_trigger,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      trigger <- input$nav_guard_trigger
      if (!is.list(trigger) || is.null(trigger$target)) {
        return(invisible(NULL))
      }
      emit$navigation_requested(trigger$target)
    }
  )

  # Server-side guard: detect destruktiv tab-transition (trin 2/3 -> start/upload)
  # uafhaengigt af JS-intercept. Primaer guard — robust mod bslib's egne
  # event-handlers + Bootstrap's tab-switch-internals. Bruger priority
  # STATE_MANAGEMENT + 1 saa den fyrer FOER main_navbar-tracker (priority
  # STATE_MANAGEMENT) i app_server_main.R og kan laese OLD current_tab.
  shiny::observeEvent(
    input$main_navbar,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT + 1L,
    {
      current <- input$main_navbar
      prev <- shiny::isolate(app_state$navigation$current_tab)

      # Konsumer + clear revert-flag (sat af os i forrige fire)
      if (isTRUE(shiny::isolate(app_state$navigation$guard_reverting))) {
        app_state$navigation$guard_reverting <- FALSE
        return(invisible(NULL))
      }

      # Skip under aktiv confirm-flow (handle_nav_guard_confirm styrer selv)
      if (isTRUE(shiny::isolate(app_state$navigation$guard_active))) {
        return(invisible(NULL))
      }

      # Skip hvis modal allerede vises
      if (isTRUE(shiny::isolate(app_state$navigation$guard_modal_open))) {
        return(invisible(NULL))
      }

      leaving_wizard <- isTRUE(prev %in% c("analyser", "eksporter"))
      going_destructive <- isTRUE(current %in% c("start", "upload"))

      if (leaving_wizard && going_destructive && has_real_data(app_state)) {
        # Revert tab visuelt + emit guard. nav_select trigger ny main_navbar-
        # input-event som guard_reverting-flagget konsumerer ovenfor.
        app_state$navigation$guard_reverting <- TRUE
        bslib::nav_select(
          "main_navbar",
          selected = prev,
          session = session
        )
        emit$navigation_requested(current)
      }
    }
  )

  invisible(NULL)
}

#' Build navigation guard modal-dialog
#'
#' Vises n\u00e5r brugeren fors\u00f8ger destruktiv navigation fra trin 2/3.
#' 2 knapper (Annull\u00e9r / Nulstil) + checkbox til download-opt-in.
#'
#' @return shiny::modalDialog
#' @keywords internal
#' @noRd
navigation_guard_modal <- function() {
  shiny::modalDialog(
    title = "Forlad arbejde og start forfra?",
    shiny::tagList(
      shiny::tags$p("Du har data + indstillinger p\u00e5 arbejdsbordet."),
      shiny::tags$p(
        "Vil du starte forfra uden gemte \u00e6ndringer?",
        " Du kan ikke fortryde denne handling."
      ),
      shiny::checkboxInput(
        inputId = "nav_guard_download",
        label = "Download kopi af data + indstillinger f\u00f8rst",
        value = FALSE
      )
    ),
    footer = shiny::tagList(
      shiny::actionButton(
        inputId = "nav_guard_cancel",
        label = "Nej, bliv her"
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
#' sender til browser via sendCustomMessage("download_blob"), s\u00e5 reset.
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

      # Veto wizard_gates' data_updated auto-nav under reset:
      # ellers ser observeren empty session-data som "has_data" og
      # nav_select("analyser") overskriver target nedenfor.
      app_state$navigation$guard_active <- TRUE

      reset_to_empty_session(session, app_state, emit)

      # Wizard_gates' wizard-step-messages er skippet via guard_active.
      # Send selv korrekte lock-states post-reset for UI-konsistens.
      session$sendCustomMessage("wizard-uncomplete-step", 1)
      session$sendCustomMessage("wizard-lock-step", 2)
      session$sendCustomMessage("wizard-lock-step", 3)

      session$sendCustomMessage(
        "set_in_app_navigating",
        list(value = TRUE)
      )

      bslib::nav_select(
        id = "main_navbar",
        selected = target,
        session = session
      )

      # paste-textarea ryddes inde i reset_to_empty_session() \u2014 uafhaengig
      # af target, saa bruger ikke moeder stale data ved senere trin 1-besoeg.

      shiny::removeModal(session = session)

      app_state$navigation$guard_pending_target <- NULL
      app_state$navigation$guard_modal_open <- FALSE

      session$sendCustomMessage(
        "schedule_clear_in_app_navigating",
        list(delay_ms = 500)
      )

      # Clear guard_active EFTER Shiny-flush, saa wizard_gates' observer
      # (queued af emit$data_updated under reset) ser flagget TRUE og skipper.
      session$onFlushed(
        function() {
          shiny::isolate({
            app_state$navigation$guard_active <- FALSE
          })
        },
        once = TRUE
      )
    },
    fallback = {
      shiny::showNotification(
        "Kunne ikke nulstille \u2014 pr\u00f8v igen",
        type = "error", duration = 5
      )
      shiny::removeModal(session = session)
      app_state$navigation$guard_pending_target <- NULL
      app_state$navigation$guard_modal_open <- FALSE
      app_state$navigation$guard_active <- FALSE
    }
  )
}

#' Build in-memory Excel-blob fra current app_state
#'
#' Genbruger eksisterende build_spc_excel() (3-ark: Data + Indstillinger +
#' SPC-analyse) som returnerer en tempfil-sti. L\u00e6ser bytes tilbage via
#' readBin og rydder op via on.exit.
#'
#' current_data bruges som original_data fordi det er det eneste tilg\u00e6ngelige
#' datas\u00e6t i nav-guard-flowet (ingen separat original ved dette tidspunkt).
#'
#' @param app_state Hierarchical reactiveValues
#' @param input Shiny input (kr\u00e6ves af collect_metadata)
#' @return Raw bytes \u2014 XLSX file content
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
#' @return Character \u2014 filnavn
#' @keywords internal
#' @noRd
generate_spc_filename <- function(app_state) {
  ts <- format(Sys.time(), "%Y-%m-%d_%H%M%S")
  paste0("spc-data_", ts, ".xlsx")
}
