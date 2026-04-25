## ADDED Requirements

### Requirement: UI-update-services SHALL være splittet efter operation-type

UI-opdateringslogik SHALL organiseres i tre separate services: `create_column_update_service(session)`, `create_form_update_service(session)`, `create_table_update_service(session)`. Ingen enkelt service SHALL overstige 250 linjer (ekskl. roxygen), og hver SHALL kun håndtere én operation-type.

#### Scenario: Column-input-opdatering

- **GIVEN** observer har brug for at opdatere kolonne-selectizeInput
- **WHEN** koden kalder `col_service$update(id, choices, selected)`
- **THEN** service håndterer token-protection + debounce + `shiny::updateSelectizeInput`-kald
- **AND** form-ops eller table-ops er ikke involveret

#### Scenario: Linjetælling per service

- **WHEN** `wc -l R/utils_ui_column_update_service.R` kører
- **THEN** resultat er ≤250 linjer
- **AND** samme for form- og table-services

### Requirement: UI-opdaterings-tokens SHALL holdes i observer-local env

Token-baseret loop-protection (pending_programmatic_inputs, programmatic_token_counter, queued_updates) SHALL opholde i lokalt environment oprettet i hvert observer-scope, IKKE på `app_state`. `app_state` SHALL ikke indeholde UI-opdaterings-infrastruktur-state.

#### Scenario: Observer-init opretter lokalt env

- **GIVEN** `setup_column_observers(session)` kaldes
- **WHEN** funktionen initialiseres
- **THEN** et lokalt `ui_update_tokens <- new.env()` oprettes i closure
- **AND** dette env er tilgængeligt kun inden for observers skopet
- **AND** `app_state$ui_cache` indeholder ikke længere `pending_programmatic_inputs` eller lignende

#### Scenario: Audit bekræfter fravær

- **WHEN** `grep -rn "ui_cache\\\$pending_programmatic\|programmatic_token_counter\|queued_updates" R/` kører
- **THEN** resultatet er tomt
- **AND** token-logik findes kun i observer-scoped helpers

### Requirement: register_chart_type_events SHALL være splittet efter ansvar

Funktionen `register_chart_type_events()` (tidligere i `R/utils_server_events_chart.R`) SHALL være splittet i tre separate funktioner:
- `observe_chart_type_input(input, session, emit)` — observerer kun input-ændring
- `sync_chart_type_to_state(state, new_type)` — pure state-transition
- `update_ui_for_chart_type(service, new_type)` — UI-kald via update-service

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
