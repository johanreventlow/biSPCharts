// cookie-consent.js
// GDPR-compliant samtykke-modal: hård blocking modal med binær valg
// (Acceptér alle / Kun nødvendige). Pre-app overlay før Shiny renderer.
//
// Storage v2: JSON-objekt under spc_app_consent (erstatter v1's 4 separate keys).
// Migration fra v1 håndteres i milestone JS-2.
//
// Globale flags eksponeret for andre scripts:
//   window._spcConsentDecided  — true når valg er truffet (modal eller load)
//   window._spcConsentGranted  — true/false efter valg
//   document event 'spc:consent-decided' — dispatched efter valg

(function() {
  'use strict';

  var STORAGE_KEY = 'spc_app_consent';
  var SCHEMA_VERSION = 2;
  // Defaults bruges KUN hvis R ikke har injiceret window._spcConsentVersion
  // før denne fil loader (fx i tests eller hvis app_ui.R ændres). Single
  // source of truth for prod er R/config_analytics.R::ANALYTICS_CONFIG —
  // injiceret via app_ui.R synkron <script>-tag før golem::bundle_resources
  // henter cookie-consent.js. Hvis R IKKE har sat dem, falder vi tilbage
  // til disse defaults.
  var DEFAULT_CONSENT_VERSION = 2;
  var DEFAULT_MAX_AGE_DAYS = 365;

  // Default: ej besluttet
  window._spcConsentDecided = false;
  window._spcConsentGranted = undefined;

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

  // Legacy v1 keys (4 separate items). Bevares uændret indtil migration
  // har kørt successful — defensive against partial-migration crashes.
  var LEGACY_KEYS = {
    consent: 'spc_app_analytics_consent',
    version: 'spc_app_consent_version',
    timestamp: 'spc_app_consent_timestamp',
    visitorId: 'spc_app_visitor_id'
  };

  function readLegacyConsent() {
    try {
      var consent = localStorage.getItem(LEGACY_KEYS.consent);
      var version = localStorage.getItem(LEGACY_KEYS.version);
      var timestamp = localStorage.getItem(LEGACY_KEYS.timestamp);
      if (consent === null || version === null || timestamp === null) {
        return null;
      }
      return {
        consented: consent === 'true',
        consent_version: parseInt(version, 10),
        timestamp: timestamp,
        visitor_id: localStorage.getItem(LEGACY_KEYS.visitorId) || null
      };
    } catch (e) {
      return null;
    }
  }

  function migrateLegacyConsent() {
    var legacy = readLegacyConsent();
    if (!legacy) return null;

    // Konstruér v2-record. Bemærk: vi forlader ikke valid-tjek til
    // isConsentValid() — migration mappet bevares 1:1, og caller
    // bestemmer derefter om det er stadig gyldigt mod nuværende version.
    var record = {
      schema_version: SCHEMA_VERSION,
      consent_version: legacy.consent_version,
      timestamp: legacy.timestamp,
      consented: !!legacy.consented,
      visitor_id: legacy.consented ? legacy.visitor_id : null
    };

    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(record));
      // Slet legacy-keys først efter v2-skrivning er bekræftet
      localStorage.removeItem(LEGACY_KEYS.consent);
      localStorage.removeItem(LEGACY_KEYS.version);
      localStorage.removeItem(LEGACY_KEYS.timestamp);
      // visitor_id bevares som legacy backup hvis bruger har consent=true,
      // ellers slet (vi ønsker ikke residual identifikator efter reject)
      if (!legacy.consented) {
        localStorage.removeItem(LEGACY_KEYS.visitorId);
      }
      console.info('[SPC] Migrated v1→v2 consent schema');
      return record;
    } catch (e) {
      console.warn('[SPC] Migration v1→v2 failed:', e);
      return null;
    }
  }

  function readConsent() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) {
        // V2 record findes ej — forsøg legacy-migration
        return migrateLegacyConsent();
      }
      var parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== 'object') return null;
      if (parsed.schema_version !== SCHEMA_VERSION) return null;
      return parsed;
    } catch (e) {
      return null;
    }
  }

  function isConsentValid(record, requiredVersion, maxAgeDays) {
    if (!record) return false;
    if (record.consent_version !== requiredVersion) return false;
    var savedAt = new Date(record.timestamp).getTime();
    if (isNaN(savedAt)) return false;
    var ageDays = (Date.now() - savedAt) / (1000 * 60 * 60 * 24);
    if (ageDays > maxAgeDays) return false;
    return true;
  }

  function saveConsent(consented, consentVersion) {
    try {
      var existing = readConsent();
      var visitorId = (existing && existing.visitor_id) || null;
      if (consented && !visitorId) {
        visitorId = generateUUID();
      }
      var record = {
        schema_version: SCHEMA_VERSION,
        consent_version: consentVersion,
        timestamp: new Date().toISOString(),
        consented: !!consented,
        visitor_id: consented ? visitorId : null
      };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(record));
      return true;
    } catch (e) {
      console.error('[SPC] saveConsent failed:', e);
      return false;
    }
  }

  function getClientMetadata(record) {
    return {
      visitor_id: record && record.visitor_id ? record.visitor_id : null,
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

  function notifyShiny(consented, record) {
    if (typeof Shiny === 'undefined' || !Shiny.setInputValue) {
      // Shiny ej klar endnu — vent på connect
      $(document).on('shiny:connected', function() { notifyShiny(consented, record); });
      return;
    }
    Shiny.setInputValue('analytics_consent', consented, {priority: 'event'});
    if (consented) {
      Shiny.setInputValue('analytics_client_metadata', getClientMetadata(record),
        {priority: 'event'});
    }
  }

  function dispatchDecidedEvent(granted) {
    window._spcConsentDecided = true;
    window._spcConsentGranted = !!granted;
    try {
      var ev = new CustomEvent('spc:consent-decided', {
        detail: {granted: !!granted}
      });
      document.dispatchEvent(ev);
    } catch (e) {
      // CustomEvent ej understøttet (extremely old browser) — ignorer
    }
  }

  // Inert-tracking: bevar liste over body-children vi har sat inert på,
  // så vi kun fjerner inert på dem (og ej forstyrrer noget vi ej satte).
  var _inertedNodes = [];

  function inertAppRoot() {
    if (!document.body) return;
    if (_inertedNodes.length > 0) return; // Allerede inert
    var children = document.body.children;
    for (var i = 0; i < children.length; i++) {
      var node = children[i];
      // Ej inert vores egen modal/backdrop (added efter denne kald)
      if (node.id === 'spc-cookie-modal' ||
          node.id === 'spc-cookie-modal-backdrop') {
        continue;
      }
      // Ej inert script-tags eller noscript
      var tag = node.tagName ? node.tagName.toLowerCase() : '';
      if (tag === 'script' || tag === 'noscript') continue;
      // Ej inert hvis allerede inert (preservér oprindelig state)
      if (node.hasAttribute('inert')) continue;
      node.setAttribute('inert', '');
      _inertedNodes.push(node);
    }
  }

  function uninertAppRoot() {
    for (var i = 0; i < _inertedNodes.length; i++) {
      _inertedNodes[i].removeAttribute('inert');
    }
    _inertedNodes = [];
  }

  function dimAppRoot() {
    if (!document.body) return;
    document.body.classList.add('spc-app-dimmed');
    inertAppRoot();
  }

  function undimAppRoot() {
    if (!document.body) return;
    document.body.classList.remove('spc-app-dimmed');
    uninertAppRoot();
  }

  function hasExistingAppState() {
    try {
      return localStorage.getItem('spc_app_current_session') !== null;
    } catch (e) {
      return false;
    }
  }

  function buildModal(consentVersion) {
    var hasExistingData = hasExistingAppState();

    var backdrop = document.createElement('div');
    backdrop.className = 'spc-cookie-modal__backdrop';
    backdrop.id = 'spc-cookie-modal-backdrop';

    var modal = document.createElement('div');
    modal.className = 'spc-cookie-modal';
    modal.id = 'spc-cookie-modal';
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-modal', 'true');
    modal.setAttribute('aria-labelledby', 'spc-cookie-modal-title');
    modal.setAttribute('aria-describedby', 'spc-cookie-modal-body');

    var title = document.createElement('h2');
    title.id = 'spc-cookie-modal-title';
    title.className = 'spc-cookie-modal__title';
    title.textContent = 'Cookies og lokal lagring';

    var body = document.createElement('div');
    body.id = 'spc-cookie-modal-body';
    body.className = 'spc-cookie-modal__body';
    // innerHTML er sikkert her: indhold er hardcoded konstant, ingen bruger-input.
    // eslint-disable-next-line no-unsanitized/property
    body.innerHTML =
      '<p>For at give dig den bedste oplevelse gemmer biSPCharts dit arbejde ' +
      '(uploadede data og indstillinger) <strong>lokalt</strong> i din browser, ' +
      'så du kan fortsætte hvor du slap.</p>' +
      '<p>Vi måler også anonymt brugsadfærd (performance og fejltyper) ' +
      'for løbende at kunne forbedre appen.</p>' +
      '<p>Statistikken vil aldrig kunne bruges til tracking, reklamer eller ' +
      'identifikation af brugere.</p>';

    // Advarselsblok: vises når brugeren har eksisterende gemt session
    // som vil blive slettet ved valg af "Kun nødvendige".
    var warning = null;
    if (hasExistingData) {
      warning = document.createElement('div');
      warning.className = 'spc-cookie-modal__warning';
      warning.setAttribute('role', 'alert');
      warning.textContent = '⚠ Du har en gemt session fra tidligere. ' +
        'Vælger du "Kun nødvendige", slettes den straks. Brug ' +
        'Download-knappen i appen for at gemme manuelt før du afviser.';
    }

    var buttons = document.createElement('div');
    buttons.className = 'spc-cookie-modal__buttons';

    var acceptBtn = document.createElement('button');
    acceptBtn.type = 'button';
    acceptBtn.className = 'spc-cookie-modal__btn spc-cookie-modal__btn--accept';
    acceptBtn.textContent = 'Acceptér alle';

    var rejectBtn = document.createElement('button');
    rejectBtn.type = 'button';
    rejectBtn.className = 'spc-cookie-modal__btn spc-cookie-modal__btn--reject';
    rejectBtn.textContent = 'Kun nødvendige';

    var rejectLabel = document.createElement('small');
    rejectLabel.className = 'spc-cookie-modal__btn-label';
    rejectLabel.textContent = '(begrænset brugeroplevelse)';

    var rejectWrap = document.createElement('div');
    rejectWrap.className = 'spc-cookie-modal__btn-wrap';
    rejectWrap.appendChild(rejectBtn);
    rejectWrap.appendChild(rejectLabel);

    buttons.appendChild(acceptBtn);
    buttons.appendChild(rejectWrap);
    modal.appendChild(title);
    modal.appendChild(body);
    if (warning) modal.appendChild(warning);
    modal.appendChild(buttons);

    document.body.appendChild(backdrop);
    document.body.appendChild(modal);

    // Autofocus på Acceptér alle (non-destruktivt valg). GDPR-equal-prominence
    // sikret via styling — ingen visuel forskel der nudger.
    // Defer to next tick for at lade browser stabilisere DOM.
    setTimeout(function() {
      try { acceptBtn.focus(); } catch (e) { /* ignore */ }
    }, 0);

    function decide(granted) {
      saveConsent(granted, consentVersion);
      undimAppRoot();
      var existing = document.getElementById('spc-cookie-modal');
      var existingBackdrop = document.getElementById('spc-cookie-modal-backdrop');
      if (existing) existing.remove();
      if (existingBackdrop) existingBackdrop.remove();
      dispatchDecidedEvent(granted);
      notifyShiny(granted, readConsent());
    }

    acceptBtn.addEventListener('click', function() { decide(true); });
    rejectBtn.addEventListener('click', function() { decide(false); });
  }

  // Pre-app gate: ved DOMContentLoaded validerer vi eksisterende samtykke
  // SILENT. Modal vises IKKE automatisk — den triggers af R-side når brugeren
  // klikker "Kom i gang" eller "Gendan session" (action-baseret consent-flow).
  // Landing-page kan vises uden modal — brugeren skal ikke samtykke for at
  // se velkomstskærm.
  //
  // ASYMMETRISK PERSISTENS (politisk valg):
  //   - Accept persisteres (365 dage / consent-version-gate)
  //   - Reject persisteres IKKE på tværs af sessions → modal vises igen
  //     næste besøg, så bruger får mulighed for at revurdere
  function preAppGate(consentVersion, maxAgeDays) {
    var record = readConsent();
    if (isConsentValid(record, consentVersion, maxAgeDays)) {
      if (record.consented === false) {
        // Tidligere afvist samtykke: ryd record + behandl som ej besluttet,
        // så modal vises igen ved næste consent-krævende handling.
        try { localStorage.removeItem(STORAGE_KEY); } catch (e) { /* ignore */ }
        return;
      }
      // Eksisterende valid accept — dispatch + notify uden modal
      dispatchDecidedEvent(record.consented);
      notifyShiny(record.consented, record);
    }
    // Ingen valid samtykke: hold stille. R-side triggerer modal ved
    // første consent-krævende handling (start_wizard, restore_saved_session).
  }

  // Eksplicit trigger fra R-side — vises kun hvis consent ej allerede besluttet
  function triggerConsentModal(consentVersion) {
    if (window._spcConsentDecided === true) {
      // Allerede besluttet — re-dispatch så pending R-action kan fortsætte
      dispatchDecidedEvent(window._spcConsentGranted);
      return;
    }
    if (document.getElementById('spc-cookie-modal')) return; // Allerede vist
    dimAppRoot();
    buildModal(consentVersion || window._spcConsentVersion);
  }

  // Public API: footer-link genåbner samtykke-valg
  window.spcShowCookieSettings = function() {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch (e) { /* ignore */ }
    var existing = document.getElementById('spc-cookie-modal');
    var existingBackdrop = document.getElementById('spc-cookie-modal-backdrop');
    if (existing) existing.remove();
    if (existingBackdrop) existingBackdrop.remove();
    window._spcConsentDecided = false;
    window._spcConsentGranted = undefined;
    dimAppRoot();
    buildModal(window._spcConsentVersion || DEFAULT_CONSENT_VERSION);
  };

  // Default config — bruges kun hvis R ikke har injiceret værdierne via
  // app_ui.R synkron <script>-tag. Sætter ej hvis allerede sat (R wins).
  if (typeof window._spcConsentVersion !== 'number') {
    window._spcConsentVersion = DEFAULT_CONSENT_VERSION;
  }
  if (typeof window._spcConsentMaxAgeDays !== 'number') {
    window._spcConsentMaxAgeDays = DEFAULT_MAX_AGE_DAYS;
  }

  // Pre-app gate kører ASAP ved DOMContentLoaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      preAppGate(window._spcConsentVersion, window._spcConsentMaxAgeDays);
    });
  } else {
    preAppGate(window._spcConsentVersion, window._spcConsentMaxAgeDays);
  }

  // R sender consent_version efter session-init — for re-validation
  // (hvis version bumped siden DOMContentLoaded).
  if (typeof Shiny !== 'undefined' && Shiny.addCustomMessageHandler) {
    Shiny.addCustomMessageHandler('spc_set_consent_version', function(version) {
      window._spcConsentVersion = version;
      // Hvis besluttet med tidligere samtykke: re-validér mod ny version
      // STILLE — modal vises ej automatisk, R triggerer den ved næste
      // consent-krævende handling.
      if (window._spcConsentDecided) {
        var record = readConsent();
        if (!isConsentValid(record, version, window._spcConsentMaxAgeDays)) {
          window._spcConsentDecided = false;
          window._spcConsentGranted = undefined;
        }
      }
    });

    // R triggerer modal når bruger forsøger consent-krævende handling
    // (start_wizard, restore_saved_session) og samtykke endnu ej er besluttet.
    Shiny.addCustomMessageHandler('spc_show_consent_modal', function(_message) {
      triggerConsentModal(window._spcConsentVersion);
    });
  }

  // Eksponer triggerConsentModal i tilfælde af direkte JS-kald
  window.spcTriggerConsentModal = triggerConsentModal;

})();
