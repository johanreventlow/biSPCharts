## 1. Analyse

- [x] 1.1 Kortlæg alle excelR-update-kald i `R/utils_server_column_management.R`
- [x] 1.2 Kortlæg alle dataTable-update-kald i øvrige `utils_server_*.R`-filer
- [x] 1.3 Identificér token-protection-behov per call-site

## 2. Implementér

- [x] 2.1 Opret `R/utils_ui_table_update_service.R` med `create_table_update_service(session, app_state)`
- [x] 2.2 API: `update_excelr_data(table_id, data, options)`, `update_datatable(table_id, data, options)`, `clear_table(table_id)`
- [x] 2.3 Roxygen-docs (@param, @return, @keywords internal)
- [x] 2.4 Token-protection via delt `safe_programmatic_ui_update()`

## 3. Tests

- [x] 3.1 Opret `tests/testthat/test-ui-update-service-table.R`
- [x] 3.2 Test API-overflader uden Shiny-runtime (mock session)
- [x] 3.3 Test integration med token-protection

## 4. Migrér call-sites

- [x] 4.1 Erstat excelR-update-kald i `R/utils_server_column_management.R` med service-kald
      (format_data_for_excelr + table_version path fix)
- [x] 4.2 Erstat dataTable-kald i øvrige filer
      (DT bruges ikke — update_datatable er dokumenteret stub)
- [x] 4.3 Opdatér `create_ui_update_service()`-wrapper til også at delegere table-ops

## 5. Validering

- [x] 5.1 Fuld test-suite grøn (0 FAIL, 5610 PASS)
- [ ] 5.2 Manuel test: upload data → tabel-opdatering virker (kræver browser)
- [x] 5.3 Linjetælling: `wc -l R/utils_server_column_management.R` reduceret (432→421, 11 linjer)
      NB: ≥100 linjer reduceret var ikke opnåeligt — se afvigelse i rapport
- [x] 5.4 `openspec validate migrate-table-update-service --strict` ✓ valid
