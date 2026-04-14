// shiny-handlers.js
// Custom Shiny message handlers for SPC App
//
// K6 FIX: Remove console.log PHI leakage - sensitive session data should NOT be logged
// Production apps should never log full payloads that may contain patient health information

// Handler for saving app state via Shiny messages
// Issue #193: Rapporterer success/failure tilbage til R så server-side
// kan deaktivere auto-save ved quota-fejl eller andre persistente fejl.
Shiny.addCustomMessageHandler('saveAppState', function(message) {
  var dataLen = message.data ? message.data.length : 0;
  console.log('[SPC] saveAppState handler called, key:', message.key, 'size:', dataLen);
  var success = window.saveAppState(message.key, message.data);
  console.log('[SPC] saveAppState success:', success);
  if (success) {
    window._spcLastSaveTime = Date.now();
    _spcUpdateSaveElapsed();
  } else {
    console.error('saveAppState failed for key:', message.key);
  }
  Shiny.setInputValue('local_storage_save_result', {
    success: success,
    timestamp: new Date().toISOString(),
    key: message.key
  }, {priority: 'event'});
});

// Handler for loading app state via Shiny messages
Shiny.addCustomMessageHandler('loadAppState', function(message) {
  var data = window.loadAppState(message.key);
  Shiny.setInputValue('loaded_app_state', data, {priority: 'event'});
});

// Handler for clearing app state via Shiny messages
Shiny.addCustomMessageHandler('clearAppState', function(message) {
  var success = window.clearAppState(message.key);
  if (!success) {
    console.error('clearAppState failed for key:', message.key);
  }
});

// Aktivér wizard-mode (vis navbar-trin).
// Issue #193: Bruges af session restore til at skippe landing page
// når der er gemt data i localStorage. Placeret her i stedet for
// wizard-nav.js for at være uafhængig af wizard-nav.js loading status.
Shiny.addCustomMessageHandler('activate-wizard-mode', function(_message) {
  if (document.body) {
    document.body.classList.add('wizard-nav-active');
    console.log('[SPC] wizard-nav-active body class added');
  }
});

// Peek localStorage ved session-init og send kun metadata til R.
// Fuld payload caches i window.__pendingRestore — sendes først når bruger
// aktivt vælger "Gendan session" via performSessionRestore custom message.
// Issue #193 / brugerstyret restore.
$(document).on('shiny:sessioninitialized', function() {
  console.log('[SPC] shiny:sessioninitialized fired');
  var data = window.loadAppState('current_session');
  console.log('[SPC] localStorage peek: data present =', data !== null);
  if (data) {
    // Cache fuld payload — sendes til R først ved brugerens valg
    window.__pendingRestore = data;
    // Send kun metadata-subset til R (ingen PHI i log)
    Shiny.setInputValue('session_peek', {
      has_payload: true,
      version: data.version || null,
      timestamp: data.timestamp || null,
      nrows: (data.data && data.data.nrows) || null,
      ncols: (data.data && data.data.ncols) || null,
      indicator_title: (data.metadata && data.metadata.indicator_title) || '',
      active_tab: (data.metadata && data.metadata.active_tab) || null
    }, {priority: 'event'});
  } else {
    window.__pendingRestore = null;
    Shiny.setInputValue('session_peek', {has_payload: false}, {priority: 'event'});
  }
});

// Trigges af R når bruger klikker "Gendan session"
Shiny.addCustomMessageHandler('performSessionRestore', function(_message) {
  console.log('[SPC] performSessionRestore: sending cached payload to R');
  if (window.__pendingRestore) {
    Shiny.setInputValue('auto_restore_data', window.__pendingRestore, {priority: 'event'});
    window.__pendingRestore = null;
  } else {
    console.warn('[SPC] performSessionRestore called but no pending restore data');
  }
});

// Trigges af R når bruger klikker "Start ny session"
Shiny.addCustomMessageHandler('discardPendingRestore', function(_message) {
  console.log('[SPC] discardPendingRestore: clearing cached payload');
  window.__pendingRestore = null;
});

// Client-side save-elapsed timer (Issue #193)
// Opdaterer #save-elapsed-text hvert 5 s uden server-roundtrip,
// så Connect Cloud idle-timeout ikke holdes kunstigt i live.
// Ryddes ved session disconnect for at undgå interval-leak.
window._spcLastSaveTime = null;
window._spcElapsedInterval = null;

function _spcUpdateSaveElapsed() {
  var el = document.getElementById('save-elapsed-text');
  if (!el || !window._spcLastSaveTime) return;
  var sec = Math.round((Date.now() - window._spcLastSaveTime) / 1000);
  var label;
  if (sec < 60) {
    label = 'Session gemt \u00b7 ' + sec + ' s siden';
  } else if (sec < 3600) {
    label = 'Session gemt \u00b7 ' + Math.round(sec / 60) + ' min siden';
  } else {
    label = 'Session gemt \u00b7 tidligere';
  }
  el.textContent = label;
}

window._spcElapsedInterval = setInterval(_spcUpdateSaveElapsed, 5000);

$(document).on('shiny:disconnected', function() {
  if (window._spcElapsedInterval) {
    clearInterval(window._spcElapsedInterval);
    window._spcElapsedInterval = null;
  }
});

// Issue #185: Tilføj tooltips til Skift/Frys kolonne-headers i excelR tabel
// MutationObserver sikrer at tooltips tilføjes efter excelR rendering
(function() {
  var tooltipMap = {
    'Skift': 'Opdeler diagrammet i faser ved kendte proces\u00e6ndringer',
    'Frys': 'L\u00e5ser kontrolgr\u00e6nser baseret p\u00e5 en baseline-periode'
  };

  function addTableHeaderTooltips() {
    var headers = document.querySelectorAll('.jexcel > thead > tr > td');
    headers.forEach(function(td) {
      var text = (td.textContent || '').trim();
      if (tooltipMap[text] && !td.getAttribute('title')) {
        td.setAttribute('title', tooltipMap[text]);
        td.style.cursor = 'help';
      }
    });
  }

  var observer = new MutationObserver(function() {
    addTableHeaderTooltips();
  });

  $(document).on('shiny:sessioninitialized', function() {
    var target = document.getElementById('main_data_table');
    if (target) {
      observer.observe(target, { childList: true, subtree: true });
    }
    addTableHeaderTooltips();
  });
})();