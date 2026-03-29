# mod_help_server.R
# Minimal server for hjælpeside-modul

#' Help Module Server
#'
#' Minimal server logik for hjælpesiden.
#' Indholdet er statisk, så ingen reaktivitet er nødvendig.
#'
#' @param id Module ID
#' @return NULL (ingen outputs)
#' @export
mod_help_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    # Statisk indhold - ingen server-logik nødvendig
    NULL
  })
}
