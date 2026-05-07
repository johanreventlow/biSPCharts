# ==============================================================================
# mod_spc_chart_observers.R
# ==============================================================================
# OBSERVER MODULE FOR SPC CHART VISUALIZATION
#
# Purpose: Register and manage reactive observers that handle side effects
#          in the SPC chart module, including viewport dimension tracking,
#          state synchronization, and cache invalidation.
# ==============================================================================

#' Fallback delay before flipping `viewport_ready` if no JS event arrives.
#' @keywords internal
VIEWPORT_READY_FALLBACK_SECS <- 2

#' Register Viewport Dimension Observer
#'
#' Tracks viewport (plot container) dimensions and gates SPC analysis
#' cold-start render on a real browser layout measurement.
#'
#' Why both clientData and JS event: `session$clientData` reports the
#' CSS-default 800x600 immediately at startup, before the browser has
#' measured layout. The JS `ResizeObserver`
#' (`inst/app/www/viewport-ready.js`) fires `input$viewport_ready` only
#' once a real layout (>100x100 px) is measured, allowing
#' `spc_inputs_raw` to gate cold-start evaluation on
#' `app_state$visualization$viewport_ready`.
#'
#' @param app_state Reactive values object containing visualization state
#' @param session Shiny session object (for clientData access)
#' @param input Shiny input object (provides `viewport_ready` from JS)
#' @param ns Namespace function for output IDs
#' @param emit Emit API object from `create_emit_api(app_state)`, created once
#'   outside the observer to avoid recreating it on every reactive invalidation.
#' @param .scheduler Function with signature `function(callback, delay)` used
#'   to schedule the fallback timeout. Default `later::later`. Tests may
#'   inject a synchronous scheduler for deterministic execution.
#'
#' @return NULL (side effect: registers observer with Shiny)
#'
#' @keywords internal
register_viewport_observer <- function(
  app_state,
  session,
  input,
  ns,
  emit,
  .scheduler = later::later
) {
  # Observer 1: clientData -> app_state. Tracks resize events. testServer's
  # mockclientdata exercises this path.
  shiny::observe({
    width <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_width")]]
    height <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_height")]]

    shiny::req(
      !is.null(width), !is.null(height),
      width > 100, height > 100
    )

    set_viewport_dims(app_state, width, height, emit)
  })

  # Observer 2: JS ResizeObserver -> flip readiness gate + write app_state.
  # ignoreInit = FALSE so the observer is wired before the JS event arrives
  # (initial NULL is handled by the early-return guard below).
  shiny::observeEvent(input$viewport_ready, ignoreInit = FALSE, {
    payload <- input$viewport_ready
    if (!is.list(payload)) {
      return()
    }
    width <- payload$width
    height <- payload$height
    if (is.null(width) || is.null(height) || width <= 100 || height <= 100) {
      return()
    }

    set_viewport_dims(app_state, width, height, emit)
    app_state$visualization$viewport_ready <- TRUE

    log_debug(
      sprintf("viewport_ready signal received: %dx%d", round(width), round(height)),
      .context = LOG_CONTEXTS$ui$viewport
    )
  })

  # Fallback: flip the gate even if the JS event never arrives. Critical
  # for headless tests, environments without ResizeObserver, and JS-disabled
  # browsers (Issue #610 acceptance criterion).
  .scheduler(
    function() {
      if (isTRUE(shiny::isolate(app_state$visualization$viewport_ready))) {
        return(invisible(NULL))
      }

      current <- shiny::isolate(app_state$visualization$viewport_dims)
      width <- current$width
      height <- current$height
      have_dims <- !is.null(width) && !is.null(height) && width > 100 && height > 100

      if (!have_dims) {
        set_viewport_dims(
          app_state,
          VIEWPORT_DEFAULTS$width,
          VIEWPORT_DEFAULTS$height,
          emit
        )
        width <- VIEWPORT_DEFAULTS$width
        height <- VIEWPORT_DEFAULTS$height
      }

      log_warn(
        sprintf(
          "viewport_ready JS event missing after %ss \u2014 using %s: %dx%d",
          VIEWPORT_READY_FALLBACK_SECS,
          if (have_dims) "clientData-derived dims" else "VIEWPORT_DEFAULTS",
          round(width), round(height)
        ),
        .context = LOG_CONTEXTS$ui$viewport
      )

      app_state$visualization$viewport_ready <- TRUE
    },
    delay = VIEWPORT_READY_FALLBACK_SECS
  )

  invisible(NULL)
}
