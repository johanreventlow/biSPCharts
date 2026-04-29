# app.R
# Production entry point for Posit Connect Cloud
# For lokal udvikling: brug source("dev/run_dev.R")
#
# Pakken er installeret som del af Connect-manifestet (source-bundle).
# pkgload bruges KUN i development-flow (dev/run_dev.R) og er i Suggests.

# Forhindre Shiny fra at auto-source R/ filer (pakken haandterer dette)
options(shiny.autoload.r = FALSE)

# Load installeret pakke — ingen pkgload::load_all() i production
library(biSPCharts)

# Production mode
options("golem.app.prod" = TRUE)

# Returner shinyApp objekt - Connect Cloud styrer livscyklus
shiny::shinyApp(
  ui = app_ui,
  server = app_server
)
