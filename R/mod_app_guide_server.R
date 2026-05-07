# mod_app_guide_server.R
# Server for app-vejledningsmodul med tilbagenavigation

#' App Guide Module Server
#'
#' Server logik for app-vejledningssiden. Håndterer tilbagenavigation
#' til den tab brugeren kom fra.
#'
#' @param id Module ID
#' @param parent_session Shiny session. Parent session for navbar navigation.
#' @param app_state Centraliseret app state. Issue #532: tab-state læses fra
#'   app_state$navigation$previous_tab (tidligere passerede vi en separat
#'   reactiveVal).
#' @return NULL
#' @keywords internal
mod_app_guide_server <- function(id, parent_session = NULL, app_state = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    setup_help_back_navigation(input, parent_session, app_state)
  })
}
