## Why

Følge-op til `split-monolithic-ui-update-service` (archived 2026-04-28). Audit (2026-04-30) afslørede at to af de tre felter på `app_state$ui` der oprindeligt skulle "extract'es til observer-env" faktisk er **dead state** — defineret i `R/state_management.R` men ingen produktionskode populerer felterne:

- `pending_programmatic_inputs` (`R/state_management.R:221`): læses og ryddes defensivt i 4 observer-bodies (`R/utils_server_events_chart.R:117/177/287`, `R/utils_server_column_input.R:86`) men ingen producent eksisterer i `R/`. Producent forsvandt i refaktor `a4c1c399 fix: fjern GlobalEnv mutation` uden tilsvarende consumer-cleanup.
- `programmatic_token_counter` (`R/state_management.R:222`): kun definitionen findes i `R/`. Ingen reader/writer i produktionskode. Kun tests skriver til feltet (test af pure plumbing).

Det tredje felt — `queued_updates` — er derimod **legitim session-global queue-infrastruktur** der serialiserer concurrent UI-opdateringer på tværs af observere via `safe_programmatic_ui_update()` + `process_ui_update_queue()` + `enqueue_ui_update()` + `cleanup_expired_queue_updates()`. Flytning til observer-scoped env ville bryde queue-kontraktens cross-observer-serialisering.

**Scope-amendment 2026-04-30:** Det oprindelige proposal foreslog at flytte alle 3 felter til observer-scoped env. Audit afdækkede at 2 felter er dead state (skal slettes, ikke flyttes) og 1 felt er legitim session-state (skal blive på `app_state$ui`). Spec og tasks er omskrevet til den smallere dead-state-cleanup-scope.

## What Changes

- **Slet** `pending_programmatic_inputs` fra `app_state$ui` definition (`R/state_management.R`)
- **Slet** `programmatic_token_counter` fra `app_state$ui` definition (`R/state_management.R`)
- **Fjern** dead read-and-clear-blocks for `pending_programmatic_inputs[[col_name]]` i 4 observer-bodies:
  - `R/utils_server_events_chart.R:117-119` (chart_type)
  - `R/utils_server_events_chart.R:177-181` (y_axis_unit)
  - `R/utils_server_events_chart.R:287-291` (n_column)
  - `R/utils_server_column_input.R:86-90` (col_name)
- **Slet** `tests/testthat/test-ui-token-management.R` (kun plumbing-tests af dead state — første test asserterer at sætte counter persisterer; anden test asserterer at sætte `queue_processing` flag persisterer. Ingen produktionsadfærd testet)
- **Ryd op** test-fixtures der initialiserer fjernede felter (`tests/testthat/helper-fixtures.R`, `test-event-system-observers.R`, `test-ui-update-service-column.R`, `test-ui-update-service-form.R`, `test-column-observer-consolidation.R`, `test-mod-spc-chart-comprehensive.R`)
- **Bibehold** `queued_updates` på `app_state$ui`. Tilføj kort kommentar i `state_management.R` der dokumenterer feltet som legitim session-global queue.

## Impact

- **Affected specs**: `ui-update-service` (ADDED — krav om at `app_state$ui` ikke holder dead token-state)
- **Affected code**:
  - Modificeret: `R/state_management.R` (slet 2 felter, dokumentér 1)
  - Modificeret: `R/utils_server_events_chart.R` (~12 linjer fjernes)
  - Modificeret: `R/utils_server_column_input.R` (~5 linjer fjernes)
  - Slettet: `tests/testthat/test-ui-token-management.R` (~85 linjer)
  - Modificeret: 5 test-fixture-filer (~12 linjer)

**Breaking change-risiko:** Lav. Dead state — ingen produktionskode er afhængig af felterne. Test-suite-cleanup eneste consumer-side change.

## Related

- Forløb: `split-monolithic-ui-update-service` (archived 2026-04-28)
- GitHub Issue #321 (parent tracking)
- Audit-historik: producent for `pending_programmatic_inputs` introduceret i `216acec5 feat(token-system): implementer Fase 1 token-baseret loop protection`, fjernet i `a4c1c399 fix: fjern GlobalEnv mutation i safe_programmatic_ui_update`
