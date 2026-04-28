## Why

Følge-op til `split-monolithic-ui-update-service` (archived 2026-04-28). Funktionen `register_chart_type_events()` i `R/utils_server_events_chart.R` (574 linjer) blander:

- Input-observation (`input$chart_type`)
- Column-normalization
- Cache-invalidation
- UI-opdatering (selectizeInput-refresh)
- Event-emission

Denne sammenblanding forhindrer unit-test af logikken uden Shiny-runtime. Med `extract-pure-domain-from-shiny-shim` nu archived (2026-04-28) er `sync_chart_type_to_state()` som pure transition unblocked.

## What Changes

Split `register_chart_type_events()` i tre separate funktioner:

- `observe_chart_type_input(input, session, emit, app_state)` — observerer kun `input$chart_type`-ændring, kalder ned i de øvrige
- `sync_chart_type_to_state(state, new_type)` — pure state-transition, returnerer ny state. Ingen Shiny-imports, ingen reactive context. Testable uden Shiny-runtime.
- `update_ui_for_chart_type(service, new_type, app_state)` — UI-kald via column/form services

Composition: `observe_chart_type_input()` etablerer observer; observer-body kalder `sync_chart_type_to_state()` (state-update) + `update_ui_for_chart_type()` (UI-update).

## Impact

- **Affected specs**: `ui-update-service` (ADDED — ny requirement om register_chart_type-split)
- **Affected code**:
  - Modificeret: `R/utils_server_events_chart.R` (574 → forventet ~3 × 100-150 linjer)
  - Ny: `tests/testthat/test-sync-chart-type-to-state.R` (pure unit-tests)
  - Modificeret: `R/utils_server_initialization.R` eller hvor `register_chart_type_events()` kaldes

**Breaking change-risiko:** Lav. `register_chart_type_events()` er intern. Ingen API-ændring eksternt.

## Related

- Forløb: `split-monolithic-ui-update-service` (archived 2026-04-28-split-monolithic-ui-update-service)
- Afhængighed (nu løst): `extract-pure-domain-from-shiny-shim` (archived 2026-04-28-extract-pure-domain-from-shiny-shim)
- GitHub Issue #321 (parent tracking)
