# mod_landing_server.R
# Server logik for landing page

#' Landing Page Module Server
#'
#' Håndterer dynamisk rendering af landing page baseret på localStorage-peek.
#' Viser restore-card når en gemt session er tilgængelig, ellers default-landing.
#'
#' @param id Module ID
#' @param parent_session Shiny session. Parent session for navbar navigation og custom messages.
#' @param app_state Centraliseret app state. Bruges til at observere peek_result.
#' @return NULL
#' @keywords internal
mod_landing_server <- function(id, parent_session = NULL, app_state = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    # Dynamisk landing body — venter på peek_result fra JS/R peek-observer.
    # NULL = endnu ikke afklaret (viser ingenting for at undgå flash),
    # has_payload = FALSE → default-landing,
    # has_payload = TRUE  → restore-card med metadata.
    output$landing_body <- shiny::renderUI({
      ns <- session$ns

      if (is.null(app_state)) {
        return(landing_default_ui(ns))
      }

      peek_result <- app_state$session$peek_result

      # NULL = JS ikke loaded / peek ikke ankommet endnu → vis default landing
      # (JS-disabled fallback og initial render før sessioninitialized)
      if (is.null(peek_result)) {
        return(landing_default_ui(ns))
      }

      if (isTRUE(peek_result$has_payload)) {
        landing_restore_ui(ns, peek_result)
      } else {
        landing_default_ui(ns)
      }
    })

    # "Kom i gang" knap: vis navbar-trin og navigér til Upload
    shiny::observeEvent(input$start_wizard, {
      if (!is.null(parent_session)) {
        shinyjs::runjs("document.body.classList.add('wizard-nav-active');")
        bslib::nav_select("main_navbar", selected = "upload", session = parent_session)
      }
    })

    # Discoveryability-links: navigér til hjælpefanerne uden at aktivere wizard-nav
    shiny::observeEvent(input$goto_app_guide, {
      if (!is.null(parent_session)) {
        shinyjs::runjs("document.body.classList.add('wizard-nav-active');")
        bslib::nav_select("main_navbar", selected = "app_guide", session = parent_session)
      }
    })

    shiny::observeEvent(input$goto_spc, {
      if (!is.null(parent_session)) {
        shinyjs::runjs("document.body.classList.add('wizard-nav-active');")
        bslib::nav_select("main_navbar", selected = "hjaelp", session = parent_session)
      }
    })

    # Bruger vælger "Gendan session"
    shiny::observeEvent(input$restore_saved_session, {
      log_info("Bruger valgte at gendanne gemt session", .context = "SESSION_RESTORE")
      if (!is.null(parent_session)) {
        parent_session$sendCustomMessage("performSessionRestore", list())
      }
    })

    # Bruger vælger "Start ny session"
    shiny::observeEvent(input$discard_saved_session, {
      log_info("Bruger valgte at kassere gemt session og starte ny", .context = "SESSION_RESTORE")
      if (!is.null(parent_session)) {
        clearDataLocally(parent_session)
        parent_session$sendCustomMessage("discardPendingRestore", list())
      }
      if (!is.null(app_state)) {
        app_state$session$peek_result <- list(has_payload = FALSE)
      }
    })
  })
}
