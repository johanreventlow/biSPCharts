// analytics-client.js
// Klient-side performance timing og metadata for analytics
// Aktiveres KUN naar bruger har givet consent

(function() {
  'use strict';

  var _analyticsActive = false;

  Shiny.addCustomMessageHandler('spc_start_analytics', function(_message) {
    if (_analyticsActive) return;
    _analyticsActive = true;
    collectInitialMetrics();
    setupPerformanceObservers();
  });

  function collectInitialMetrics() {
    if (document.readyState === 'complete') {
      sendPageLoadMetrics();
    } else {
      window.addEventListener('load', sendPageLoadMetrics);
    }
  }

  function sendPageLoadMetrics() {
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
      var observer = new PerformanceObserver(function(list) {
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
      observer.observe({entryTypes: ['measure']});
    } catch (e) {
      console.warn('[SPC] PerformanceObserver ikke tilgaengelig:', e.message);
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
