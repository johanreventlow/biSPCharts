# app.R
# Production entry point for Posit Connect Cloud
# For lokal udvikling: brug source("dev/run_dev.R")
#
# Connect Cloud installerer dependencies fra manifest.json::packages, men IKKE
# selve repo'et som pakke. pkgload::load_all() loader pakken fra source-bundlet
# uden installation. pkgload skal være i Imports (ikke Suggests) for at være
# installeret på Connect. Se docs/adr/ADR-019-production-entrypoint-pkgload.md.

# Forhindre Shiny fra at auto-source R/ filer (pkgload haandterer dette)
options(shiny.autoload.r = FALSE)

# Load pakken fra source-bundlet
pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)

# Production mode
options("golem.app.prod" = TRUE)

# Returner shinyApp objekt - Connect Cloud styrer livscyklus
# Bruger ::: fordi app_ui/app_server er @keywords internal og dermed ej i
# package-search-path efter pkgload::load_all(export_all = FALSE). Ref #481.
shiny::shinyApp(
  ui = biSPCharts:::app_ui,
  server = biSPCharts:::app_server
)
