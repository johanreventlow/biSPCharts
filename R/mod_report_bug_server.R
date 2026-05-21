# mod_report_bug_server.R
# Server for "Rapporter fejl"-modul med tilbagenavigation.

#' Report Bug Module Server
#'
#' Server logik for "Rapporter fejl"-siden. Haandterer tilbagenavigation
#' til den tab brugeren kom fra. Selve mailto-linket er statisk og kraever
#' ingen server-side processing.
#'
#' @param id Module ID.
#' @param parent_session Shiny session. Parent session for navbar navigation.
#' @param app_state Centraliseret app state. Tab-state laeses fra
#'   \code{app_state$navigation$previous_tab}.
#' @return NULL
#' @keywords internal
mod_report_bug_server <- function(id, parent_session = NULL, app_state = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    setup_help_back_navigation(input, parent_session, app_state)
  })
}
