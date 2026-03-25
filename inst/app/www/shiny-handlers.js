// shiny-handlers.js
// Custom Shiny message handlers for SPC App

// K6 FIX: Remove console.log PHI leakage - sensitive session data should NOT be logged
// Production apps should never log full payloads that may contain patient health information

// Handler for saving app state via Shiny messages
Shiny.addCustomMessageHandler('saveAppState', function(message) {
  // K6: Removed console.log that exposed full message payload (PHI risk)
  var success = window.saveAppState(message.key, message.data);
  if (!success) {
    console.error('saveAppState failed for key:', message.key);
  }
});

// Handler for loading app state via Shiny messages
Shiny.addCustomMessageHandler('loadAppState', function(message) {
  // K6: Removed console.log that exposed full message payload (PHI risk)
  var data = window.loadAppState(message.key);
  Shiny.setInputValue('loaded_app_state', data, {priority: 'event'});
});

// Handler for clearing app state via Shiny messages
Shiny.addCustomMessageHandler('clearAppState', function(message) {
  // K6: Removed console.log that exposed full message payload (PHI risk)
  var success = window.clearAppState(message.key);
  if (!success) {
    console.error('clearAppState failed for key:', message.key);
  }
});

// Handler for showing app UI after loading
Shiny.addCustomMessageHandler('showAppUI', function(message) {
  window.showAppUI();
});

// Modal close detection — send Shiny input naar Bootstrap modal lukkes
// Erstatter later::later(1s) workaround i server_management.R
$(document).on('hidden.bs.modal', '.modal', function() {
  Shiny.setInputValue('modal_closed_event', Date.now(), {priority: 'event'});
});

// Auto-load existing session data on app start
$(document).ready(function() {
  if (window.hasAppState('current_session')) {
    setTimeout(function() {
      // K6: Removed console.log calls that exposed session data (PHI risk)
      // If debugging is needed, use a debug flag and redact sensitive fields
      var data = window.loadAppState('current_session');
      if (data) {
        Shiny.setInputValue('auto_restore_data', data, {priority: 'event'});
      }
    }, 500); // Wait for Shiny to be ready
  }
});