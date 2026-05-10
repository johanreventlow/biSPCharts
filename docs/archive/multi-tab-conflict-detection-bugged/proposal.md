## Why

Cycle B reactive-state-+-persistence-review (`docs/reviews/02-reactive-state-persistence.md`) identificerede silent data-loss-risk i localStorage-persistence-laget, verificeret empirisk af Codex peer-review:

`saveAppState()` skriver altid til `spc_app_current_session`-key uden tab-UUID, compare-and-swap, `storage`-event-handling eller newer-save-warning. To tabs af samme app paa samme domæne → silent last-write-wins. Bruger der restorer eller editter parallelt i to tabs kan overskrive nyere session uden warning.

**Real-world-frekvens lav,** men silent data-loss = brittle. Ingen mitigation eller dokumentation findes i dag.

## What Changes

### JS-side (`inst/app/www/local-storage.js`)
- Generer per-tab UUID ved load (`crypto.randomUUID()`)
- Inkluder UUID + `last_modified` (epoch-ms) i hver `saveAppState()`-payload
- Lyt til `window.storage`-event for at detektere skriv fra anden tab
- Ved storage-event: hvis other-tab's UUID ≠ current og `last_modified` > vores `session_loaded_at`: trigger advarsel via `Shiny.setInputValue("multi_tab_conflict_detected", ...)`

### R-side
- Ny observer i `R/utils_server_server_management.R`: håndterer `input$multi_tab_conflict_detected` → vis `shinyalert::shinyalert()` modal med valg:
  - **Behold mit arbejde** (overrider next save, ignorerer warning indtil næste konflikt)
  - **Overtag andens arbejde** (clear current state, restore fra localStorage)
- Pre-save-check: hvis localStorage-modifikation efter `session_loaded_at` → block save + show konflikt-modal

### Test changes
- Ny `tests/testthat/test-multi-tab-conflict.R`:
  - Mock JS storage-event → verificer R-observer triggers modal
  - Verificer payload-struktur indeholder UUID + timestamp
  - Verificer pre-save-check blokerer ved konflikt

### Documentation
- Opdatér `docs/adr/ADR-005-session-persistence-localstorage.md` med multi-tab-section
- Tilføj user-guide-note i `docs/CONTRIBUTING.md` (eller relevant doc)

## Impact

- **Affected specs:** `session-persistence` (MODIFIED — udvider med multi-tab-handling)
- **Affected code:**
  - Modificeret: `inst/app/www/local-storage.js` (UUID + storage-event + payload-format)
  - Modificeret: `R/utils_local_storage.R` (payload-format-validation)
  - Modificeret: `R/utils_server_server_management.R` (observer + modal-handler)
  - Ny: `tests/testthat/test-multi-tab-conflict.R`
  - Modificeret: `docs/adr/ADR-005-session-persistence-localstorage.md`

- **Behavioral impact:**
  - Ny modal når multi-tab-konflikt detekteres
  - Payload-format-skift = schema-version-bump (LOCAL_STORAGE_SCHEMA_VERSION 3.0 → 4.0) — kræver migration
  - Eksisterende sessioner uden UUID: behandles som "anonymous tab" (warn én gang, herefter normal)

- **Risk:**
  - Modal-spam hvis bruger har 3+ tabs aabne samtidig (mitigation: rate-limit modal til 1 per 30s)
  - Migration-edge-case: 3.0 payloads uden UUID skal kunne læses

## Related

- Cycle B-review: `docs/reviews/02-reactive-state-persistence.md` (M5)
- Codex empirisk verifikation: 2026-05-09
- ADR-005 (session-persistence localStorage)
