# mod_about_server.R
# Server for "Om os"-modul med tilbagenavigation.

#' About Module Server
#'
#' Server logik for "Om os"-siden. Haandterer tilbagenavigation til den
#' tab brugeren kom fra. Selve sidens indhold er statisk og kraever ingen
#' server-side processing.
#'
#' @param id Module ID.
#' @param parent_session Shiny session. Parent session for navbar navigation.
#' @param app_state Centraliseret app state. Tab-state laeses fra
#'   \code{app_state$navigation$previous_tab}.
#' @return NULL
#' @keywords internal
mod_about_server <- function(id, parent_session = NULL, app_state = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    setup_help_back_navigation(input, parent_session, app_state)

    # Intern navigation til hjaelpe-sider
    shiny::observeEvent(input$goto_help,
      priority = OBSERVER_PRIORITIES$STATUS_UPDATES,
      {
        if (!is.null(parent_session)) {
          bslib::nav_select("main_navbar", selected = "hjaelp", session = parent_session)
        }
      }
    )

    shiny::observeEvent(input$goto_report_bug,
      priority = OBSERVER_PRIORITIES$STATUS_UPDATES,
      {
        if (!is.null(parent_session)) {
          bslib::nav_select("main_navbar", selected = "rapporter_fejl", session = parent_session)
        }
      }
    )
  })
}
