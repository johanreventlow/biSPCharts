## MODIFIED Requirements

### Requirement: UI-update-services SHALL være splittet efter operation-type

UI-opdateringslogik for kolonne-inputs, form-fields OG table-opdateringer SHALL organiseres i separate services: `create_column_update_service(session, app_state)`, `create_form_update_service(session, app_state, column_service)` og `create_table_update_service(session, app_state)`. Hver service SHALL kun håndtere én operation-type.

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

#### Scenario: Table-opdatering

- **GIVEN** observer har brug for at opdatere excelR- eller dataTable-output
- **WHEN** koden kalder `table_service$update_excelr_data(table_id, data)` eller `table_service$update_datatable(table_id, data)`
- **THEN** service håndterer token-protection + UI-update-kald
- **AND** column-ops eller form-ops er ikke involveret

#### Scenario: Backward-kompatibel wrapper

- **GIVEN** eksisterende kode kalder `create_ui_update_service(session, app_state)`
- **WHEN** wrapperen returnerer
- **THEN** API'et delegerer transparent til column-service + form-service + table-service
- **AND** ingen kalder ændres
