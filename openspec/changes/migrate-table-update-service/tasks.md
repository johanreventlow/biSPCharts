## 1. Analyse

- [ ] 1.1 Kortlæg alle excelR-update-kald i `R/utils_server_column_management.R`
- [ ] 1.2 Kortlæg alle dataTable-update-kald i øvrige `utils_server_*.R`-filer
- [ ] 1.3 Identificér token-protection-behov per call-site

## 2. Implementér

- [ ] 2.1 Opret `R/utils_ui_table_update_service.R` med `create_table_update_service(session, app_state)`
- [ ] 2.2 API: `update_excelr_data(table_id, data, options)`, `update_datatable(table_id, data, options)`, `clear_table(table_id)`
- [ ] 2.3 Roxygen-docs (@param, @return, @keywords internal)
- [ ] 2.4 Token-protection via delt `safe_programmatic_ui_update()`

## 3. Tests

- [ ] 3.1 Opret `tests/testthat/test-ui-update-service-table.R`
- [ ] 3.2 Test API-overflader uden Shiny-runtime (mock session)
- [ ] 3.3 Test integration med token-protection

## 4. Migrér call-sites

- [ ] 4.1 Erstat excelR-update-kald i `R/utils_server_column_management.R` med service-kald
- [ ] 4.2 Erstat dataTable-kald i øvrige filer
- [ ] 4.3 Opdatér `create_ui_update_service()`-wrapper til også at delegere table-ops

## 5. Validering

- [ ] 5.1 Fuld test-suite grøn
- [ ] 5.2 Manuel test: upload data → tabel-opdatering virker
- [ ] 5.3 Linjetælling: `wc -l R/utils_server_column_management.R` reduceret med ≥100 linjer
- [ ] 5.4 `openspec validate migrate-table-update-service --strict`
