# dev/run_dev.R
# Development entry point for SPC App
# Brug: source("dev/run_dev.R") fra RStudio eller terminal
#
# Denne fil indlaeser sibling-pakker (BFHtheme, BFHcharts, BFHllm)
# fra kildekode saa vi altid tester nyeste version under udvikling.
#
# For production: Se app.R (brugt af Posit Connect Cloud)

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

# remove.packages("BFHcharts")
# remove.packages("BFHtheme")
# remove.packages("BFHllm")
# 
# pak::pkg_install(c(
#   "johanreventlow/BFHtheme",
#   "johanreventlow/BFHcharts",
#   "johanreventlow/BFHllm"))

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
# =============================================================================
# RE-RENDER DIAGNOSE — trin 2/3 preview cascade-tracking
# =============================================================================
# Filtrer DEBUG til kontekster der afsloerer reactive-entry/exit, cache-hits,
# tab-gating, debounce-aktivitet og event-flow. Drop AI/RAG/SESSION-stoej.
set_debug_context(c(
  "EXPORT_MODULE",       # export_plot/pdf_export_plot reactive entry + render-gate
  "BACKEND_WRAPPER",     # generateSPCPlot CALLED
  "BFH_SERVICE",         # SPC compute + cached=TRUE/FALSE
  "BFH_TIMING",          # tidsforbrug pr compute
  "SPC_CACHE",           # cache hit/miss
  "QIC_CACHE",           # cache invalidation context
  "AUTO_SAVE",           # debounce-cascade
  "VIEWPORT_DIMENSIONS", # viewport_ready signal-timing
  "EVENT_SYSTEM",        # emit$ + listener-fire
  "FILE_UPLOAD_FLOW",    # paste/upload trigger-kilder
  "AUTO_DETECT_CACHE",   # autodetect re-runs
  "RENDER_PLOT",         # analyse-render entry
  "VISUALIZATION"        # plot_object reactive
))

# =============================================================================
# REACTLOG — fuld dependency-graf efter session
# =============================================================================
# Efter app-luk: kald shiny::reactlogShow() i konsol for visualisering.
# (reactlog::reactlog_show() kraever eksplicit log-argument; brug shiny-wrapperen.)
options(shiny.reactlog = TRUE)
if (requireNamespace("reactlog", quietly = TRUE)) {
  reactlog::reactlog_enable()
}

# =============================================================================
# SHINY-DIAGNOSTIK — trace + autoreload off (undgaa stoej + dobbelt-init)
# =============================================================================
options(shiny.trace = FALSE)        # saet TRUE for raw websocket-frames
options(shiny.autoreload = FALSE)
options(shiny.minified = FALSE)
options(shiny.fullstacktrace = TRUE)

# Browser-launch: RStudio viewer bruges automatisk i RStudio.
# Firefox via 'open' kan ramme race condition — brug manuelt besøg
# af URL'en fra konsollen, eller sæt TRUE for RStudio viewer.
# shiny::devmode(TRUE)
options(shiny.port = 8080)
options(shiny.launch.browser = TRUE)

# DEBUG-niveau for re-render diagnose. Skift tilbage til "INFO" naar faerdig.
run_app(enable_test_mode = FALSE, log_level = "DEBUG")
