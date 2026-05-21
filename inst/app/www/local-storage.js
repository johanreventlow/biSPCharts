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

// GDPR-gate: Persistens (save/load) kræver eksplicit cookie-samtykke.
// Sættes af cookie-consent.js. window._spcConsentGranted === true betyder
// brugeren har valgt "Acceptér alle" (binær consent-model). Andre værdier
// (false, undefined) blokerer save/load. clearAppState og hasAppState er
// IKKE gatede — de er nødvendige for revoke-flow + UI-feedback.
function _spcIsPersistenceAllowed() {
  return window._spcConsentGranted === true;
}

// Ryd alle spc_app_* keys UNDTAGEN spc_app_consent (samtykke-record)
// og spc_app_visitor_id (legacy). Kaldes ved consent-revoke for at
// forhindre at gammel data ligger tilbage efter brugeren har sagt nej.
window.clearAllAppData = function() {
  try {
    var preserved = ['spc_app_consent', 'spc_app_visitor_id',
      'spc_app_analytics_consent', 'spc_app_consent_version',
      'spc_app_consent_timestamp'];
    var toRemove = [];
    for (var i = 0; i < localStorage.length; i++) {
      var k = localStorage.key(i);
      if (k && k.indexOf('spc_app_') === 0 && preserved.indexOf(k) === -1) {
        toRemove.push(k);
      }
    }
    for (var j = 0; j < toRemove.length; j++) {
      localStorage.removeItem(toRemove[j]);
    }
    console.info('[SPC] Cleared', toRemove.length, 'app-state keys after consent revoke');
    return true;
  } catch (e) {
    console.error('[SPC] clearAllAppData failed:', e);
    return false;
  }
};

// Listen for consent-revoke: ryd app-data straks
document.addEventListener('spc:consent-decided', function(ev) {
  if (ev && ev.detail && ev.detail.granted === false) {
    window.clearAllAppData();
  }
});

// Save data to localStorage with app prefix
// Note: `data` is already a JSON string from R's jsonlite::toJSON().
// We must NOT call JSON.stringify() here — doing so double-encodes the
// payload and breaks roundtrip parsing. See Issue #193.
window.saveAppState = function(key, data) {
  if (!_spcIsPersistenceAllowed()) {
    console.debug('[SPC] saveAppState blocked: consent not granted');
    return false;
  }
  try {
    localStorage.setItem('spc_app_' + key, data);
    return true;
  } catch(e) {
    console.error('Failed to save to localStorage:', e);
    return false;
  }
};

window.updateAppStateMetadata = function(key, metadataJson, version) {
  if (!_spcIsPersistenceAllowed()) {
    console.debug('[SPC] updateAppStateMetadata blocked: consent not granted');
    return false;
  }

  var storageKey = 'spc_app_' + key;
  try {
    var raw = localStorage.getItem(storageKey);
    if (!raw) {
      console.warn('[SPC] updateAppStateMetadata failed: no existing app state');
      return false;
    }

    var payload = JSON.parse(raw);
    if (!payload || !payload.data) {
      console.warn('[SPC] updateAppStateMetadata failed: existing state has no data');
      return false;
    }

    payload.metadata = JSON.parse(metadataJson);
    payload.timestamp = new Date().toISOString();
    payload.version = version;

    localStorage.setItem(storageKey, JSON.stringify(payload));
    return true;
  } catch(e) {
    console.error('Failed to update localStorage metadata:', e);
    return false;
  }
};

// Load data from localStorage
// Issue #193: Ved parse-fejl (fx gammel double-encoded data fra tidligere
// version) rydder vi automatisk storage så brugeren ikke sidder fast i
// et brudt state. Næste gang bruger gemmer, starter de forfra med v2.0.
//
// IKKE consent-gated: landing-page peek skal kunne læse eksisterende
// localStorage-metadata for at vise "Gendan session"-prompt. Reading af
// allerede gemt data er ej "ny persistens" — full restore (auto_restore_data)
// gates separat via R-side require_consent_or_show_modal().
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

// Clear specific key from localStorage — IKKE consent-gated (skal virke
// for revoke-flow + bruger-initieret session-rydning).
window.clearAppState = function(key) {
  try {
    localStorage.removeItem('spc_app_' + key);
    return true;
  } catch(e) {
    console.error('Failed to clear localStorage:', e);
    return false;
  }
};

// Check if data exists — IKKE consent-gated (UI-feedback skal kunne vise
// status uafhængigt af consent, fx "du har en gemt session"-warning i modal).
window.hasAppState = function(key) {
  return localStorage.getItem('spc_app_' + key) !== null;
};
