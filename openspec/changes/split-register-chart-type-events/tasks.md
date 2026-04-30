## 1. Analyse

- [x] 1.1 Læs `R/utils_server_events_chart.R::register_chart_type_events()` (574 linjer)
- [x] 1.2 Identificér state-mutations vs UI-kald vs event-emissioner i body
- [x] 1.3 Verificér at `sync_chart_type_to_state()`-pattern matcher domain-core fra `extract-pure-domain-from-shiny-shim`

## 2. Implementér pure transition

- [x] 2.1 Opret `sync_chart_type_to_state(state, new_type)` som pure funktion (returnerer ny state)
- [x] 2.2 Placér i `R/fct_chart_type_transition.R` eller eksisterende domain-core-modul
- [x] 2.3 Roxygen + @keywords internal

## 3. Implementér observer + UI-update

- [x] 3.1 Opret `observe_chart_type_input(input, session, emit, app_state)` — etablerer observer
- [x] 3.2 Opret `update_ui_for_chart_type(service, new_type, app_state)` — kalder column/form services
- [x] 3.3 Refaktorér `register_chart_type_events()` til composition: observer-body kalder `sync_chart_type_to_state()` + `update_ui_for_chart_type()`

## 4. Tests

- [x] 4.1 Opret `tests/testthat/test-sync-chart-type-to-state.R` — pure unit-tests uden Shiny
- [x] 4.2 Test alle chart-type-transitioner (run, i, mr, p, pp, u, up, c, g, t)
- [x] 4.3 Test edge-cases: NULL/tom state, ugyldig chart_type
- [ ] 4.4 Integration-test (testServer): observer kalder sync + update korrekt

## 5. Validering

- [x] 5.1 `register_chart_type_events()` reduceret til ≤150 linjer (composition only)
- [x] 5.2 `sync_chart_type_to_state()` 100% test-dækket uden Shiny
- [ ] 5.3 Manuel test: skift chart-type i UI → ingen regression
- [x] 5.4 `openspec validate split-register-chart-type-events --strict`
