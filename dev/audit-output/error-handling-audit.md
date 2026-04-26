# Audit: error = function(e) NULL — 2026-04-25

Gennemgang af alle forekomster iht. harden-csv-parse-error-reporting spec.

## Legende
- **(a)** Tilføjet log_debug
- **(b)** Erstattet med try_with_diagnostics
- **(c)** Dokumenteret silent-fail-begrundelse

---

## error = function(e) NULL

| Fil | Linje | Beslutning | Begrundelse |
|-----|-------|-----------|-------------|
| fct_file_operations.R | 491, 507, 523 | **(b)** | CSV-parsing erstattet med try_with_diagnostics — opsamler alle fejl og viser dansk detailbesked |
| app_initialization.R | 123, 134, 145, 156 | **(a)** | Init-probe, ikke-blokerende; log_debug(conditionMessage(e), .context = "APP_INIT") tilføjet |
| utils_analytics_consent.R | 90 | **(c)** | session$token læsning før session-init; NULL er forventet og håndteret |
| utils_logging.R | 119 | **(c)** | Golem-config tilgængelighed under bootstrap; NULL → falder tilbage til default log-level |
| mod_spc_chart_server.R | 177, 181 | **(c)** | UI-diagnose af tom plot-tilstand; ikke core-path; reactive context kan fejle legitimt |
| fct_file_operations.R | 687 | **(c)** | Multi-separator loop (paste-tekst); fejl per separator er forventet, best_fallback-logik håndterer totalt-fail |
| utils_bfhllm_integration.R | 27, 74, 108 | **(c)** | golem-config mangler i tests/standalone; falder tilbage til hardcoded defaults |
| utils_server_export.R | 203 | **(c)** | Hospital-navn til eksport er ikke-essentiel metadata; NULL → fallback til default |

---

## safe_operation() anti-pattern audit

Forekomster klassificeret som legitime (non-essentiel kode):

| Fil | Linje | Vurdering |
|-----|-------|----------|
| utils_analytics_consent.R | 68, 93 | Legitimt — analytics-emit og session-end callback |
| utils_analytics_pins.R | 292 | Legitimt — analytics side-effect |
| mod_export_download.R | 50 | Legitimt — export UI-handling |
| utils_lazy_loading.R | 86 | Legitimt — lazy-load side-effect |
| utils_server_wizard_gates.R | 107 | Legitimt — UI-gate refresh |
| utils_cache_generators.R | 11, 63, 110, 177 | Legitimt — cache-generation (regenererbar) |
| utils_event_context_handlers.R | 240, 291, 339 | Legitimt — event-handler side-effects |
| utils_advanced_debug.R | 180, 201, 226, 257, 285 | Legitimt — diagnostik-læsning til debug-UI |
| utils_server_events_navigation.R | 91, 102 | Legitimt — navigation side-effects |
| utils_qic_preparation.R | 189 | Legitimt — QIC metrics tracking |
| utils_server_event_listeners.R | 142 | Legitimt — event-listener side-effect |
| app_run.R | 152 | Legitimt — app-startup side-effect |

**Anti-pattern forekomster (brug af safe_operation() om core-processing):**

| Fil | Linje | Problem | Anbefaling |
|-----|-------|---------|-----------|
| utils_spc_data_processing.R | 14 | sanitize_spc_config() er core-processing; fallback=config maskerer fejl | Separat change: erstat med explicit tryCatch + stop() |
| mod_spc_chart_compute.R | 143 | Core SPC plot computation; fejl swallowed som NULL | Separat change: explicit error propagation |
| fct_file_operations.R | 265 | Fil upload orchestration er core-path | Separat change: explicit error propagation |
| utils_server_paste_data.R | 166 | Paste-data processing er core-path | Separat change: explicit error propagation |
| utils_spc_data_processing.R | 55, 120, 168, 202, 245, 278 | Yderligere SPC processing functions | Kræver separat audit + change |

> **Note:** Anti-pattern-forekomsterne er ikke rettet i denne change for at holde scope afgrænset.
> Flagget til separat change med bredere refaktoring af SPC-pipeline error handling.
