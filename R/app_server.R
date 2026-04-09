#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @export
app_server <- function(input, output, session) {
  # Pre-populate BFHcharts template med biSPCharts assets (fonts+images)
  # Nødvendigt fordi BFHcharts' GitHub repo ikke inkluderer disse filer.
  # bfh_export_pdf() bruger system.file() internt, saa assets skal
  # vaere i BFHcharts' installerede template-mappe.
  tryCatch({
    bfhc_tmpl <- system.file("templates/typst/bfh-template", package = "BFHcharts")
    if (nzchar(bfhc_tmpl) && dir.exists(bfhc_tmpl)) {
      inject_template_assets(bfhc_tmpl)
    }
  }, error = function(e) NULL)

  # Call the main server function directly (no more file dependencies!)
  main_app_server(input, output, session)
}