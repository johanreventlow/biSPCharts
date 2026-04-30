# ui-update-service Specification

## Purpose
TBD - created by archiving change split-monolithic-ui-update-service. Update Purpose after archive.
## Requirements
### Requirement: UI-update-services SHALL være splittet efter operation-type

UI-opdateringslogik for kolonne-inputs og form-fields SHALL organiseres i separate services: `create_column_update_service(session, app_state)` og `create_form_update_service(session, app_state, column_service)`. Hver service SHALL kun håndtere én operation-type.

Note: `create_table_update_service()` (excelR + dataTables) er udskudt til separat change `migrate-table-update-service` — excelR-logikken bor i `R/utils_server_column_management.R` og kræver dedikeret migration.

#### Scenario: Column-input-opdatering

- **GIVEN** observer har brug for at opdatere kolonne-selectizeInput
- **WHEN** koden kalder `col_service$update_column_choices(choices, selected, columns)`
- **THEN** service håndterer token-protection + delegering til `safe_programmatic_ui_update()` + `shiny::updateSelectizeInput`-kald
- **AND** form-ops eller table-ops er ikke involveret

#### Scenario: Form-field-opdatering

- **GIVEN** observer har brug for at opdatere text/numeric-inputs
- **WHEN** koden kalder `form_service$update_form_fields(metadata, fields)`
- **THEN** service håndterer field-validering + UI-opdatering
- **AND** column-ops eller table-ops er ikke involveret

#### Scenario: Backward-kompatibel wrapper

- **GIVEN** eksisterende kode kalder `create_ui_update_service(session, app_state)`
- **WHEN** wrapperen returnerer
- **THEN** API'et delegerer transparent til column-service + form-service
- **AND** ingen kalder ændres

### Requirement: app_state$ui SHALL NOT indeholde dead token-tracking-felter

`app_state$ui` SHALL ikke indeholde token-tracking-felter (`pending_programmatic_inputs`, `programmatic_token_counter`) der ikke har nogen producent i produktionskode. Dead state forvirrer kode-reading + bærer test-overhead uden adfærdsdækning.

`queued_updates` BIBEHOLDES som legitim session-global queue-infrastruktur — flyttes IKKE — fordi den serialiserer concurrent UI-opdateringer på tværs af observere via `safe_programmatic_ui_update()` + `process_ui_update_queue()`.

#### Scenario: Dead token-felter fjernet fra state_management

- **GIVEN** `R/state_management.R`'s `app_state$ui <- shiny::reactiveValues(...)` definition
- **WHEN** filen inspiceres efter cleanup
- **THEN** `pending_programmatic_inputs` SHALL ikke være defineret
- **AND** `programmatic_token_counter` SHALL ikke være defineret
- **AND** `queued_updates` SHALL stadig være defineret med kommentar der dokumenterer den som session-global queue

#### Scenario: Audit-grep returnerer tomt

- **WHEN** `grep -rn "pending_programmatic_inputs\|programmatic_token_counter" R/` kører
- **THEN** resultatet SHALL være tomt
- **AND** ingen produktionskode i `R/` SHALL referere disse felter

#### Scenario: Observer-bodies ryddet for dead read-and-clear-blocks

- **GIVEN** `R/utils_server_events_chart.R` (chart_type, y_axis_unit, n_column observers)
- **AND** `R/utils_server_column_input.R` (col_name handler)
- **WHEN** observer-bodies inspiceres
- **THEN** ingen `pending_token <- app_state$ui$pending_programmatic_inputs[[...]]`-blocks SHALL eksistere
- **AND** ingen `app_state$ui$pending_programmatic_inputs[[...]] <- NULL`-blocks SHALL eksistere
- **AND** observer-logic der tidligere var defensivt gated på pending_token SHALL køre uconditional eller med eksplicit dokumenteret guard (fx `app_state$ui$updating_programmatically`-check)

#### Scenario: queued_updates bibeholdes på app_state$ui

- **GIVEN** `R/state_management.R`'s `app_state$ui` definition
- **WHEN** filen inspiceres efter cleanup
- **THEN** `queued_updates = list()` SHALL stadig være defineret
- **AND** der SHALL være kommentar der dokumenterer feltet som legitim session-global queue
- **AND** `safe_programmatic_ui_update()` + `process_ui_update_queue()` + `enqueue_ui_update()` SHALL fortsætte med at læse/skrive feltet uændret

#### Scenario: test-ui-token-management.R fjernet

- **GIVEN** `tests/testthat/test-ui-token-management.R`
- **WHEN** test-suite køres efter cleanup
- **THEN** filen SHALL ikke længere eksistere
- **AND** ingen test SHALL mutere `app_state$ui$pending_programmatic_inputs` eller `app_state$ui$programmatic_token_counter`

#### Scenario: Test-fixtures ryddet

- **WHEN** `tests/testthat/helper-fixtures.R` og test-filer inspiceres
- **THEN** initialisering af `pending_programmatic_inputs` SHALL være fjernet
- **AND** initialisering af `programmatic_token_counter` SHALL være fjernet
- **AND** `queued_updates`-initialisering SHALL bibeholdes (felt eksisterer stadig)

#### Scenario: Fuld test-suite forbliver grøn

- **GIVEN** alle ovenstående cleanup-skridt
- **WHEN** `devtools::test()` køres
- **THEN** alle eksisterende tests SHALL passere
- **AND** ingen ny test SHALL fejle pga. fjernet dead state

