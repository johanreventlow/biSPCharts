# ==============================================================================
# mod_spc_chart_observers.R
# ==============================================================================
# OBSERVER MODULE FOR SPC CHART VISUALIZATION
#
# Purpose: Register and manage reactive observers that handle side effects
#          in the SPC chart module, including viewport dimension tracking,
#          state synchronization, and cache invalidation.
#
# Extracted from: mod_spc_chart_server.R (Stage 5 of Phase 2c refactoring)
# Depends on: app_state (centralized Shiny state)
#            session (for clientData access)
#            set_viewport_dims (from utils_viewport_helpers.R)
# ==============================================================================

#' Register Viewport Dimension Observer
#'
#' Sets up an observer that tracks viewport (plot container) dimensions from
#' Shiny's clientData and updates the centralized app_state. This ensures
#' responsive font scaling uses actual browser dimensions, not defaults.
#'
#' @param app_state Reactive values object containing visualization state
#' @param session Shiny session object (for clientData access)
#' @param ns Namespace function for output IDs
#'
#' @return NULL (side effect: registers observer with Shiny)
#'
#' @details
#' Viewport observer flow:
#' 1. Reads session clientData for output dimensions
#' 2. Validates dimensions are non-null and greater than 100px
#' 3. Updates app_state visualization with viewport dimensions
#' 4. Emits viewport_changed event for downstream reactives
#'
#' Critical for:
#' - Responsive font scaling (base_size calculation uses viewport diagonal)
#' - Cache key generation (includes viewport dimensions)
#' - Label placement accuracy (requires accurate device dimensions)
#'
#' @keywords internal
register_viewport_observer <- function(app_state, session, ns) {
  shiny::observe({
    # Read viewport dimensions from clientData
    width <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_width")]]
    height <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_height")]]

    # GUARD: Require valid dimensions (prevent defaults from being cached)
    shiny::req(
      !is.null(width), !is.null(height),
      width > 100, height > 100
    )

    # Update centralized viewport state
    emit <- create_emit_api(app_state)
    set_viewport_dims(app_state, width, height, emit)
  })
}
