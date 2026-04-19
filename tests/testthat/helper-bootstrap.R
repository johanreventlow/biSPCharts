# ==============================================================================
# helper-bootstrap.R
# ==============================================================================
# §2.4.2 — Package loading, shiny aliases, conditional setup.
#
# Sourced automatisk af testthat (filename-prefix "helper-" + load_all helpers).
# Denne fil håndterer ENTEN:
#   - Load biSPCharts package via pkgload::load_all()
#   - Fallback source() af essentielle R/-filer ved fejl
#   - Shiny-aliasing så tests kan bruge `reactive` i stedet for `shiny::reactive`
#
# Sibling-helpers:
#   - helper-fixtures.R: test-data + app_state-factories
#   - helper-mocks.R: kanoniske mocks for eksterne APIs
# ==============================================================================

library(testthat)

# ------------------------------------------------------------------------------
# Shiny aliases
# ------------------------------------------------------------------------------
# Gør core Shiny-funktioner tilgængelige uden library(shiny) i hver testfil.

isolate <- shiny::isolate
reactive <- shiny::reactive
reactiveValues <- shiny::reactiveValues
debounce <- shiny::debounce
updateSelectizeInput <- shiny::updateSelectizeInput
req <- shiny::req

# ------------------------------------------------------------------------------
# Package loading
# ------------------------------------------------------------------------------
# VIGTIGT: helper.R sourses af pkgload::load_all(helpers=TRUE), som er default.
# Hvis helper.R selv kalder pkgload::load_all(), opstår uendelig rekursion:
#   load_all() → source(helper.R) → load_all() → source(helper.R) → ...
# Hver iteration kører .onLoad() (~18s), så det ligner en uendelig hang.
#
# Løsning: Tjek om pakken allerede er loaded. Kald KUN load_all() hvis den
# IKKE allerede er loaded, og brug helpers=FALSE for at bryde rekursionen.

project_root <- here::here()

package_already_loaded <- function() {
  "biSPCharts" %in% loadedNamespaces()
}

if (!package_already_loaded()) {
  if (requireNamespace("pkgload", quietly = TRUE)) {
    tryCatch(
      {
        pkgload::load_all(project_root, quiet = TRUE, helpers = FALSE)
      },
      error = function(e) {
        message("pkgload failed, falling back to source-based loading: ", e$message)
        # Lightweight fallback — source kun essentielle filer
        essential_files <- c(
          "R/state_management.R",
          "R/utils_error_handling.R",
          "R/utils_server_performance.R",
          "R/fct_autodetect_helpers.R",
          "R/fct_autodetect_unified.R"
        )
        for (file_path in essential_files) {
          full_path <- file.path(project_root, file_path)
          if (file.exists(full_path)) {
            tryCatch(source(full_path, local = FALSE), error = function(e) {
              message("Failed to source ", file_path, ": ", e$message)
            })
          }
        }
      }
    )
  }
}

# Conditional source af ekstra helpers hvis pkgload ikke eksporterede dem
conditionally_source_helpers <- function() {
  helper_functions <- c("observer_manager", "create_empty_session_data")
  functions_missing <- !sapply(helper_functions, exists, mode = "function")

  if (any(functions_missing)) {
    additional_helper_files <- c(
      "R/utils_observer_management.R",
      "R/utils_server_session_helpers.R",
      "R/utils_server_server_management.R"
    )
    for (file_path in additional_helper_files) {
      full_path <- file.path(project_root, file_path)
      if (file.exists(full_path)) {
        tryCatch(
          source(full_path, local = FALSE),
          error = function(e) {
            message("Failed to source helper ", file_path, ": ", e$message)
          }
        )
      }
    }
  }
}

conditionally_source_helpers()
