# app.R
# Development entry point for SPC App

# ==============================================================================
# DEBUG CONTEXT FILTERING - Reduce token usage when debugging
# ==============================================================================
# Usage:
#   show_debug_contexts()  # See all available contexts organized by category
#   set_debug_context(c("state", "data", "ai"))  # Filter to specific areas
#   set_debug_context(NULL)  # Reset to log everything (default)
#
# Example use cases:
#   set_debug_context(c("AI_METADATA", "AI_SUGGESTION", "GEMINI_API"))  # Debug AI
#   set_debug_context(c("EXPORT_MODULE"))  # Debug PDF export
#   set_debug_context(c("UNIFIED_AUTODETECT", "AUTO_DETECT_CACHE", "COLUMN_SCORING"))
#   set_debug_context(c("RENDER_PLOT", "Y_AXIS_SCALING", "VISUALIZATION"))
#
# See docs/DEBUG_CONTEXTS_QUICK_REFERENCE.md for complete list of all contexts
# ==============================================================================

# ==============================================================================
# DEV-LOADING AF SIBLING-PAKKER
# ==============================================================================
# Indlaeser BFHtheme, BFHcharts og BFHllm fra kildekode (sibling-mapper)
# saa vi altid tester nyeste version under udvikling.
# Raekkefoelge: BFHtheme -> BFHcharts -> BFHllm -> biSPCharts (dependency order)
# ==============================================================================
dev_load_siblings <- function(base_path = dirname(getwd())) {
  siblings <- list(
    BFHtheme  = file.path(base_path, "BFHtheme"),
    BFHcharts = file.path(base_path, "BFHcharts"),
    BFHllm    = file.path(base_path, "BFHllm")
  )

  for (pkg_name in names(siblings)) {
    pkg_path <- siblings[[pkg_name]]
    if (dir.exists(pkg_path)) {
      message(sprintf("[DEV] Indlaeser %s fra %s", pkg_name, pkg_path))
      devtools::load_all(pkg_path, quiet = TRUE)
    } else {
      message(sprintf("[DEV] %s ikke fundet i %s - bruger installeret version", pkg_name, pkg_path))
    }
  }
}

dev_load_siblings()

# Load biSPCharts
devtools::load_all(helpers = FALSE)

# Optional: Show debug contexts and set filter before running app
# show_debug_contexts()
# set_debug_context(c("data", "ai", "cache", "qic"))  # Uncomment to filter
# set_debug_context(c("data", "ai", "cache", "qic", "RAG", "AI_METADATA", "AI_SUGGESTION", "GEMINI_API", "AI_CACHE", "EXPORT_MODULE", "BFH_SERVICE", "BFH_TIMING"))
# set_debug_context(c("RAG", "AI_METADATA", "AI_SUGGESTION", "GEMINI_API", "AI_CACHE", "EXPORT_MODULE"))
# set_debug_context(c("EXPORT_MODULE"))
# set_debug_context(c("RAG", "AI_METADATA", "AI_SUGGESTION", "GEMINI_API", "AI_CACHE"))
set_debug_context(NULL)

# Run app with test mode enabled for development

# Browser-launch: RStudio viewer bruges automatisk i RStudio.
# Firefox via 'open' kan ramme race condition — brug manuelt besøg
# af URL'en fra konsollen, eller sæt TRUE for RStudio viewer.
shiny::devmode(TRUE)
options(shiny.port = 8080)
options(shiny.launch.browser = TRUE)
# run_app(enable_test_mode = FALSE, log_level = "DEBUG")
run_app(enable_test_mode = FALSE, log_level = "INFO")
