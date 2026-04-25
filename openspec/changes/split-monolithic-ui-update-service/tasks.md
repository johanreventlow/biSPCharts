## 1. Analyse og design

- [ ] 1.1 Læs `R/utils_ui_ui_updates.R:21-558` og kortlæg alle sub-funktioner i `create_ui_update_service()`
- [ ] 1.2 Kategorisér sub-funktioner: column-ops, form-ops, table-ops
- [ ] 1.3 Kortlæg token-protection-logik: hvilke `app_state$ui_cache`-felter bruges hvor?
- [ ] 1.4 Kortlæg kaldere af `create_ui_update_service()`: `grep -rn "create_ui_update_service" R/`
- [ ] 1.5 Opret `design.md` med split-plan og state-migration-strategi

## 2. Column update-service

- [ ] 2.1 Opret `R/utils_ui_column_update_service.R` med `create_column_update_service(session)`
- [ ] 2.2 API: `update(id, choices, selected, options)`, `disable(id)`, `reset(id)`
- [ ] 2.3 Token-protection i closure-local env, ikke app_state
- [ ] 2.4 Tests: `tests/testthat/test-ui-update-service-column.R`

## 3. Form update-service

- [ ] 3.1 Opret `R/utils_ui_form_update_service.R` med `create_form_update_service(session)`
- [ ] 3.2 API: `update_text(id, value)`, `update_numeric(id, value)`, `disable(id)`
- [ ] 3.3 Tests: `tests/testthat/test-ui-update-service-form.R`

## 4. Table update-service

- [ ] 4.1 Opret `R/utils_ui_table_update_service.R` med `create_table_update_service(session)`
- [ ] 4.2 API: `update_data(id, data)`, `replace(id, data)`, `clear(id)`
- [ ] 4.3 Debounce-logik for excelR bevaret
- [ ] 4.4 Tests: `tests/testthat/test-ui-update-service-table.R`

## 5. Migrér kaldere

- [ ] 5.1 Opdatér alle kaldere til at bruge specifik service i stedet for monolit
- [ ] 5.2 Hvis eksisterende API bevares: lav tynd backward-kompatibel wrapper der delegerer (deprecation-path)
- [ ] 5.3 Slet gamle `create_ui_update_service()` efter alle kaldere er migreret

## 6. Fjern UI-state fra app_state

- [ ] 6.1 Fjern `app_state$ui_cache$pending_programmatic_inputs`, `programmatic_token_counter`, `queued_updates` fra `R/state_management.R`
- [ ] 6.2 Verificér ingen R-fil refererer til disse felter længere
- [ ] 6.3 Opdatér dokumentation (CLAUDE.md app_state-schema)

## 7. Split register_chart_type_events

- [ ] 7.1 Opret tre separate funktioner: `observe_chart_type_input`, `sync_chart_type_to_state`, `update_ui_for_chart_type`
- [ ] 7.2 `sync_chart_type_to_state` er pure state-transition (bruger mønstret fra `extract-pure-domain-from-shiny-shim`)
- [ ] 7.3 Opdatér `setup_event_listeners()` til at komposere de tre funktioner
- [ ] 7.4 Tests: `tests/testthat/test-register-chart-type-split.R`

## 8. Validering

- [ ] 8.1 Kør fuld test-suite — alle eksisterende tests skal fortsat passere
- [ ] 8.2 Manuel test: upload data, skift chart-type hurtigt flere gange, verificér ingen race conditions
- [ ] 8.3 Verificér at utils_ui_ui_updates.R er slettet eller ≤100 linjer thin-wrappers
- [ ] 8.4 Kør `openspec validate split-monolithic-ui-update-service --strict`

Tracking: GitHub Issue #321
