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
#' Tracks viewport (plot container) dimensions and ensures cold-start renders
#' wait for a real browser layout measurement before producing a chart.
#'
#' Two complementary mechanisms (Issue #610):
#' \itemize{
#'   \item \strong{clientData observer} — keeps writing dimensions from
#'     `session$clientData` into `app_state$visualization$viewport_dims`.
#'     This preserves backward-compatible behavior (resize tracking,
#'     test environments where `mockclientdata` returns valid dims).
#'   \item \strong{viewport_ready signal} — gates `spc_inputs_raw` on the
#'     first real layout. The browser-side ResizeObserver
#'     (`inst/app/www/viewport-ready.js`) fires `input$viewport_ready` once
#'     `#visualization-spc_plot_actual` has dims > 100x100 px. This observer
#'     mirrors the measurement into `app_state` and flips the signal TRUE.
#'   \item \strong{Timeout fallback} — `later::later(fallback_delay_secs)`
#'     flips the signal TRUE even if the JS event never arrives (no
#'     ResizeObserver, headless tests, JS disabled), using clientData
#'     dimensions written by Observer 1 or `VIEWPORT_DEFAULTS`.
#' }
#'
#' Why both: clientData reports the CSS-default 800x600 immediately at
#' startup, before the browser has measured the actual layout. spc_inputs
#' needs to know when to start trusting the dimensions — that's the role
#' of `viewport_ready_signal`. The clientData observer is still useful
#' for resize tracking after first layout.
#'
#' @param app_state Reactive values object containing visualization state
#' @param session Shiny session object (for clientData access)
#' @param input Shiny input object (provides `viewport_ready` from JS)
#' @param ns Namespace function for output IDs
#' @param emit Emit API object from `create_emit_api(app_state)`, created once
#'   outside the observer to avoid recreating it on every reactive invalidation.
#' @param viewport_ready_signal `reactiveVal(FALSE)` flipped TRUE once a real
#'   measurement is available. `spc_inputs_raw` `req()`s on this.
#' @param fallback_delay_secs Seconds to wait before firing the timeout
#'   fallback. Default 2s (production). Tests may pass smaller values to
#'   exercise the fallback path quickly.
#' @param .scheduler Function with signature `function(callback, delay)`
#'   used to schedule the fallback timeout. Default `later::later`. Tests
#'   may inject a synchronous scheduler to drive the fallback deterministically.
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
  viewport_ready_signal,
  fallback_delay_secs = 2,
  .scheduler = later::later
) {
  # === Observer 1: clientData → app_state (legacy data source) ===
  # Continues writing dimensions on every clientData change so resize events
  # are tracked. testServer's mockclientdata exercises this path.
  shiny::observe({
    width <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_width")]]
    height <- session$clientData[[paste0("output_", ns("spc_plot_actual"), "_height")]]

    shiny::req(
      !is.null(width), !is.null(height),
      width > 100, height > 100
    )

    set_viewport_dims(app_state, width, height, emit)
  })

  # === Observer 2: input$viewport_ready → flip signal + write app_state ===
  # JS ResizeObserver fires this once the browser has a real layout. Until
  # this fires, `spc_inputs_raw` is gated and won't render the synthetic
  # 800x600 cold-start frame.
  shiny::observeEvent(input$viewport_ready, ignoreInit = FALSE, {
    payload <- input$viewport_ready
    if (is.null(payload) || !is.list(payload)) {
      return()
    }
    width <- payload$width
    height <- payload$height
    if (is.null(width) || is.null(height) || width <= 100 || height <= 100) {
      return()
    }

    set_viewport_dims(app_state, as.numeric(width), as.numeric(height), emit)
    viewport_ready_signal(TRUE)

    log_debug(
      sprintf("viewport_ready signal received: %dx%d", round(width), round(height)),
      .context = "VIEWPORT_DIMENSIONS"
    )
  })

  # === Fallback: later::later flips signal even without JS event ===
  # Critical for headless tests, environments without ResizeObserver, and
  # JS-disabled browsers (Issue #610 acceptance criterion: "No regression
  # for environments where clientData is unavailable"). Uses whatever
  # dimensions Observer 1 has already written to app_state, or VIEWPORT_DEFAULTS.
  .scheduler(
    function() {
      if (isTRUE(shiny::isolate(viewport_ready_signal()))) {
        return(invisible(NULL))
      }

      current <- shiny::isolate(app_state$visualization$viewport_dims)
      width <- current$width
      height <- current$height

      if (!is.null(width) && !is.null(height) && width > 100 && height > 100) {
        # Observer 1 already wrote a valid dimension — just flip the signal.
        log_warn(
          sprintf(
            "viewport_ready JS event missing after %ss — using clientData-derived dims: %dx%d",
            fallback_delay_secs, round(width), round(height)
          ),
          .context = "VIEWPORT_DIMENSIONS"
        )
      } else {
        # Nothing valid in app_state — use VIEWPORT_DEFAULTS.
        set_viewport_dims(
          app_state,
          VIEWPORT_DEFAULTS$width,
          VIEWPORT_DEFAULTS$height,
          emit
        )
        log_warn(
          sprintf(
            "viewport_ready JS event missing after %ss and clientData unavailable — using VIEWPORT_DEFAULTS: %dx%d",
            fallback_delay_secs, VIEWPORT_DEFAULTS$width, VIEWPORT_DEFAULTS$height
          ),
          .context = "VIEWPORT_DIMENSIONS"
        )
      }

      viewport_ready_signal(TRUE)
    },
    delay = fallback_delay_secs
  )

  invisible(NULL)
}
