# mod_app_guide_server.R
# Minimal server for app-vejledningsmodul

#' App Guide Module Server
#'
#' Minimal server logik for app-vejledningssiden.
#' Indholdet er statisk, s\u00e5 ingen reaktivitet er n\u00f8dvendig.
#'
#' @param id Module ID
#' @return NULL (ingen outputs)
#' @export
mod_app_guide_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    # Statisk indhold - ingen server-logik n\u00f8dvendig
    NULL
  })
}
