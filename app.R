# app.R
# Production entry point for Posit Connect Cloud
# For lokal udvikling: brug source("dev/run_dev.R")
pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
run_app()
