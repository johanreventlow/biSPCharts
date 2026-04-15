// cookie-consent.js
// GDPR cookie consent banner og analytics metadata indsamling
// Bruger spc_app_ prefix (eksisterende localStorage-moenster fra local-storage.js)

(function() {
  'use strict';

  var KEYS = {
    consent: 'spc_app_analytics_consent',
    version: 'spc_app_consent_version',
    timestamp: 'spc_app_consent_timestamp',
    visitorId: 'spc_app_visitor_id'
  };

  function generateUUID() {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) {
      return crypto.randomUUID();
    }
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r = Math.random() * 16 | 0;
      var v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  function getConsentStatus() {
    try {
      var consent = localStorage.getItem(KEYS.consent);
      var version = localStorage.getItem(KEYS.version);
      var timestamp = localStorage.getItem(KEYS.timestamp);
      if (consent === null || version === null || timestamp === null) return null;
      return {
        consented: consent === 'true',
        version: parseInt(version, 10),
        timestamp: timestamp
      };
    } catch (e) {
      return null;
    }
  }

  function isConsentValid(status, requiredVersion, maxAgeDays) {
    if (!status) return false;
    if (status.version !== requiredVersion) return false;
    var ageDays = (new Date() - new Date(status.timestamp)) / (1000 * 60 * 60 * 24);
    if (ageDays > maxAgeDays) return false;
    return true;
  }

  function saveConsent(accepted, consentVersion) {
    try {
      localStorage.setItem(KEYS.consent, accepted ? 'true' : 'false');
      localStorage.setItem(KEYS.version, String(consentVersion));
      localStorage.setItem(KEYS.timestamp, new Date().toISOString());
      if (accepted && !localStorage.getItem(KEYS.visitorId)) {
        localStorage.setItem(KEYS.visitorId, generateUUID());
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  function getVisitorId() {
    try { return localStorage.getItem(KEYS.visitorId); }
    catch (e) { return null; }
  }

  function getClientMetadata() {
    return {
      visitor_id: getVisitorId(),
      user_agent: navigator.userAgent,
      screen_width: screen.width,
      screen_height: screen.height,
      window_width: window.innerWidth,
      window_height: window.innerHeight,
      is_touch: ('ontouchstart' in window) || (navigator.maxTouchPoints > 0),
      language: navigator.language,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      referrer: document.referrer || null,
      timestamp: new Date().toISOString()
    };
  }

  function notifyShiny(consented) {
    if (typeof Shiny === 'undefined' || !Shiny.setInputValue) {
      $(document).on('shiny:connected', function() { notifyShiny(consented); });
      return;
    }
    Shiny.setInputValue('analytics_consent', consented, {priority: 'event'});
    if (consented) {
      Shiny.setInputValue('analytics_client_metadata', getClientMetadata(), {priority: 'event'});
    }
  }

  // Build banner with safe DOM methods (no innerHTML — XSS prevention)
  function showBanner(consentVersion) {
    var banner = document.createElement('div');
    banner.className = 'spc-cookie-banner';
    banner.id = 'spc-cookie-banner';
    banner.setAttribute('role', 'dialog');
    banner.setAttribute('aria-label', 'Cookie samtykke');

    var textDiv = document.createElement('div');
    textDiv.className = 'spc-cookie-banner__text';
    textDiv.textContent = 'Denne app indsamler anonymiseret brugsstatistik for at forbedre kvaliteten.';

    var buttonsDiv = document.createElement('div');
    buttonsDiv.className = 'spc-cookie-banner__buttons';

    var rejectBtn = document.createElement('button');
    rejectBtn.className = 'spc-cookie-banner__btn spc-cookie-banner__btn--reject';
    rejectBtn.textContent = 'Afvis';

    var acceptBtn = document.createElement('button');
    acceptBtn.className = 'spc-cookie-banner__btn spc-cookie-banner__btn--accept';
    acceptBtn.textContent = 'Accept\u00e9r';

    buttonsDiv.appendChild(rejectBtn);
    buttonsDiv.appendChild(acceptBtn);
    banner.appendChild(textDiv);
    banner.appendChild(buttonsDiv);
    document.body.appendChild(banner);

    acceptBtn.addEventListener('click', function() {
      saveConsent(true, consentVersion);
      banner.classList.add('spc-cookie-banner--hidden');
      notifyShiny(true);
    });

    rejectBtn.addEventListener('click', function() {
      saveConsent(false, consentVersion);
      banner.classList.add('spc-cookie-banner--hidden');
      notifyShiny(false);
    });
  }

  window.spcShowCookieSettings = function() {
    try {
      localStorage.removeItem(KEYS.consent);
      localStorage.removeItem(KEYS.version);
      localStorage.removeItem(KEYS.timestamp);
    } catch (e) { /* ignore */ }
    var existing = document.getElementById('spc-cookie-banner');
    if (existing) existing.remove();
    showBanner(window._spcConsentVersion || 1);
  };

  window._spcConsentVersion = 1;

  Shiny.addCustomMessageHandler('spc_set_consent_version', function(version) {
    window._spcConsentVersion = version;
    var status = getConsentStatus();
    if (isConsentValid(status, version, 365)) {
      notifyShiny(status.consented);
    } else {
      showBanner(version);
    }
  });

})();
