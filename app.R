# app.R
# Production entry point for Posit Connect Cloud
# For lokal udvikling: brug source("dev/run_dev.R")

# Forhindre dobbelt-loading af R/ filer (pkgload haandterer dette)
options(shiny.autoload.r = FALSE)

# Load pakken fra source
pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)

# Production mode
options("golem.app.prod" = TRUE)

# Returner shinyApp objekt - Connect Cloud styrer livscyklus
shiny::shinyApp(
  ui = app_ui,
  server = app_server
)
