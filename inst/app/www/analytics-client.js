// analytics-client.js
// Klient-side performance timing og metadata for analytics
// Aktiveres KUN naar bruger har givet consent

(function() {
  'use strict';

  var _analyticsActive = false;
  var _perfObserver = null;

  Shiny.addCustomMessageHandler('spc_start_analytics', function(_message) {
    if (_analyticsActive) return;
    _analyticsActive = true;
    collectInitialMetrics();
    setupPerformanceObservers();
  });

  Shiny.addCustomMessageHandler('spc_stop_analytics', function(_message) {
    if (!_analyticsActive) return;
    _analyticsActive = false;
    if (_perfObserver) {
      try { _perfObserver.disconnect(); } catch (e) { /* ignore */ }
      _perfObserver = null;
    }
    console.info('[SPC] Analytics tracking stoppet efter samtykke-tilbagetrækning');
  });

  function collectInitialMetrics() {
    if (document.readyState === 'complete') {
      sendPageLoadMetrics();
    } else {
      window.addEventListener('load', sendPageLoadMetrics);
    }
  }

  function sendPageLoadMetrics() {
    if (!_analyticsActive) return;
    try {
      var perf = performance.getEntriesByType('navigation')[0];
      if (!perf) return;
      Shiny.setInputValue('analytics_performance', {
        type: 'page_load',
        dns_ms: Math.round(perf.domainLookupEnd - perf.domainLookupStart),
        connect_ms: Math.round(perf.connectEnd - perf.connectStart),
        ttfb_ms: Math.round(perf.responseStart - perf.requestStart),
        dom_ready_ms: Math.round(perf.domContentLoadedEventEnd - perf.startTime),
        load_complete_ms: Math.round(perf.loadEventEnd - perf.startTime),
        timestamp: new Date().toISOString()
      }, {priority: 'event'});
    } catch (e) {
      console.warn('[SPC] Performance metrics fejlede:', e.message);
    }
  }

  function setupPerformanceObservers() {
    if (typeof PerformanceObserver === 'undefined') return;
    try {
      _perfObserver = new PerformanceObserver(function(list) {
        if (!_analyticsActive) return;
        list.getEntries().forEach(function(entry) {
          if (entry.name.startsWith('spc_')) {
            Shiny.setInputValue('analytics_performance', {
              type: entry.name,
              duration_ms: Math.round(entry.duration),
              timestamp: new Date().toISOString()
            }, {priority: 'event'});
          }
        });
      });
      _perfObserver.observe({entryTypes: ['measure']});
    } catch (e) {
      console.warn('[SPC] PerformanceObserver ikke tilgaengelig:', e.message);
      _perfObserver = null;
    }
  }

  window.spcMarkStart = function(name) {
    if (!_analyticsActive) return;
    try { performance.mark('spc_' + name + '_start'); }
    catch (e) { /* ignore */ }
  };

  window.spcMarkEnd = function(name) {
    if (!_analyticsActive) return;
    try {
      performance.mark('spc_' + name + '_end');
      performance.measure('spc_' + name, 'spc_' + name + '_start', 'spc_' + name + '_end');
    } catch (e) { /* ignore */ }
  };

})();
