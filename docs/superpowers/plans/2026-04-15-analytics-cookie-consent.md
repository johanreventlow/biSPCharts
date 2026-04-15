# Analytics & Cookie Consent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tilfoej GDPR-compliant cookie consent og analytics tracking til biSPCharts, bygget paa eksisterende shinylogs-infrastruktur.

**Architecture:** Cookie consent-banner i JS styrer om shinylogs initialiseres. Klient-side metadata (browser, skaerm, visitor-ID) og performance-timing sendes til R via `Shiny.setInputValue()`. Log-data aggregeres og publiceres via `pins`-pakken til fremtidigt Quarto dashboard.

**Tech Stack:** shinylogs (eksisterende), pins (ny dependency), vanilla JavaScript, localStorage, Shiny custom message handlers.

**Design spec:** `docs/superpowers/specs/2026-04-15-analytics-cookie-consent-design.md`

---

## File Structure

### Nye filer

| Fil | Ansvar |
|-----|--------|
| `R/config_analytics.R` | Analytics-konstanter: consent version, log rotation, pin config, feature flags |
| `inst/app/www/cookie-consent.css` | Styling til consent-banner (fixed bottom, BFH farver) |
| `inst/app/www/cookie-consent.js` | Consent-banner UI, localStorage consent/visitor-ID, client metadata indsamling |
| `inst/app/www/analytics-client.js` | Performance timing via Performance API, sender til R |
| `R/utils_analytics_consent.R` | Server-side consent-gate: observeEvent paa consent input, betinget shinylogs init |
| `R/utils_analytics_pins.R` | Log-aggregering fra JSON-filer, pin_write til Connect Cloud |
| `tests/testthat/test-config_analytics.R` | Tests for analytics config |
| `tests/testthat/test-utils_analytics_consent.R` | Tests for consent-gate logik |
| `tests/testthat/test-utils_analytics_pins.R` | Tests for log-aggregering og pins |

### Aendringer i eksisterende filer

| Fil | Aendring |
|-----|---------|
| `DESCRIPTION` | Tilfoej `pins (>= 1.2.0)` til Imports |
| `inst/golem-config.yml` | Tilfoej `analytics:` sektion i alle environments |
| `R/config_log_contexts.R` | Tilfoej `analytics` kategori til LOG_CONTEXTS |
| `R/utils_server_initialization.R` | Flyt shinylogs init bag consent-gate (kald `setup_analytics_consent()`) |
| `R/ui_app_ui.R` | Tilfoej cookie-indstillinger link i footer |

---

## Task 1: Analytics Configuration

**Files:**
- Create: `R/config_analytics.R`
- Create: `tests/testthat/test-config_analytics.R`

- [ ] **Step 1: Skriv test for analytics config**

```r
# tests/testthat/test-config_analytics.R

test_that("ANALYTICS_CONFIG har alle noedvendige felter", {
  expect_true(is.list(ANALYTICS_CONFIG))
  expect_true("consent_version" %in% names(ANALYTICS_CONFIG))
  expect_true("consent_max_age_days" %in% names(ANALYTICS_CONFIG))
  expect_true("log_retention_days" %in% names(ANALYTICS_CONFIG))
  expect_true("log_compress_after_days" %in% names(ANALYTICS_CONFIG))
  expect_true("pin_name" %in% names(ANALYTICS_CONFIG))
  expect_true("enabled" %in% names(ANALYTICS_CONFIG))
})

test_that("ANALYTICS_CONFIG har korrekte typer", {
  expect_type(ANALYTICS_CONFIG$consent_version, "integer")
  expect_type(ANALYTICS_CONFIG$consent_max_age_days, "integer")
  expect_type(ANALYTICS_CONFIG$log_retention_days, "integer")
  expect_type(ANALYTICS_CONFIG$log_compress_after_days, "integer")
  expect_type(ANALYTICS_CONFIG$pin_name, "character")
  expect_type(ANALYTICS_CONFIG$enabled, "logical")
})

test_that("ANALYTICS_CONFIG har fornuftige defaults", {
  expect_equal(ANALYTICS_CONFIG$consent_version, 1L)
  expect_equal(ANALYTICS_CONFIG$consent_max_age_days, 365L)
  expect_equal(ANALYTICS_CONFIG$log_retention_days, 365L)
  expect_equal(ANALYTICS_CONFIG$log_compress_after_days, 90L)
  expect_equal(ANALYTICS_CONFIG$pin_name, "spc-analytics-logs")
  expect_true(ANALYTICS_CONFIG$enabled)
})

test_that("get_analytics_config() returnerer korrekt config", {
  config <- get_analytics_config()
  expect_true(is.list(config))
  expect_equal(config$consent_version, ANALYTICS_CONFIG$consent_version)
})
```

- [ ] **Step 2: Koer test — verificer at den fejler**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-config_analytics.R')"`
Expected: FAIL — `ANALYTICS_CONFIG` ikke fundet

- [ ] **Step 3: Implementer config**

```r
# R/config_analytics.R
# Konfiguration for analytics og cookie consent

#' Analytics Configuration
#'
#' Centraliserede konstanter for analytics, consent og log rotation.
#'
#' @format List med foelgende felter:
#' \describe{
#'   \item{consent_version}{Integer — bump for at tvinge re-consent}
#'   \item{consent_max_age_days}{Antal dage foer consent udloeber (GDPR)}
#'   \item{log_retention_days}{Antal dage foer log-filer slettes}
#'   \item{log_compress_after_days}{Antal dage foer log-filer komprimeres}
#'   \item{pin_name}{Navn paa pin til Connect Cloud}
#'   \item{enabled}{Feature flag for hele analytics-systemet}
#' }
#' @export
ANALYTICS_CONFIG <- list(
  consent_version = 1L,
  consent_max_age_days = 365L,   # 12 maaneder GDPR re-consent
  log_retention_days = 365L,
  log_compress_after_days = 90L,
  pin_name = "spc-analytics-logs",
  enabled = TRUE
)

#' Hent analytics konfiguration
#'
#' Returnerer analytics config. Kan udvides til at laese fra
#' golem-config.yml i fremtiden.
#'
#' @return List med analytics konfiguration
#' @export
get_analytics_config <- function() {
  ANALYTICS_CONFIG
}
```

- [ ] **Step 4: Koer test — verificer at den bestaar**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-config_analytics.R')"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add R/config_analytics.R tests/testthat/test-config_analytics.R
git commit -m "feat(analytics): tilfoej analytics konfiguration med consent version og log rotation"
```

---

## Task 2: Cookie Consent JavaScript

**Files:**
- Create: `inst/app/www/cookie-consent.css`
- Create: `inst/app/www/cookie-consent.js`

- [ ] **Step 1: Opret consent banner CSS**

```css
/* inst/app/www/cookie-consent.css */
/* Cookie consent banner — GDPR-compliant, diskret placement */

.spc-cookie-banner {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background-color: #2c3e50;
  color: #ffffff;
  padding: 16px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  z-index: 9999;
  font-size: 14px;
  box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.2);
}

.spc-cookie-banner__text {
  flex: 1;
  line-height: 1.4;
}

.spc-cookie-banner__buttons {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}

.spc-cookie-banner__btn {
  padding: 8px 20px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
}

.spc-cookie-banner__btn--accept {
  background-color: #27ae60;
  color: #ffffff;
}

.spc-cookie-banner__btn--accept:hover {
  background-color: #219a52;
}

.spc-cookie-banner__btn--reject {
  background-color: transparent;
  color: #ffffff;
  border: 1px solid #ffffff;
}

.spc-cookie-banner__btn--reject:hover {
  background-color: rgba(255, 255, 255, 0.1);
}

.spc-cookie-settings-link {
  color: #888;
  font-size: 12px;
  cursor: pointer;
  text-decoration: underline;
}

.spc-cookie-settings-link:hover {
  color: #555;
}

.spc-cookie-banner--hidden {
  display: none !important;
}
```

- [ ] **Step 2: Opret consent JavaScript**

Bemærk: Consent-banneret bygges med sikre DOM-metoder (createElement/textContent) i stedet for innerHTML for at undgå XSS-risiko.

```javascript
// inst/app/www/cookie-consent.js
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

  // Byg banner med sikre DOM-metoder (ingen innerHTML — undgaar XSS)
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

  // Vis banner igen (kaldt fra "Cookie-indstillinger" link)
  window.spcShowCookieSettings = function() {
    try {
      localStorage.removeItem(KEYS.consent);
      localStorage.removeItem(KEYS.version);
      localStorage.removeItem(KEYS.timestamp);
    } catch (e) { /* ignorér */ }
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
```

- [ ] **Step 3: Verificer JS syntax**

Run: `node -c inst/app/www/cookie-consent.js && echo "JS syntax OK"`
Expected: "JS syntax OK"

- [ ] **Step 4: Commit**

```bash
git add inst/app/www/cookie-consent.css inst/app/www/cookie-consent.js
git commit -m "feat(analytics): tilfoej cookie consent banner med GDPR compliance"
```

---

## Task 3: Analytics Client JavaScript (Performance Timing)

**Files:**
- Create: `inst/app/www/analytics-client.js`

- [ ] **Step 1: Opret analytics client JS**

```javascript
// inst/app/www/analytics-client.js
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
    catch (e) { /* ignorér */ }
  };

  window.spcMarkEnd = function(name) {
    if (!_analyticsActive) return;
    try {
      performance.mark('spc_' + name + '_end');
      performance.measure('spc_' + name, 'spc_' + name + '_start', 'spc_' + name + '_end');
    } catch (e) { /* ignorér */ }
  };

})();
```

- [ ] **Step 2: Verificer JS syntax**

Run: `node -c inst/app/www/analytics-client.js && echo "JS syntax OK"`
Expected: "JS syntax OK"

- [ ] **Step 3: Commit**

```bash
git add inst/app/www/analytics-client.js
git commit -m "feat(analytics): tilfoej klient-side performance timing"
```

---

## Task 4: Server-Side Consent Gate

**Files:**
- Create: `R/utils_analytics_consent.R`
- Create: `tests/testthat/test-utils_analytics_consent.R`
- Modify: `R/config_log_contexts.R`

- [ ] **Step 1: Skriv tests for consent-gate**

```r
# tests/testthat/test-utils_analytics_consent.R

test_that("should_track_analytics() returnerer FALSE naar consent mangler", {
  expect_false(should_track_analytics(consent = NULL))
  expect_false(should_track_analytics(consent = FALSE))
})

test_that("should_track_analytics() returnerer TRUE naar consent er givet", {
  expect_true(should_track_analytics(consent = TRUE))
})

test_that("should_track_analytics() respekterer feature flag", {
  withr::with_options(
    list(spc.analytics.enabled = FALSE),
    expect_false(should_track_analytics(consent = TRUE))
  )
})

test_that("format_analytics_metadata() returnerer korrekt struktur", {
  metadata <- list(
    visitor_id = "test-uuid-1234",
    user_agent = "Mozilla/5.0",
    screen_width = 1920,
    screen_height = 1080,
    window_width = 1200,
    window_height = 800,
    is_touch = FALSE,
    language = "da",
    timezone = "Europe/Copenhagen",
    referrer = "https://example.com",
    timestamp = "2026-04-15T10:00:00Z"
  )

  result <- format_analytics_metadata(metadata)
  expect_true(is.list(result))
  expect_equal(result$visitor_id, "test-uuid-1234")
  expect_equal(result$browser, "Mozilla/5.0")
  expect_equal(result$screen_width, 1920)
  expect_false(result$is_touch)
})

test_that("format_analytics_metadata() haandterer NULL input", {
  result <- format_analytics_metadata(NULL)
  expect_null(result)
})
```

- [ ] **Step 2: Koer test — verificer at den fejler**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-utils_analytics_consent.R')"`
Expected: FAIL — funktioner ikke fundet

- [ ] **Step 3: Tilfoej analytics log context**

I `R/config_log_contexts.R`, tilfoej en `analytics` kategori i LOG_CONTEXTS listen:

```r
  analytics = list(
    consent = "ANALYTICS_CONSENT",
    tracking = "ANALYTICS_TRACKING",
    metadata = "ANALYTICS_METADATA",
    performance = "ANALYTICS_PERF",
    pins = "ANALYTICS_PINS",
    rotation = "ANALYTICS_ROTATION"
  ),
```

- [ ] **Step 4: Implementer consent-gate**

```r
# R/utils_analytics_consent.R
# Server-side analytics consent gate og metadata haandtering

#' Tjek om analytics tracking skal vaere aktiv
#'
#' Verificerer baade bruger-consent og feature flag.
#'
#' @param consent Logical eller NULL — brugerens consent-status
#' @return Logical — TRUE hvis tracking er tilladt
#' @export
should_track_analytics <- function(consent = NULL) {
  analytics_enabled <- getOption("spc.analytics.enabled", default = ANALYTICS_CONFIG$enabled)
  if (!analytics_enabled) return(FALSE)
  if (is.null(consent) || !isTRUE(consent)) return(FALSE)
  TRUE
}

#' Formatér client metadata fra JavaScript
#'
#' Konverterer raa metadata fra JS til struktureret R-format.
#'
#' @param raw_metadata List fra Shiny.setInputValue('analytics_client_metadata')
#' @return List med formateret metadata, eller NULL
#' @export
format_analytics_metadata <- function(raw_metadata) {
  if (is.null(raw_metadata)) return(NULL)
  list(
    visitor_id = raw_metadata$visitor_id,
    browser = raw_metadata$user_agent,
    screen_width = raw_metadata$screen_width,
    screen_height = raw_metadata$screen_height,
    window_width = raw_metadata$window_width,
    window_height = raw_metadata$window_height,
    is_touch = isTRUE(raw_metadata$is_touch),
    language = raw_metadata$language,
    timezone = raw_metadata$timezone,
    referrer = raw_metadata$referrer,
    timestamp = raw_metadata$timestamp
  )
}

#' Setup analytics consent observer i Shiny server
#'
#' Registrerer observer paa input$analytics_consent og initialiserer
#' shinylogs KUN naar brugeren har accepteret.
#'
#' @param input Shiny input object
#' @param session Shiny session object
#' @param hashed_token Hashed session token for logging
#' @param log_directory Directory for shinylogs output
#' @return Invisible NULL
#' @export
setup_analytics_consent <- function(input, session, hashed_token, log_directory = "logs/") {
  config <- get_analytics_config()
  session$sendCustomMessage("spc_set_consent_version", config$consent_version)

  shiny::observeEvent(input$analytics_consent, {
    consent <- input$analytics_consent

    if (should_track_analytics(consent)) {
      safe_operation(
        "Initialize shinylogs after consent",
        code = {
          setup_shinylogs(
            enable_tracking = TRUE,
            enable_errors = TRUE,
            enable_performances = TRUE,
            log_directory = log_directory
          )
          initialize_shinylogs_tracking(
            session = session,
            app_name = "SPC_Analysis_Tool"
          )
          session$sendCustomMessage("spc_start_analytics", list())
          log_info("Analytics tracking aktiveret efter consent",
                   .context = LOG_CONTEXTS$analytics$consent)
        },
        fallback = function(e) {
          log_error(paste("shinylogs init fejlede:", e$message),
                    .context = LOG_CONTEXTS$analytics$consent)
        },
        error_type = "processing"
      )
    } else {
      log_debug("Analytics afvist af bruger",
                .context = LOG_CONTEXTS$analytics$consent)
    }
  }, once = TRUE, ignoreNULL = TRUE)

  shiny::observeEvent(input$analytics_client_metadata, {
    metadata <- format_analytics_metadata(input$analytics_client_metadata)
    if (!is.null(metadata)) {
      log_info("Client metadata modtaget",
               .context = LOG_CONTEXTS$analytics$metadata)
      session$userData$analytics_metadata <- metadata
    }
  }, once = TRUE, ignoreNULL = TRUE)

  shiny::observeEvent(input$analytics_performance, {
    perf <- input$analytics_performance
    if (!is.null(perf)) {
      log_debug_kv(
        message = paste("Performance:", perf$type),
        .context = LOG_CONTEXTS$analytics$performance,
        type = perf$type,
        duration_ms = perf$duration_ms %||% NA_real_
      )
    }
  }, ignoreNULL = TRUE)

  session$onSessionEnded(function() {
    safe_operation(
      "Aggregate analytics on session end",
      code = {
        aggregate_and_pin_logs(log_directory)
      },
      fallback = function(e) {
        log_error(paste("Log aggregering fejlede:", e$message),
                  .context = LOG_CONTEXTS$analytics$pins)
      },
      error_type = "processing"
    )
  })

  invisible(NULL)
}
```

- [ ] **Step 5: Koer test — verificer at den bestaar**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-utils_analytics_consent.R')"`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add R/utils_analytics_consent.R tests/testthat/test-utils_analytics_consent.R R/config_log_contexts.R
git commit -m "feat(analytics): tilfoej server-side consent gate og metadata haandtering"
```

---

## Task 5: Log Aggregering og Pins

**Files:**
- Create: `R/utils_analytics_pins.R`
- Create: `tests/testthat/test-utils_analytics_pins.R`
- Modify: `DESCRIPTION`

- [ ] **Step 1: Tilfoej pins dependency**

I `DESCRIPTION`, tilfoej `pins (>= 1.2.0)` i Imports-sektionen (alfabetisk, efter `later`):

```
    later (>= 1.3.0),
    pins (>= 1.2.0),
    yaml (>= 2.3.0),
```

- [ ] **Step 2: Skriv tests for log-aggregering**

```r
# tests/testthat/test-utils_analytics_pins.R

test_that("read_shinylogs_sessions() returnerer data.frame", {
  tmp_dir <- withr::local_tempdir()
  session_dir <- file.path(tmp_dir, "sessions")
  dir.create(session_dir, recursive = TRUE)

  test_session <- list(
    app = "SPC_Analysis_Tool",
    user = "",
    server_connected = "2026-04-15T10:00:00Z",
    server_disconnected = "2026-04-15T10:15:00Z",
    session_duration = 900
  )
  jsonlite::write_json(test_session,
    file.path(session_dir, "session_2026-04-15_test123.json"))

  result <- read_shinylogs_sessions(tmp_dir)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) >= 1)
  expect_true("session_duration" %in% names(result))
})

test_that("read_shinylogs_sessions() haandterer tom mappe", {
  tmp_dir <- withr::local_tempdir()
  result <- read_shinylogs_sessions(tmp_dir)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("rotate_log_files() komprimerer gamle filer", {
  tmp_dir <- withr::local_tempdir()

  old_file <- file.path(tmp_dir, "old_log.json")
  writeLines('{"test": true}', old_file)
  Sys.setFileTime(old_file, Sys.time() - as.difftime(100, units = "days"))

  new_file <- file.path(tmp_dir, "new_log.json")
  writeLines('{"test": true}', new_file)

  rotate_log_files(tmp_dir, compress_after_days = 90, delete_after_days = 365)

  expect_true(file.exists(paste0(old_file, ".gz")))
  expect_false(file.exists(old_file))
  expect_true(file.exists(new_file))
})
```

- [ ] **Step 3: Koer test — verificer at den fejler**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-utils_analytics_pins.R')"`
Expected: FAIL — funktioner ikke fundet

- [ ] **Step 4: Implementer log-aggregering og pins**

```r
# R/utils_analytics_pins.R
# Log-aggregering fra shinylogs JSON-filer og publicering via pins

#' Laes shinylogs session-filer til data.frame
#'
#' @param log_directory Sti til log-mappe
#' @return data.frame med session-data (tom data.frame hvis ingen filer)
#' @export
read_shinylogs_sessions <- function(log_directory) {
  sessions_dir <- file.path(log_directory, "sessions")
  if (!dir.exists(sessions_dir)) return(data.frame())

  files <- list.files(sessions_dir, pattern = "\\.json$", full.names = TRUE)
  if (length(files) == 0) return(data.frame())

  sessions <- lapply(files, function(f) {
    tryCatch(
      jsonlite::fromJSON(f, simplifyVector = TRUE),
      error = function(e) {
        log_warn(paste("Kunne ikke laese session-fil:", basename(f)),
                 .context = LOG_CONTEXTS$analytics$pins)
        NULL
      }
    )
  })

  sessions <- Filter(Negate(is.null), sessions)
  if (length(sessions) == 0) return(data.frame())

  tryCatch(
    dplyr::bind_rows(sessions),
    error = function(e) {
      log_warn(paste("bind_rows fejlede:", e$message),
               .context = LOG_CONTEXTS$analytics$pins)
      data.frame()
    }
  )
}

#' Roter log-filer (komprimer gamle, slet meget gamle)
#'
#' @param log_directory Sti til log-mappe
#' @param compress_after_days Komprimer filer aeldre end dette (default: 90)
#' @param delete_after_days Slet filer aeldre end dette (default: 365)
#' @export
rotate_log_files <- function(log_directory,
                             compress_after_days = ANALYTICS_CONFIG$log_compress_after_days,
                             delete_after_days = ANALYTICS_CONFIG$log_retention_days) {
  json_files <- list.files(log_directory, pattern = "\\.json$",
                           full.names = TRUE, recursive = TRUE)
  if (length(json_files) == 0) return(invisible(NULL))

  now <- Sys.time()
  for (f in json_files) {
    file_age_days <- as.numeric(difftime(now, file.info(f)$mtime, units = "days"))

    if (file_age_days > delete_after_days) {
      unlink(f)
      unlink(paste0(f, ".gz"))
    } else if (file_age_days > compress_after_days) {
      tryCatch({
        con <- gzfile(paste0(f, ".gz"), "wb")
        writeLines(readLines(f), con)
        close(con)
        unlink(f)
      }, error = function(e) {
        log_warn(paste("Komprimering fejlede:", basename(f), e$message),
                 .context = LOG_CONTEXTS$analytics$rotation)
      })
    }
  }
  invisible(NULL)
}

#' Aggreger logs og publicer til Connect Cloud via pins
#'
#' @param log_directory Sti til log-mappe
#' @export
aggregate_and_pin_logs <- function(log_directory = "logs/") {
  config <- get_analytics_config()
  sessions <- read_shinylogs_sessions(log_directory)

  if (nrow(sessions) == 0) {
    log_debug("Ingen sessions at aggregere",
              .context = LOG_CONTEXTS$analytics$pins)
    return(invisible(NULL))
  }

  safe_operation(
    "Pin analytics data",
    code = {
      if (requireNamespace("pins", quietly = TRUE) && nchar(Sys.getenv("CONNECT_SERVER")) > 0) {
        board <- pins::board_connect()
        pins::pin_write(board, sessions, config$pin_name,
                        type = "rds",
                        description = "biSPCharts analytics session data")
        log_info(paste("Analytics pin opdateret:", nrow(sessions), "sessions"),
                 .context = LOG_CONTEXTS$analytics$pins)
      } else {
        log_debug("Pins ikke tilgaengelig (ikke paa Connect Cloud)",
                  .context = LOG_CONTEXTS$analytics$pins)
      }
    },
    fallback = function(e) {
      log_warn(paste("Pin publicering fejlede:", e$message),
               .context = LOG_CONTEXTS$analytics$pins)
    },
    error_type = "processing"
  )

  rotate_log_files(log_directory)
  invisible(NULL)
}
```

- [ ] **Step 5: Koer test — verificer at den bestaar**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-utils_analytics_pins.R')"`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add R/utils_analytics_pins.R tests/testthat/test-utils_analytics_pins.R DESCRIPTION
git commit -m "feat(analytics): tilfoej log-aggregering og pins-publicering"
```

---

## Task 6: Integrer i Eksisterende App

**Files:**
- Modify: `R/utils_server_initialization.R` (linje 63-81)
- Modify: `R/ui_app_ui.R` (efter linje 284)
- Modify: `inst/golem-config.yml`

- [ ] **Step 1: Opdater golem-config.yml**

Tilfoej i `default:` sektionen (efter `session:` blokken, foer `ai:`):

```yaml
  # Analytics og cookie consent
  analytics:
    enabled: true
    consent_version: 1
    consent_max_age_days: 365
    log_directory: "logs/"
    pin_name: "spc-analytics-logs"
    log_retention_days: 365
    log_compress_after_days: 90
```

Tilfoej i `development:`:
```yaml
  analytics:
    enabled: true
```

Tilfoej i `production:`:
```yaml
  analytics:
    enabled: true
```

Tilfoej i `testing:`:
```yaml
  analytics:
    enabled: false
```

- [ ] **Step 2: Flyt shinylogs init bag consent-gate**

I `R/utils_server_initialization.R`, erstat linje 63-81 (den eksisterende shinylogs-blok):

```r
  # Nuvaerende kode (FJERN):
  # if (should_enable_shinylogs()) {
  #   setup_shinylogs(...)
  #   initialize_shinylogs_tracking(...)
  #   log_debug_kv(...)
  # }

  # Ny kode (ERSTAT MED):
  # ANALYTICS: Setup consent gate (erstatter direkte shinylogs init)
  # shinylogs initialiseres KUN naar bruger har givet consent via cookie-banner
  if (should_enable_shinylogs()) {
    setup_analytics_consent(
      input = session$input,
      session = session,
      hashed_token = hashed_token,
      log_directory = "logs/"
    )
    log_debug("Analytics consent gate registered", .context = "APP_INIT")
  }
```

- [ ] **Step 3: Tilfoej cookie-indstillinger link i ui_app_ui.R**

I `create_ui_header()` funktionen, tilfoej foer den afsluttende `)` paa linje 285:

```r
    # Cookie-indstillinger link (synlig i bunden af siden)
    shiny::tags$div(
      style = "position: fixed; bottom: 4px; right: 12px; z-index: 999;",
      shiny::tags$a(
        href = "javascript:void(0)",
        onclick = "if(window.spcShowCookieSettings) window.spcShowCookieSettings();",
        class = "spc-cookie-settings-link",
        "Cookie-indstillinger"
      )
    )
```

- [ ] **Step 4: Koer alle eksisterende tests**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: Alle eksisterende tests bestaar

- [ ] **Step 5: Commit**

```bash
git add R/utils_server_initialization.R R/ui_app_ui.R inst/golem-config.yml
git commit -m "feat(analytics): integrer consent-gate i app init og tilfoej cookie-indstillinger link"
```

---

## Task 7: Opdater NAMESPACE og Dokumentation

**Files:**
- Modify: `R/NAMESPACE` (via devtools::document())

- [ ] **Step 1: Koer devtools::document()**

Run: `Rscript -e "devtools::document()"`
Expected: NAMESPACE opdateret med nye exports

- [ ] **Step 2: Koer fuld test-suite**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: Alle tests bestaar

- [ ] **Step 3: Commit**

```bash
git add R/NAMESPACE man/
git commit -m "chore: opdater NAMESPACE og dokumentation for analytics"
```

---

## Task 8: Manuel Verifikation

- [ ] **Step 1: Start app lokalt**

Run: `Rscript -e "devtools::load_all(); run_app()"`

- [ ] **Step 2: Verificer consent-banner**

Check:
- Cookie-banner vises ved foerste besog (bund af siden)
- Tekst: "Denne app indsamler anonymiseret brugsstatistik for at forbedre kvaliteten."
- "Accepter" og "Afvis" knapper er synlige
- Banner forsvinder efter klik

- [ ] **Step 3: Verificer consent persistering**

Check:
- Genindlaes siden — banneret skal IKKE vises igen
- DevTools > Application > Local Storage: se `spc_app_analytics_consent`, `spc_app_consent_version`, `spc_app_consent_timestamp`
- Hvis accepteret: se ogsaa `spc_app_visitor_id`

- [ ] **Step 4: Verificer cookie-indstillinger link**

Check:
- "Cookie-indstillinger" link synlig i nederste hoejre hjoerne
- Klik viser banneret igen
- Nyt valg gemmes korrekt

- [ ] **Step 5: Verificer shinylogs kun koerer ved consent**

Check:
- Accepter cookies > upload data > interager med appen
- Tjek `logs/` mappen — der skal vaere JSON-filer
- Ryd localStorage > genindlaes > afvis cookies
- Interager med appen — `logs/` skal IKKE faa nye filer

- [ ] **Step 6: Verificer performance metrics**

Check:
- Accepter cookies > aaben browser DevTools > Console
- Se `[SPC]`-prefixed log messages for performance data

- [ ] **Step 7: Commit final state hvis noedvendigt**

```bash
git add -A
git commit -m "chore: justeringer efter manuel verifikation"
```
