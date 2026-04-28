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

