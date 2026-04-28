## Why

Følge-op til `split-monolithic-ui-update-service` (archived 2026-04-28). Den arkiverede change leverede `column_update_service` + `form_update_service`, men `table_update_service` blev udskudt fordi excelR-logikken bor i `R/utils_server_column_management.R`, ikke i `create_ui_update_service()`. Konsolidering af table-opdateringer (excelR + dataTables) i én service vil:

- Eliminere spredt UI-kald-logik for tabel-opdateringer
- Gøre table-update token-protection konsistent med column/form services
- Reducere `utils_server_column_management.R` (>500 linjer) ved at flytte ren UI-update-kode ud
- Tillade unit-tests af table-update-API uden Shiny-runtime

## What Changes

- Opret `R/utils_ui_table_update_service.R` med `create_table_update_service(session, app_state)`
- API: `update_excelr_data(table_id, data, options)`, `update_datatable(table_id, data, options)`, `clear_table(table_id)`
- Migrer excelR-update-kald fra `R/utils_server_column_management.R` til service
- Migrer dataTable-opdateringer fra spredte call-sites
- Token-protection delegeret til delt `safe_programmatic_ui_update()` (samme pattern som col/form services)
- Tilføj `tests/testthat/test-ui-update-service-table.R`
- Opdatér backward-compat wrapper `create_ui_update_service()` til også at delegere til table-service

## Impact

- **Affected specs**: `ui-update-service` (MODIFIED — udvider eksisterende krav fra col+form til col+form+table)
- **Affected code**:
  - Ny: `R/utils_ui_table_update_service.R`
  - Ny: `tests/testthat/test-ui-update-service-table.R`
  - Modificeret: `R/utils_server_column_management.R` (flyt UI-update-kode ud)
  - Modificeret: `R/utils_ui_ui_updates.R` (wrapper delegerer også til table-service)

## Related

- Forløb: `split-monolithic-ui-update-service` (archived 2026-04-28-split-monolithic-ui-update-service)
- GitHub Issue #321 (parent tracking)
