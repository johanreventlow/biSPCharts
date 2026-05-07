// viewport-ready.js
// Issue #610: First-layout gating for SPC analysis chart.
//
// Shiny's session$clientData reports the CSS-default container size
// (800x600 for renderPlot) immediately at startup, before the browser
// has measured the actual layout. This causes spc_inputs_raw to fire
// with synthetic dimensions, producing a doubled analysis render
// (first at 800x600, then at the real viewport).
//
// This module fires a single Shiny.setInputValue("visualization-viewport_ready", ...)
// once the browser has reported a real layout for #visualization-spc_plot_actual,
// allowing the server-side reactive chain to gate cold-start evaluation
// until real dimensions are known.
//
// Fallback: if ResizeObserver is unavailable or the element never reaches
// a real size, the server-side timeout (later::later(2s)) takes over.

(function () {
  'use strict';

  // Module ID hardcoded — visualizationModuleServer always called with
  // id = "visualization" (see R/utils_server_visualization.R:163).
  var TARGET_INPUT_ID = 'visualization-viewport_ready';
  var TARGET_ELEMENT_ID = 'visualization-spc_plot_actual';

  // Minimum dimension to treat as "real layout" — anything smaller is
  // either still hidden (display:none returns 0) or a transient state.
  var MIN_DIM_PX = 100;

  function sendReady(width, height) {
    if (typeof Shiny === 'undefined' || !Shiny.setInputValue) {
      return false;
    }
    Shiny.setInputValue(
      TARGET_INPUT_ID,
      {
        width: Math.round(width),
        height: Math.round(height),
        ts: Date.now()
      },
      { priority: 'event' }
    );
    console.log('[VIEWPORT_READY] fired', { width: Math.round(width), height: Math.round(height) });
    return true;
  }

  function attachObserver() {
    var el = document.getElementById(TARGET_ELEMENT_ID);
    if (!el) {
      // Element not yet rendered — Shiny may not have created the
      // namespaced output container yet. Retry on next animation frame.
      window.requestAnimationFrame(attachObserver);
      return;
    }

    // If ResizeObserver is unavailable (very old browsers, headless tests
    // without ResizeObserver polyfill), measure synchronously once and let
    // the server-side timeout fallback handle re-measure.
    if (typeof window.ResizeObserver !== 'function') {
      console.warn('[VIEWPORT_READY] ResizeObserver unavailable, sending one-shot measurement');
      var rect = el.getBoundingClientRect();
      if (rect.width > MIN_DIM_PX && rect.height > MIN_DIM_PX) {
        sendReady(rect.width, rect.height);
      }
      // No retry — server-side timeout will fall back if this fails.
      return;
    }

    var fired = false;
    var observer = new ResizeObserver(function (entries) {
      if (fired) return;
      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        var box = entry.contentRect;
        if (box.width > MIN_DIM_PX && box.height > MIN_DIM_PX) {
          if (sendReady(box.width, box.height)) {
            fired = true;
            observer.disconnect();
            break;
          }
        }
      }
    });

    observer.observe(el);

    // Belt-and-suspenders: if the observer hasn't fired within 1500 ms
    // (e.g., element hidden behind tab), measure synchronously and send
    // best-effort. Server-side timeout (2 s) is the ultimate fallback.
    setTimeout(function () {
      if (fired) return;
      var rect = el.getBoundingClientRect();
      if (rect.width > MIN_DIM_PX && rect.height > MIN_DIM_PX) {
        if (sendReady(rect.width, rect.height)) {
          fired = true;
          observer.disconnect();
        }
      }
    }, 1500);
  }

  $(document).on('shiny:sessioninitialized', function () {
    // Defer until after Shiny binds outputs so the namespaced container
    // exists in the DOM.
    window.requestAnimationFrame(attachObserver);
  });
})();
