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

# Load package
devtools::load_all(reset = TRUE, recompile = FALSE, helpers = FALSE)

# Optional: Show debug contexts and set filter before running app
# show_debug_contexts()
# set_debug_context(c("data", "ai", "cache", "qic"))  # Uncomment to filter
set_debug_context(c("RAG", "AI_METADATA", "AI_SUGGESTION", "GEMINI_API", "AI_CACHE", "EXPORT_MODULE"))
# set_debug_context(NULL)

# Run app with test mode enabled for development
run_app(enable_test_mode = TRUE, log_level = "DEBUG")
# run_app(enable_test_mode = FALSE, log_level = "INFO")
