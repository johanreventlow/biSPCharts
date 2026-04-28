## ADDED Requirements

### Requirement: register_chart_type_events SHALL være splittet efter ansvar

Funktionen `register_chart_type_events()` (i `R/utils_server_events_chart.R`) SHALL være splittet i tre separate funktioner:

- `observe_chart_type_input(input, session, emit, app_state)` — observerer kun input-ændring
- `sync_chart_type_to_state(state, new_type)` — pure state-transition, ingen Shiny-imports
- `update_ui_for_chart_type(service, new_type, app_state)` — UI-kald via column/form services

`register_chart_type_events()` selv SHALL reduceres til composition (≤150 linjer).

#### Scenario: Sync er pure og testable

- **GIVEN** unit-test for `sync_chart_type_to_state(state, "run")` kører uden Shiny
- **THEN** funktionen returnerer ny state med `columns$mappings$chart_type = "run"`
- **AND** ingen Shiny-imports eller reactive context kræves

#### Scenario: Composition i setup

- **GIVEN** `setup_event_listeners()` kaldes ved session-init
- **WHEN** chart-type-observers initialiseres
- **THEN** `observe_chart_type_input(...)` etablerer observer
- **AND** observer-body kalder `sync_chart_type_to_state()` + `update_ui_for_chart_type()`
- **AND** hver af de tre kan mockes eller stubbes separat i tests

#### Scenario: Linjetælling

- **WHEN** `wc -l R/utils_server_events_chart.R` kører efter split
- **THEN** `register_chart_type_events()`-body er ≤150 linjer (composition only)
- **AND** øvrig logik er flyttet til de tre nye funktioner
