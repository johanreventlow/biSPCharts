// local-storage.js
// Browser localStorage integration for SPC App
//
// Issue #528: Transparent AES-GCM-256-kryptering af localStorage payloads.
// Nøglen genereres som non-extractable CryptoKey og gemmes i IndexedDB.
// Same-Origin-Policy + non-extractable beskytter mod passive scrapere og
// browser-extensions uden samme origin. R-siden er ikke berørt — ser
// fortsat plain JSON.
//
// Migration: Eksisterende plain JSON læses uændret (ingen `_enc`-marker).
// Næste save skriver krypteret format. Brugerflow er uafbrudt.

// TTL-konfiguration: overskriver med window.SPC_LOCALSTORAGE_TTL_MINUTES
// hvis det er sat fra R-siden (via tags$script i app_ui.R).
// Default 480 minutter (8 timer) matcher klinisk arbejdsdag.
var SPC_LOCALSTORAGE_DEFAULT_TTL_MINUTES = 480;
var SPC_IDB_NAME = 'spc_app_keystore';
var SPC_IDB_STORE = 'keys';
var SPC_KEY_ID = 'localstorage_aes_gcm_v1';

function spc_get_ttl_minutes() {
  return (typeof window.SPC_LOCALSTORAGE_TTL_MINUTES === 'number' &&
    window.SPC_LOCALSTORAGE_TTL_MINUTES > 0)
    ? window.SPC_LOCALSTORAGE_TTL_MINUTES
    : SPC_LOCALSTORAGE_DEFAULT_TTL_MINUTES;
}

// Crypto-tilgængelighed -----------------------------------------------------
// Returns true når både WebCrypto subtle-API og IndexedDB er til stede.
// Falder tilbage til plain localStorage hvis ikke (private mode, gamle
// browsere). Logger warning men afbryder ikke save/load-flow.
function spc_crypto_available() {
  return typeof window !== 'undefined' &&
    typeof window.indexedDB !== 'undefined' &&
    typeof window.crypto !== 'undefined' &&
    typeof window.crypto.subtle !== 'undefined';
}

// IndexedDB key store -------------------------------------------------------
function spc_open_keystore() {
  return new Promise(function(resolve, reject) {
    var req = window.indexedDB.open(SPC_IDB_NAME, 1);
    req.onupgradeneeded = function(e) {
      var db = e.target.result;
      if (!db.objectStoreNames.contains(SPC_IDB_STORE)) {
        db.createObjectStore(SPC_IDB_STORE);
      }
    };
    req.onsuccess = function(e) { resolve(e.target.result); };
    req.onerror = function(e) { reject(e.target.error); };
  });
}

function spc_idb_get(db, key) {
  return new Promise(function(resolve, reject) {
    var tx = db.transaction([SPC_IDB_STORE], 'readonly');
    var store = tx.objectStore(SPC_IDB_STORE);
    var req = store.get(key);
    req.onsuccess = function(e) { resolve(e.target.result); };
    req.onerror = function(e) { reject(e.target.error); };
  });
}

function spc_idb_put(db, key, value) {
  return new Promise(function(resolve, reject) {
    var tx = db.transaction([SPC_IDB_STORE], 'readwrite');
    var store = tx.objectStore(SPC_IDB_STORE);
    var req = store.put(value, key);
    req.onsuccess = function() { resolve(true); };
    req.onerror = function(e) { reject(e.target.error); };
  });
}

// Returnerer eksisterende non-extractable CryptoKey eller genererer en ny.
// CryptoKey-objektet kan persisteres direkte i IndexedDB (structured clone)
// uden at være extractable — angriber kan ikke læse rå nøglematerialet,
// kun invokere encrypt/decrypt på samme origin.
window._spcEncryptionKeyPromise = null;
function spc_get_encryption_key() {
  if (window._spcEncryptionKeyPromise) {
    return window._spcEncryptionKeyPromise;
  }
  window._spcEncryptionKeyPromise = spc_open_keystore().then(function(db) {
    return spc_idb_get(db, SPC_KEY_ID).then(function(existing) {
      if (existing) return existing;
      return window.crypto.subtle.generateKey(
        { name: 'AES-GCM', length: 256 },
        false,
        ['encrypt', 'decrypt']
      ).then(function(newKey) {
        return spc_idb_put(db, SPC_KEY_ID, newKey).then(function() { return newKey; });
      });
    });
  }).catch(function(e) {
    console.warn('[SPC] Encryption key init failed, falling back to plain storage:', e && e.message);
    window._spcEncryptionKeyPromise = null;
    throw e;
  });
  return window._spcEncryptionKeyPromise;
}

// Base64 helpers (ingen Uint8Array.prototype.toBase64 i ældre browsere).
function spc_buf_to_b64(buf) {
  var bytes = new Uint8Array(buf);
  var binary = '';
  for (var i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return window.btoa(binary);
}

function spc_b64_to_buf(b64) {
  var binary = window.atob(b64);
  var bytes = new Uint8Array(binary.length);
  for (var i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

// Encrypt/decrypt -----------------------------------------------------------
// Outer wrapper-format: {"_enc": 1, "iv": "<base64>", "ct": "<base64>"}
// Plain (legacy/fallback): JSON.stringify(payload)
function spc_encrypt_payload(plaintextStr) {
  if (!spc_crypto_available()) {
    return Promise.resolve(plaintextStr);
  }
  return spc_get_encryption_key().then(function(key) {
    var iv = window.crypto.getRandomValues(new Uint8Array(12));
    var encoded = new TextEncoder().encode(plaintextStr);
    return window.crypto.subtle.encrypt(
      { name: 'AES-GCM', iv: iv },
      key,
      encoded
    ).then(function(ct) {
      return JSON.stringify({
        _enc: 1,
        iv: spc_buf_to_b64(iv.buffer),
        ct: spc_buf_to_b64(ct)
      });
    });
  }).catch(function(e) {
    console.warn('[SPC] Encryption failed, storing plaintext:', e && e.message);
    return plaintextStr;
  });
}

function spc_decrypt_payload(rawStr) {
  // Detektér wrapper-format. Kun objekter med _enc=1 dekrypteres; alt
  // andet returneres som plain (legacy migration-path).
  var parsed;
  try {
    parsed = JSON.parse(rawStr);
  } catch(e) {
    return Promise.reject(e);
  }
  if (!parsed || parsed._enc !== 1) {
    return Promise.resolve(parsed);
  }
  if (!spc_crypto_available()) {
    return Promise.reject(new Error('Encrypted payload but crypto unavailable'));
  }
  return spc_get_encryption_key().then(function(key) {
    var iv = new Uint8Array(spc_b64_to_buf(parsed.iv));
    var ct = spc_b64_to_buf(parsed.ct);
    return window.crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: iv },
      key,
      ct
    ).then(function(plain) {
      var jsonStr = new TextDecoder().decode(plain);
      return JSON.parse(jsonStr);
    });
  });
}

// TTL-check ved sideload: fjerner forældede sessioner fra delte hospitals-PC'er.
// Læser kun timestamp-feltet, så vi kan undgå decrypt på TTL-check (hurtigt
// + ingen async-flow ved boot). Krypterede payloads har timestamp i metadata
// efter decrypt — derfor falder TTL-check tilbage til "ekspirér ikke" hvis
// vi ikke kan finde en plain timestamp. Stale entries vil blive expireret
// ved næste decrypt-fejl eller manuel cleanup.
function spc_expire_stale_sessions() {
  var sessionKey = 'spc_app_current_session';
  try {
    var raw = localStorage.getItem(sessionKey);
    if (!raw) return;
    var parsed = JSON.parse(raw);
    if (!parsed) return;
    // Krypteret format: vi kan ikke synkront læse timestamp.
    // TTL-check udskydes til efter decrypt i loadAppState.
    if (parsed._enc === 1) return;
    if (!parsed.timestamp) return;
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

// Async TTL-check der kan håndtere krypterede payloads. Kaldes efter
// første succesfulde decrypt for at fjerne stale entries.
function spc_check_decrypted_ttl(parsed, storageKey) {
  if (!parsed || !parsed.timestamp) return parsed;
  var savedAt = new Date(parsed.timestamp).getTime();
  if (isNaN(savedAt)) return parsed;
  var ageMinutes = (Date.now() - savedAt) / 60000;
  var ttl = spc_get_ttl_minutes();
  if (ageMinutes > ttl) {
    console.info(
      '[SPC] localStorage session udløbet (', Math.round(ageMinutes),
      'min > TTL', ttl, 'min). Rydder krypteret payload.'
    );
    try { localStorage.removeItem(storageKey); } catch(_) {}
    return null;
  }
  return parsed;
}

// Kør TTL-check så snart DOM er klar (før Shiny kalder loadAppState)
$(document).ready(function() {
  spc_expire_stale_sessions();
});

// Save data to localStorage with app prefix
// Note: `data` er allerede en JSON-string fra Rs jsonlite::toJSON().
// Vi krypterer den før setItem og pakker i wrapper-format.
// Returnerer Promise<boolean> — async pga. WebCrypto.
window.saveAppState = function(key, data) {
  var storageKey = 'spc_app_' + key;
  return spc_encrypt_payload(data).then(function(payload) {
    try {
      localStorage.setItem(storageKey, payload);
      return true;
    } catch(e) {
      console.error('Failed to save to localStorage:', e);
      return false;
    }
  }).catch(function(e) {
    console.error('saveAppState pipeline failed:', e);
    return false;
  });
};

// Load data from localStorage
// Returnerer Promise<object|null>. Krypterede payloads dekrypteres
// transparent. Plain legacy-format læses uændret. Ved decrypt-fejl
// (corrupt data, mismatched key efter browser-data-clear) ryddes
// indgangen så bruger ikke sidder fast i et brudt state.
window.loadAppState = function(key) {
  var storageKey = 'spc_app_' + key;
  var rawData;
  try {
    rawData = localStorage.getItem(storageKey);
  } catch(e) {
    console.warn('[SPC] localStorage.getItem fejlede:', e.message);
    return Promise.resolve(null);
  }
  if (!rawData) return Promise.resolve(null);

  return spc_decrypt_payload(rawData).then(function(parsed) {
    return spc_check_decrypted_ttl(parsed, storageKey);
  }).catch(function(e) {
    console.warn('[SPC] Corrupt localStorage entry detected, auto-clearing:', e && e.message);
    try { localStorage.removeItem(storageKey); } catch(_) {}
    return null;
  });
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
