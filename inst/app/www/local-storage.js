// local-storage.js
// Browser localStorage integration for SPC App

// TTL-konfiguration: overskriver med window.SPC_LOCALSTORAGE_TTL_MINUTES
// hvis det er sat fra R-siden (via tags$script i app_ui.R).
// Default 480 minutter (8 timer) matcher klinisk arbejdsdag.
var SPC_LOCALSTORAGE_DEFAULT_TTL_MINUTES = 480;

function spc_get_ttl_minutes() {
  return (typeof window.SPC_LOCALSTORAGE_TTL_MINUTES === 'number' &&
    window.SPC_LOCALSTORAGE_TTL_MINUTES > 0)
    ? window.SPC_LOCALSTORAGE_TTL_MINUTES
    : SPC_LOCALSTORAGE_DEFAULT_TTL_MINUTES;
}

// TTL-check ved sideload: fjerner forældede sessioner fra delte hospitals-PC'er.
// Kaldes automatisk via $(document).ready() nedenfor.
function spc_expire_stale_sessions() {
  var sessionKey = 'spc_app_current_session';
  try {
    var raw = localStorage.getItem(sessionKey);
    if (!raw) return;
    var parsed = JSON.parse(raw);
    if (!parsed || !parsed.timestamp) return;
    var savedAt = new Date(parsed.timestamp).getTime();
    if (isNaN(savedAt)) return;
    var ageMinutes = (Date.now() - savedAt) / 60000;
    var ttl = spc_get_ttl_minutes();
    if (ageMinutes > ttl) {
      console.info(
        '[SPC] localStorage session udløbet (', Math.round(ageMinutes),
        'min > TTL', ttl, 'min). Rydder for at beskytte data på delt PC.'
      );
      localStorage.removeItem(sessionKey);
    }
  } catch(e) {
    // Parse-fejl: lad loadAppState håndtere cleanup
    console.warn('[SPC] TTL-check fejlede — ignorerer:', e.message);
  }
}

// Kør TTL-check så snart DOM er klar (før Shiny kalder loadAppState)
$(document).ready(function() {
  spc_expire_stale_sessions();
});

// Save data to localStorage with app prefix
// Note: `data` is already a JSON string from R's jsonlite::toJSON().
// We must NOT call JSON.stringify() here — doing so double-encodes the
// payload and breaks roundtrip parsing. See Issue #193.
window.saveAppState = function(key, data) {
  try {
    localStorage.setItem('spc_app_' + key, data);
    return true;
  } catch(e) {
    console.error('Failed to save to localStorage:', e);
    return false;
  }
};

// Load data from localStorage
// Issue #193: Ved parse-fejl (fx gammel double-encoded data fra tidligere
// version) rydder vi automatisk storage så brugeren ikke sidder fast i
// et brudt state. Næste gang bruger gemmer, starter de forfra med v2.0.
window.loadAppState = function(key) {
  var storageKey = 'spc_app_' + key;
  try {
    var data = localStorage.getItem(storageKey);
    if (data) {
      return JSON.parse(data);
    } else {
      return null;
    }
  } catch(e) {
    console.warn('[SPC] Corrupt localStorage entry detected, auto-clearing:', e.message);
    try {
      localStorage.removeItem(storageKey);
    } catch(cleanupErr) {
      console.error('[SPC] Failed to clean up corrupt entry:', cleanupErr);
    }
    return null;
  }
};

// Clear specific key from localStorage
window.clearAppState = function(key) {
  try {
    localStorage.removeItem('spc_app_' + key);
    return true;
  } catch(e) {
    console.error('Failed to clear localStorage:', e);
    return false;
  }
};

// Check if data exists in localStorage
window.hasAppState = function(key) {
  return localStorage.getItem('spc_app_' + key) !== null;
};
