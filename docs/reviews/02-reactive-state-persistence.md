# Review #02 — Reactive State + Persistence

**Dato:** 2026-05-09
**Reviewer:** Claude (3 paralleled Explore-agents) + Codex (GPT-5) adversarial-review
**Status:** Reconciled efter Codex peer-review

## Scope

Konsolideret cycle B (original #1 + #3):
- **Reactive state:** state_management.R, utils_server_event_listeners.R, utils_event_context_handlers.R, ADR-003/004/006
- **Persistence:** utils_local_storage.R, utils_server_session_helpers.R, local-storage.js, ADR-005

## Reconciled findings (efter Codex peer-review)

### 🔴 HIGH — bekræftet user-visible risk

#### M2 → PROMOTERET TIL HIGH efter Codex-verifikation: Double-emit `navigation_changed` causerer pre-autodetect render
**Lokation:** `R/fct_file_operations.R:363-376` (Excel-load), `:493` (session-file-load), `:628` (paste-data)
**Symptom (Codex bekræftet):** Standard load-paths emitter `data_updated("file_loaded")` OG direct `emit$navigation_changed()` umiddelbart efter. Data-update-dispatcher behandler load-context som autodetect-only; tests asserter at navigation først fires via `auto_detection_completed → ui_sync_needed → ui_sync_completed → navigation_changed`.

**Konsekvens (NY indsigt fra Codex — ikke bare counter-nit):** Direct emit skaber **pre-autodetect navigation-invalidering** → første render bruger stale/incomplete column-mappings → derefter andet render efter UI-sync. Bruger ser glitch eller forkert plot kortvarigt.

**Fix:** Slet direkte `emit$navigation_changed()` fra load-paths (`file_loaded`, `session_file_loaded`, `paste_data`). Lad data_updated→autodetect→UI-sync-cascade være eneste navigation-source. Tilføj regression-test på upload/paste-handler-niveau.

### 🟡 MEDIUM — bekræftet af Codex

#### M5 (uændret) — Multi-tab silent overskriving
**Lokation:** `inst/app/www/local-storage.js:51-54`
**Symptom (Codex bekræftet):** `saveAppState()` skriver altid til `spc_app_current_session`-key uden tab/session-UUID, compare-and-swap, `storage`-event-handling, eller newer-save-warning. To tabs på samme domæne → silent last-write-wins.
**Konsekvens:** Bruger der restorer eller editter parallelt i to tabs kan overskrive nyere session uden warning.
**Fix:** Inkluder per-tab/session-id + last-modified-timestamp i payload. Før save/restore: detect localStorage-modifikation fra anden tab efter denne session startede → block eller warn i stedet for silent overwrite.

#### M7 (uændret) — `save_session_on_exit` config-flag ignoreres = persistence contract violation
**Lokation:** `R/app_server_main.R:301-315` (cleanup-handler) + `inst/golem-config.yml:271`
**Symptom (Codex bekræftet):** Production config sætter `save_session_on_exit: true`. Server cleanup stopper kun background-tasks + observers. Repo-search viser INGEN kode der læser `save_session_on_exit`. Data/settings-saves er debounced 2000ms/1000ms → tab-luk inden for vinduet mister sidste edits, selv om production-config siger exit-save.
**Konsekvens:** Persistence-contract-violation, ej bare dead config.
**Fix:** Implementer final-save-path gated by `get_session_config()$save_session_on_exit` FØR cleanup deaktiverer observers/background-state. ELLER: fjern production-flag + dokumentér at kun debounced autosave understøttes.

### ❌ DISMISSED efter Codex-verifikation

#### H1 (auto_detection_completed direct mutation) — DISMISSED
**Hvorfor:** Codex fandt at `transition_autodetect_complete()` ALLEREDE udfører atomic completion-update FØR observer kører. Direct mutations på linje 168-169 er post-transition-cleanup, ikke primary state-skift.
**Aktion:** Lavprio kosmetisk ADR-004-cleanup hvis ønsket; ej blokerende.

#### M3 (cleanup_expired_queue_updates orphan) — DISMISSED
**Hvorfor:** Codex fandt at funktionen ER kaldt via `comprehensive_system_cleanup()` scheduled fra `setup_background_tasks()`. Min subagent's grep var ufuldstændig (tjekkede kun direct callers, ej call-graph).
**Aktion:** Ingen — fungerer som designet.

### 🟡 MEDIUM — IKKE-VERIFICERET (Codex fokuserede ikke på disse)

Disse M-fund stammer fra subagent-rapporter; Codex tog ej eksplicit stilling. Behold som svagere prio indtil verificeret.

#### M1 — `column_choices_changed` orphan event
**Lokation:** Emit defineret state_management.R:559, kaldt utils_server_column_input.R:117-128. **Ingen listener.**
**Konsekvens:** Dead code; potentiel skjult cascade hvis nogen senere tilføjer listener.
**Fix:** Slet emit + counter-init. (Bekræfter fund fra perf-review-session, stadig ej fjernet.)

#### M2 — FLYTTET TIL HIGH ovenfor (Codex bekræftede som user-visible UX-bug)

#### M3 — DISMISSED ovenfor (Codex bekræftede cleanup ER kaldt via comprehensive_system_cleanup)

#### M4 — `QuotaExceededError` JS→R feedback mangler
**Lokation:** `inst/app/www/local-storage.js:51-59`
**Symptom:** JS catch returnerer `false` ved quota-exceeded men sender ikke besked tilbage til R via `Shiny.setInputValue`. Bruger ser kun console-error. R-side har 1MB pre-check (R/utils_local_storage.R:326) som dækker normale tilfælde, men edge-cases (browser med fyldt localStorage fra andre apps) får silent-fail.
**Fix:** JS sender `Shiny.setInputValue("local_storage_save_result", {success: false, error: "quota"})` ved fail. R-side observer tilbyder retry/disable-auto-save UX.

#### M5 — Multi-tab-conflict silent overskriving
**Lokation:** localStorage er shared mellem tabs på samme domæne; ingen koordination implementeret.
**Symptom:** To tabs af samme app → sidste-write vinder uden warning. Bruger der arbejder i to tabs samtidigt mister muligvis data fra ene tab.
**Vurdering:** Lav real-world-frekvens, men silent data-loss = brittle.
**Fix:** Tilføj timestamp + UUID i payload; ved restore: hvis storage timestamp > session start, advarer bruger.

#### M6 — TTL-expiry mangler test-coverage
**Lokation:** `inst/app/www/local-storage.js:18-40` (`spc_expire_stale_sessions`); ingen test.
**Symptom:** TTL-logik (`localstorage_ttl_minutes: 480`) er korrekt implementeret men ej dækket af tests. Risk for bitrot ved config-skift.
**Fix:** Tilføj `tests/testthat/test-localstorage-ttl.R` med mocked timestamp + verifikation af clear.

#### M7 — `save_session_on_exit` config-flag ignoreres
**Lokation:** `inst/golem-config.yml:271` (production: `save_session_on_exit: true`); ingen kode-implementation.
**Symptom:** Final-flush før session-end ej implementeret. Sidste edits i 2s debounce-vindue mistes hvis bruger lukker tab.
**Vurdering:** Lav impact givet TTL + browser-refresh-pattern, men config-flag uden funktion er forvirrende.
**Fix:** Implementer `session$onSessionEnded(autoSaveAppState(...))` eller fjern config-flag.

#### M8 — `test_data_loaded`-context falder til "general"
**Lokation:** `R/app_server_main.R:155` emitter `data_updated(context="test_data_loaded")`. `classify_update_context()` (utils_event_context_handlers.R:68-110) matcher ikke — falder til general → ingen plot-update.
**Mitigering:** `session_started`-observer trigger autodetect uafhængigt → fungerer i praksis.
**Fix:** Tilføj `test_data_loaded` til `load`-kategori i classifier (eksplicit i stedet for tilfældig grepl-mismatch).

#### M9 — Race-condition-test-coverage mangler
**Lokation:** `tests/testthat/` — 0 matches på `concurrent|parallel|race`.
**Symptom:** ADR-006's 5-lags anti-race-strategi ej eksplicit verificeret. Guards eksisterer (is_restoring_session) men races ej testet.
**Fix:** Tilføj integration-tests for: (a) concurrent data_updated-listeners, (b) ui_sync under queue_processing, (c) session_restore + autodetect-overlap.

#### M10 — Form-observer LOW-priority (race-risk)
**Lokation:** `R/utils_server_event_listeners.R:110-132` — `form_reset_with_ui` + `form_restore_with_ui` bruger `OBSERVER_PRIORITIES$LOW (750)`.
**Symptom:** Form-observers kører på samme priority som UI_SYNC — race hvis begge observerer samme trigger.
**Fix:** Dokumenter intentionel valg eller hæv til CRITICAL/HIGH.

#### M11 — Event-naming inkonsistens
**Lokation:** `R/state_management.R:65-101`
**Symptom:** ADR-003 specificerer past-tense ("data_loaded", "completed"). Faktisk mix:
- Past-tense: `data_updated`, `auto_detection_completed`, `column_choices_changed`
- Present-passive: `ui_sync_requested`, `visualization_update_needed`, `form_reset_needed`, `form_restore_needed`
**Vurdering:** Kosmetisk men forvirrende for nye contributors (er `requested` trigger eller completed-state?).
**Fix:** Refactor til konsistent past-tense ELLER opdater ADR-003 til at acceptere både.

### 🟢 LOW — dokumentations-drift

#### L1 — `file_upload`-context nævnt i docs men ej i produktion
**Lokation:** Docs / ADR-3 nævner `context = "file_upload"` men faktisk emit'es `file_loaded`, `session_file_loaded`, `paste_data`. Ingen `file_upload`.
**Fix:** Opdater docs eller alias `file_upload` → `file_loaded` for kompatibilitet.

#### L2 — Test mangler for `new_session`-context-fallback
**Lokation:** `tests/testthat/test-event-context-handlers.R` har ej test for `new_session`-context (falder til general).
**Fix:** Tilføj test der eksplicit verificerer `new_session` ej trigger autodetect (intentionelt).

## Hvad er ALLEREDE solidt (verificeret)

✅ Cascade-chains er **acykliske** — ingen infinite-loop-risk (Agent 1 static-analysis).
✅ Schema-version-gate (`LOCAL_STORAGE_SCHEMA_VERSION = "3.0"`) — hard-reject ved mismatch + silent forward-migration.
✅ Class-preservation per kolonne — Date/POSIXct/factor roundtrips korrekt med whitelist mod DevTools-attacks.
✅ Restore-guards (`is_restoring_session`-flag) checkes konsekvent i autodetect + auto-save.
✅ Auto-save-debounce respekterer guards (data 2s, settings 1s).
✅ JS-bridge: ingen double-encoding bug (Issue #193 fix verified).
✅ Observer-priorities for data-lifecycle korrekte (STATE_MANAGEMENT > AUTO_DETECT > UI_SYNC).
✅ session_restore-context skipper autodetect (preserve saved mappings) — verificeret i tests.

## Reconciled prioritering (post-Codex)

| Prio | Fund | Lokation | Status | Type |
|------|------|----------|--------|------|
| **HIGH** | M2→H | `R/fct_file_operations.R:363-376, 493, 628` | Codex bekræftet user-visible UX-bug | Slet direct emit + regression-test |
| **MED** | M5 | `inst/app/www/local-storage.js:51-54` | Codex bekræftet | Multi-tab UUID + timestamp |
| **MED** | M7 | `R/app_server_main.R:301-315` + `inst/golem-config.yml:271` | Codex bekræftet contract-violation | Implementer eller fjern config |
| MED | M1, M4, M6, M8-M11 | (se ovenfor) | Ikke verificeret af Codex | Behold som lavprio |
| LOW | L1, L2 | docs + tests | Ikke verificeret | Doc-cleanup |
| ❌ | H1, M3 | DISMISSED | Codex empirisk | Ingen aktion |

## Læringer fra cycle B reconcile

1. **Subagent's "intet kalder X"-claims kan være ufuldstændige.** M3 dismissed fordi grep missede call-graph (`cleanup_expired_queue_updates` kaldes via `comprehensive_system_cleanup`). Lesson: følg call-graph, ej kun direct callers.

2. **Codex's empiriske focus reframer prioritet.** Min M2 var "counter-nit"; Codex viste det er reel UX-bug (pre-autodetect render → stale columns). Promoter til HIGH.

3. **Atomic-update-violation-claim kræver dyb forståelse af transition-flow.** H1 dismissed fordi `transition_autodetect_complete()` udfører atomic update FØR observer. Subagent missede transition-pattern-context.

4. **Test-coverage-gap-fund (M6, M9) er svagt evidens.** Codex tog ej stilling — kan være valide men har lav implementeringsprioritet.

## Implementations-anbefaling

**OpenSpec-tærskel-vurdering:**
- **M2-til-HIGH (double-emit)** = behavioral fix, ingen breaking change. **Direkte commit + regression-test**. Ej OpenSpec.
- **M5 (multi-tab)** = ny feature (UUID + timestamp + storage-event-handler). **OpenSpec proposal** "multi-tab-conflict-detection".
- **M7 (save_session_on_exit)** = bevarelse af eksisterende contract. **Direkte commit** (implementér final-flush). Ej OpenSpec.
- M1, M4, M6, M8-M11: hvis implementeret, direkte commits med tests.

**Implementation-rækkefølge:**
1. **PR 1**: M2 fix (slet direct emits + regression-tests) — KRITISK UX-bug
2. **PR 2**: M7 fix (final-flush implementation) — persistence-contract
3. **OpenSpec proposal**: M5 multi-tab-detection
4. **Optional cleanup-PR**: M1 + M11 + L1 + L2 (kode-hygiejne)

**Estimat:** ~2-3 timer for PR 1+2; M5 OpenSpec separat (~3-4 timer).

## Næste skridt

✅ **Cycle B komplet.** Afventer bruger-godkendelse til implementation.
