#' The application server-side
#'
#' @param input,output,session Internal parameters for \pkg{shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @keywords internal
app_server <- function(input, output, session) {
  # Font/image assets injiceres nu via:
  # - bfh_export_pdf(inject_assets = inject_template_assets) for PDF-eksport
  # - generate_pdf_preview() for PDF preview
  # Begge bruger temp-mapper, så read-only package dirs er ikke et problem.

  # Call the main server function directly (no more file dependencies!)
  main_app_server(input, output, session)
}