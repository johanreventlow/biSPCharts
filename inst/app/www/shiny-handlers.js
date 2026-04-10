// shiny-handlers.js
// Custom Shiny message handlers for SPC App
//
// K6 FIX: Remove console.log PHI leakage - sensitive session data should NOT be logged
// Production apps should never log full payloads that may contain patient health information

// Handler for saving app state via Shiny messages
// Issue #193: Rapporterer success/failure tilbage til R så server-side
// kan deaktivere auto-save ved quota-fejl eller andre persistente fejl.
Shiny.addCustomMessageHandler('saveAppState', function(message) {
  var success = window.saveAppState(message.key, message.data);
  if (!success) {
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

// Auto-load existing session data when Shiny session is fully initialized.
// Issue #193: Bruger 'shiny:sessioninitialized' event i stedet for setTimeout(500)
// — sidstnævnte var en gæt der kunne fyre før observer var registreret.
$(document).on('shiny:sessioninitialized', function() {
  if (window.hasAppState('current_session')) {
    var data = window.loadAppState('current_session');
    if (data) {
      Shiny.setInputValue('auto_restore_data', data, {priority: 'event'});
    }
  }
});