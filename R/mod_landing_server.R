# mod_landing_server.R
# Server logik for landing page

#' Landing Page Module Server
#'
#' Håndterer "Kom i gang"-knap og logo-klik navigation.
#' Viser/skjuler navbar-trin via JavaScript.
#'
#' @param id Module ID
#' @param parent_session Shiny session. Parent session for navbar navigation.
#' @return NULL
#' @export
mod_landing_server <- function(id, parent_session = NULL) {
  shiny::moduleServer(id, function(input, output, session) {

    # "Kom i gang" knap: vis navbar-trin og navigér til Upload
    shiny::observeEvent(input$start_wizard, {
      if (!is.null(parent_session)) {
        # Vis wizard-trin og hjælp i navbar
        shinyjs::runjs("document.querySelectorAll('.navbar .nav-item.wizard-nav-item').forEach(function(el) { el.style.display = ''; });")
        bslib::nav_select("main_navbar", selected = "upload", session = parent_session)
      }
    })
  })
}
