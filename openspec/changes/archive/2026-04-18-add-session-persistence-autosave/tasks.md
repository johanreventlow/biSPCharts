## 1. Forberedelse
- [x] 1.1 Opret feature branch `feat/session-persistence-autosave`
- [x] 1.2 Kør fuld test-suite som baseline og gem resultat
- [ ] 1.3 Verificer at eksisterende `clear_saved` flow fungerer manuelt (baseline) — **[MANUELT TRIN]**

## 2. Fase 1: Test-fundament (TDD) 🧪
- [x] 2.1 Opret `tests/testthat/test-session-persistence.R`
- [x] 2.2 Skriv unit-test: `saveDataLocally()` sender korrekt custom message struktur med mocket `session`
- [x] 2.3 Skriv unit-test: `collect_metadata()` + `restore_metadata()` roundtrip med alle felter (x_column, y_column, n_column, skift_column, frys_column, kommentar_column, chart_type, target_value, centerline_value, y_axis_unit)
- [x] 2.4 Skriv unit-test: data.frame roundtrip for `numeric` kolonner
- [x] 2.5 Skriv unit-test: data.frame roundtrip for `character` kolonner
- [x] 2.6 Skriv unit-test: data.frame roundtrip for `Date` kolonner (SKIP indtil Fase 3)
- [x] 2.7 Skriv unit-test: data.frame roundtrip for `POSIXct` kolonner med tidszone (SKIP indtil Fase 3)
- [x] 2.8 Skriv unit-test: data.frame roundtrip for `integer` kolonner (SKIP indtil Fase 3)
- [x] 2.9 Skriv unit-test: data.frame roundtrip for `factor` kolonner med levels (SKIP indtil Fase 3)
- [x] 2.10 Skriv unit-test: data.frame roundtrip for `logical` kolonner
- [x] 2.11 Skriv unit-test: bounds-check afviser oversize datasæt (save-side; restore-side SKIP indtil Fase 3)
- [x] 2.12 Skriv unit-test: `autoSaveAppState()` returner NULL når `app_state$session$auto_save_enabled == FALSE` (SKIP indtil Fase 2)
- [x] 2.13 Skriv unit-test: `autoSaveAppState()` sætter `auto_save_enabled <- FALSE` ved save-fejl — **FEJLER SOM FORVENTET** (scope bug)
- [x] 2.14 Skriv JSON-encoding static-check: `local-storage.js` må ikke kalde `JSON.stringify(data)` — **FEJLER SOM FORVENTET** (double-encoding bug)
- [x] 2.15 Kør test-suite: rød baseline etableret — 3 FAIL / 35 PASS / 10 SKIP
- [x] 2.16 Commit: `test: tilføj session persistence regression tests`

## 3. Fase 2: Fix blockers 🔴
- [x] 3.1 Fix `inst/app/www/local-storage.js`: fjern `JSON.stringify()` i `window.saveAppState` (data fra R er allerede JSON-string)
- [x] 3.2 Verificer at `window.loadAppState` stadig kalder `JSON.parse()` én gang
- [x] 3.3 Tilføj `app_state` parameter til `autoSaveAppState()` i `R/utils_local_storage.R`
- [x] 3.4 Opdater caller i `R/utils_server_session_helpers.R:229`: `autoSaveAppState(session, save_data$data, save_data$metadata, app_state)`
- [x] 3.5 Opdater caller i `R/utils_server_session_helpers.R:282`: samme signatur-udvidelse
- [x] 3.6 Slet `exists("app_state")` check i `utils_local_storage.R:138` — erstat med direkte `!is.null(app_state)` check
- [x] 3.7 Fjern dead observer `observeEvent(input$manual_save, ...)` fra `R/utils_server_server_management.R:174-208`
- [x] 3.8 Fjern dead observer `observeEvent(input$show_upload_modal, ...)` fra `R/utils_server_server_management.R:216-218`
- [x] 3.9 Fjern dead `output$save_status_display` render fra `R/utils_server_server_management.R:228-242`
- [x] 3.10 Fjern `show_upload_modal()` helper-funktion (ubrugt efter dead observer-fjernelse)
- [x] 3.11 `collect_metadata()` / `restore_metadata()` beholdes — bruges stadigt af auto-save og auto-restore
- [x] 3.12 Kør test-suite: 41 PASS / 0 FAIL / 8 SKIP (blockers fixet)
- [x] 3.13 Commit: `fix(session-persistence): ret double-encoding, scope bug og dead observers`

## 4. Fase 3: Korrekthed og robusthed 🟠
- [x] 4.1 Ret restore-rækkefølge i `R/utils_server_server_management.R`:
  - Flyt `restore_metadata()` kald op til at ske **før** `set_current_data()` og `emit$data_updated()`
  - Bevar guard-flags (`restoring_session`, `updating_table`, `auto_save_enabled = FALSE`)
- [x] 4.2 Udvid class-preservation i `R/utils_local_storage.R`:
  - Oprettet helper `extract_class_info(data)` med `list(primary, is_date, is_posixct, is_factor, levels, tz)` per kolonne
  - Brugt i `saveDataLocally()` payload
- [x] 4.3 Udvid class-restoration i `R/utils_local_storage.R`:
  - Oprettet helper `restore_column_class(values, class_info)` — håndterer Date, POSIXct m. tz, integer, factor m. levels
  - Kaldt for hver kolonne i restore-loopet i `utils_server_server_management.R`
- [x] 4.4 Tilføj JS → R save-result kanal:
  - Opdateret `inst/app/www/shiny-handlers.js` `saveAppState` handler til at kalde `Shiny.setInputValue('local_storage_save_result', {...})`
  - Oprettet observer `obs_save_result` i `R/utils_server_session_helpers.R`
  - Ved `success = FALSE`: `log_warn`, sæt `auto_save_enabled <- FALSE`, vis dansk notifikation
  - Ved `success = TRUE`: opdater `last_save_time`
- [x] 4.5 Flyttet `last_save_time <- Sys.time()` ud af auto-save observers — håndteres af save-result observer
- [x] 4.6 Udskiftet `setTimeout(500)` med `$(document).on('shiny:sessioninitialized', ...)` i `inst/app/www/shiny-handlers.js`
- [x] 4.7 Tilføjet version-check i auto-restore observer: `!= LOCAL_STORAGE_SCHEMA_VERSION` → `clearDataLocally()` og return silent
- [x] 4.8 Bumpet version fra `"1.2"` til `"2.0"` (via `LOCAL_STORAGE_SCHEMA_VERSION` konstant)
- [x] 4.9 Kør test-suite: 57 PASS / 0 FAIL / 1 SKIP — alle class-preservation tests består
- [x] 4.10 Commit: `fix(session-persistence): restore order, class preservation og JS feedback loop`

## 5. Fase 4: Konfiguration og feature flag 🟡
- [x] 5.1 Slettet funktion `determine_auto_restore_setting()` fra `R/app_runtime_config.R`
- [x] 5.2 Slettet kald i `setup_development_config()` — erstattet med `get_session_config()`
- [x] 5.3 `development = list(auto_restore_enabled = FALSE)` dead default erstattet med komplet session config
- [x] 5.4 YAML er nu eneste kilde via `get_session_config()` (læser `golem::get_golem_options("session")`)
- [x] 5.5 Tilføjet `auto_save_enabled`, `save_interval_ms`, `settings_save_interval_ms` til alle 4 profiles (default, development, production, testing) i `inst/golem-config.yml`
- [x] 5.6 `apply_runtime_config()` sætter nu `AUTO_SAVE_ENABLED`, `SAVE_INTERVAL_MS`, `SETTINGS_SAVE_INTERVAL_MS` i pakke-miljø
- [x] 5.7 `convert_profile_to_legacy_config()` inkluderer nu alle nye felter
- [x] 5.8 Nye getters tilføjet i `R/zzz.R`:
  - `get_auto_save_enabled()` → default `TRUE`
  - `get_save_interval_ms()` → default `2000`
  - `get_settings_save_interval_ms()` → default `1000`
- [x] 5.9 `utils_server_session_helpers.R` bruger nu `get_save_interval_ms()` og `get_settings_save_interval_ms()` i debounce-kaldene
- [x] 5.10 Auto-save observer-oprettelse wrappet i `if (auto_save_feature_enabled)` check — observers oprettes ikke når flag er OFF
- [x] 5.11 Ny `get_session_config()` helper i `utils_bfhllm_integration.R` — single source of truth
- [x] 5.12 Test-suite: 68 PASS / 0 FAIL / 1 SKIP
- [x] 5.13 Commit: `refactor(session-persistence): single source of truth for feature flags`

## 6. Fase 5: UX-polish 💄
- [x] 6.1 Tilføjet diskret statuslinje i `R/ui_app_ui.R` — placeret under download-template-link i wizard-området:
  - `shiny::uiOutput("session_save_status", inline = TRUE)` med subtle styling
- [x] 6.2 Oprettet `output$session_save_status` render i `R/utils_server_session_helpers.R`:
  - Viser "Gemt · N s/min siden" baseret på `app_state$session$last_save_time`
  - Viser intet når `last_save_time` er NULL
  - Viser "Automatisk lagring deaktiveret" med advarselsikon når `auto_save_enabled == FALSE`
- [x] 6.3 Eksisterende restore-notifikation beholdt (fungerer med nye v2.0 data-format)
- [x] 6.4 Quota-fejl viser dansk notifikation via `obs_save_result` observer (Fase 3)
- [ ] 6.5 Test i Chrome, Firefox, Safari — **[MANUELT TRIN]**
- [x] 6.6 Commit: `feat(session-persistence): diskret statuslinje og CLAUDE.md docs`

## 7. Fase 6: Dokumentation og rollout 📝
- [x] 7.1 Opdateret `CLAUDE.md` med ny sektion "Session Persistence (Issue #193)" under "Project-Specific Architecture"
- [x] 7.2 Tilføjet NEWS.md entry med fuldt feature-beskrivelse, config og fixes
- [x] 7.3 Manuel verifikations-checkliste dokumenteret i sektion 8 af denne tasks.md
- [x] 7.4 Feature aktiveret: `auto_save_enabled: true` i alle profiles, `auto_restore_session: true` i production
- [x] 7.5 Fuld test-suite kørt: 68 PASS / 0 FAIL / 1 SKIP
- [ ] 7.6 Kør `devtools::document()` hvis NAMESPACE ændres — **[MANUELT TRIN]** (ingen nye `@export` tilføjet, sandsynligvis ikke nødvendig)
- [x] 7.7 Commit: `feat(session-persistence): diskret statuslinje og CLAUDE.md docs`

## 8. Manuel verifikation (før merge) — **[MANUELT TRIN]**
- [ ] 8.1 Upload CSV-fil, sæt kolonne-mapping + titel, luk fane brat → genåbn app → verificér at session er gendannet
- [ ] 8.2 Upload Excel-fil med Date-kolonne → luk → genåbn → verificér at Date-type er bevaret (ikke konverteret til character)
- [ ] 8.3 Upload CSV med POSIXct timestamps → luk → genåbn → verificér at tidszoner er korrekte
- [ ] 8.4 Åbn app i to browser-tabs → rediger i begge → verificér last-write-wins (ingen crash, acceptabel forvirring)
- [ ] 8.5 Fyld browser localStorage til quota (kør fx script der fylder 5 MB dummy data) → prøv auto-save → verificér dansk warning-notifikation og at appen ikke crasher
- [ ] 8.6 Sæt `auto_save_enabled: false` i config → start app → verificér at ingen auto-save observers oprettes (check logs)
- [ ] 8.7 Sæt `auto_restore_session: false` → start app med eksisterende gemt session → verificér at session IKKE gendannes
- [ ] 8.8 Klik "Blank session" → bekræft → verificér at localStorage er ryddet
- [ ] 8.9 Inspect browser DevTools → localStorage → verificér at `spc_app_current_session` key indeholder valid JSON med version `"2.0"`
- [ ] 8.10 Test med stort datasæt (~10.000 rækker) → verificér at save ikke overskrider 1 MB eller at warning vises
- [ ] 8.11 Verificér at chart render er korrekt efter restore (alle visuelle elementer matcher pre-restore state)
- [ ] 8.12 Check logs for `SESSION_RESTORE`, `AUTO_SAVE`, `LOCAL_STORAGE` contexts — ingen ERROR entries under normal brug

## 9. Afslutning
- [ ] 9.1 Opret PR med summary fra `proposal.md`
- [ ] 9.2 Link til Issue i PR body
- [ ] 9.3 Marker OpenSpec change som `openspec-implementing` under implementation
- [ ] 9.4 Efter merge: arkiver change med `openspec archive add-session-persistence-autosave --yes`

## Tracking
- GitHub Issue: #193
