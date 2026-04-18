## Why

biSPCharts har en delvist implementeret auto-save/session-restore-funktion til browser `localStorage`, men den er i øjeblikket ubrugelig i praksis pga. tre kritiske fejl og en halvt fjernet UI:

1. **Dobbelt JSON-encoding** mellem R og JavaScript — `jsonlite::toJSON()` returnerer en allerede-serialiseret string, som derefter `JSON.stringify()`'es igen i `local-storage.js`. Roundtrip er brudt.
2. **Broken scope** i `autoSaveAppState()` — funktionen forsøger at deaktivere auto-save via `exists("app_state")`, men `app_state` er ikke i scope, så fejlhåndteringen virker aldrig.
3. **Dead UI observers** — serveren lytter stadig på `input$manual_save`, `input$show_upload_modal` og renderer `output$save_status_display`, men de tilsvarende UI-elementer er fjernet fra `ui_app_ui.R`. Kun `clear_saved` ("Blank session") har stadig en knap.
4. **Race condition i restore-flow** — `emit$data_updated(context = "session_restore")` fyrer **før** `restore_metadata()` kaldes, hvilket betyder at downstream listeners (auto-detect, chart render) kører med tom kolonne-mapping.
5. **Begrænset class-preservation** — kun `numeric`, `character` og `logical` kan roundtrippes. `Date`, `POSIXct`, `integer` og `factor` konverteres stille til forkerte typer.
6. **Inkonsistent feature flag** — to parallelle paths sætter `AUTO_RESTORE_ENABLED` (hardkodede defaults i `determine_auto_restore_setting()` og YAML i `inst/golem-config.yml`), med uklar prioritet.
7. **Ingen fejl-kanal JS → R** — hvis `localStorage.setItem()` kaster `QuotaExceededError`, fanges det i JS men rapporteres aldrig tilbage til R. `last_save_time` opdateres, selvom save fejlede.
8. **Hardkodet `setTimeout(500)`** ved auto-restore i stedet for at lytte på `shiny:sessioninitialized`.

Features var tidligere udviklet men holdt tilbage under aktiv udvikling. Brugere i klinisk kvalitetsarbejde mister deres arbejde ved forbindelsestab, browser-crash eller utilsigtet luk — hvilket er frustrerende når man lige har sat kolonne-mapping, titel, target-værdi og chart-type op.

Dette change gen-aktiverer funktionen med alle fixes og tilpasser den til appens nuværende arkitektur (event-bus, `safe_operation()`, hierarkisk `app_state`, `ui_service`).

## What Changes

### Fase 1: Test-fundament (TDD)
- Opret `tests/testthat/test-session-persistence.R` med unit- og roundtrip-tests
- Tests skal fejle før fix og bestå efter — dokumenterer alle kendte bugs

### Fase 2: Fix blockers
- **Fjern double JSON-encoding** i `inst/app/www/local-storage.js` — data fra R er allerede en JSON-string
- **Tilføj `app_state` parameter** til `autoSaveAppState()` og opdater callers i `utils_server_session_helpers.R`
- **Fjern dead observers** (`manual_save`, `show_upload_modal`, `save_status_display`) fra `utils_server_server_management.R` — behold kun `clear_saved` + auto-restore flow

### Fase 3: Korrekthed og robusthed
- **Ret restore-rækkefølge**: kald `restore_metadata()` før `emit$data_updated()` så downstream listeners ser korrekt kolonne-mapping
- **Udvid class-preservation** til `Date`, `POSIXct`, `integer`, `factor` (med levels)
- **JS → R fejl-kanal**: rapportér `saveAppState` success/failure via `Shiny.setInputValue("local_storage_save_result", …)` og reagér i server med notifikation + `auto_save_enabled <- FALSE` ved fejl
- **Udskift `setTimeout(500)`** med `$(document).on('shiny:sessioninitialized', …)`
- **Udvid bounds-check** til også at validere `class_info` og `metadata` strukturer

### Fase 4: Konfiguration og feature flag
- **Slet** `determine_auto_restore_setting()` og dens kald i `setup_development_config()`
- **Lad kun `convert_profile_to_legacy_config()`** læse `auto_restore_session` fra `inst/golem-config.yml` (single source of truth)
- **Tilføj ny config** `auto_save_enabled` (separat fra `auto_restore_session`) i YAML
- **Tilføj getters**: `get_auto_save_enabled()`, `get_save_interval_ms()`
- **Respekt flag på server-side**: opret ikke auto-save observers hvis `get_auto_save_enabled()` er FALSE

### Fase 5: UX-polish
- **Lille diskret statuslinje** i wizard-bjælken: *"Indstillinger gemt · 30s siden"* (bindet til `app_state$session$last_save_time`)
- **Første-gangs notifikation** ved auto-restore: *"Tidligere session automatisk genindlæst · N datapunkter fra DD-MM-YYYY HH:MM"* (eksisterer allerede, behold)
- **Graceful fallback** ved quota-fejl: vis dansk notifikation, deaktiver auto-save resten af session

### Fase 6: Dokumentation
- Opdater `CLAUDE.md` med sektion om session persistence
- Tilføj entry i `NEWS.md`
- Dokumentér manuel verifikations-checkliste

## Impact

- **Affected specs**: Ny capability `session-persistence` (eksisterer ikke i `openspec/specs/` endnu)
- **Affected code**:
  - `R/utils_local_storage.R` (refactor `autoSaveAppState` signatur, udvid class-preservation)
  - `R/utils_server_server_management.R` (fjern dead observers, ret restore-rækkefølge)
  - `R/utils_server_session_helpers.R` (opdater auto-save callers, tilføj save-result observer)
  - `R/app_runtime_config.R` (slet `determine_auto_restore_setting()`)
  - `R/app_initialization.R` (fjern dead auto_restore default)
  - `R/zzz.R` (tilføj nye getters)
  - `R/config_system_config.R` (ryd op i `AUTOSAVE_DELAYS`)
  - `R/ui_app_ui.R` (tilføj statuslinje i wizard-bjælken)
  - `inst/golem-config.yml` (ny `auto_save_enabled` nøgle)
  - `inst/app/www/local-storage.js` (fjern double-stringify)
  - `inst/app/www/shiny-handlers.js` (udskift setTimeout med shiny event, tilføj save-result rapportering)
  - `tests/testthat/test-session-persistence.R` (NY fil)
  - `CLAUDE.md` + `NEWS.md`
- **Affected user flows**: Upload → crash → genåbn app → kolonne-mapping, titel, chart-type, target-værdi og rådata gendannes automatisk. Brugeren ser kort notifikation om restore.
- **Breaking changes**: Ingen brugervendte. Gammel `v1.2` localStorage-format detekteres og ryddes ved første opstart efter rollout.
- **Performance**: Auto-save er debounced (2s data, 1s settings) — ingen mærkbar impact. Payload-størrelse er bounded (1 MB).
- **Risiko**: Lav-medium. Roundtrip-test dækker kernebugs. Gradual rollout via feature flag i `golem-config.yml`.

## Related
- GitHub Issue: #193
- Issue #164 (tidligere session metadata roundtrip fix)
- Issue #168 (tidligere session roundtrip regression tests)
- Se også `add-session-file-export` (planlagt separat change for download/upload af projektfil til disk)
