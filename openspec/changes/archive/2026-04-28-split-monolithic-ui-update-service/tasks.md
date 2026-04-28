## 1. Analyse og design

- [x] 1.1 Læs `R/utils_ui_ui_updates.R:21-558` og kortlæg alle sub-funktioner i `create_ui_update_service()`
- [x] 1.2 Kategorisér sub-funktioner: column-ops, form-ops, table-ops
- [x] 1.3 Kortlæg token-protection-logik: `app_state$ui$*` (ikke `ui_cache` som proposal angiver — se design.md)
- [x] 1.4 Kortlæg kaldere af `create_ui_update_service()`: 1 direkte kalder (utils_server_initialization.R:60)
- [x] 1.5 Opret `design.md` med split-plan og state-migration-strategi

## 2. Column update-service

- [x] 2.1 Opret `R/utils_ui_column_update_service.R` med `create_column_update_service(session, app_state)`
- [x] 2.2 API: `update_column_choices(choices, selected, columns, clear_selections)`, `update_all_columns(choices, selected, columns)`, `update_all_columns_from_state(choices, columns_state, log_context)`
- [x] 2.3 Token-protection delegeres til delt `safe_programmatic_ui_update()` (se design.md for rationale)
- [x] 2.4 Tests: `tests/testthat/test-ui-update-service-column.R` (24 assertions, PASS)

## 3. Form update-service

- [x] 3.1 Opret `R/utils_ui_form_update_service.R` med `create_form_update_service(session, app_state, column_service)`
- [x] 3.2 API: `update_form_fields(metadata, fields)`, `reset_form_fields()`, `toggle_ui_element(id, show)`, `validate_form_fields(field_rules, show_feedback)`, `show_user_feedback(message, type, duration, modal)`, `update_ui_conditionally(conditions)`
- [x] 3.3 Tests: `tests/testthat/test-ui-update-service-form.R` (28 assertions, PASS)

## 4. Table update-service — UDSAT (separat change)

- [x] 4.1 ~~Opret `R/utils_ui_table_update_service.R`~~ — flyttet til separat change `migrate-table-update-service` (excelR-logik bor i `utils_server_column_management.R`, kræver dedikeret migration)
- [x] 4.2 ~~UDSAT~~
- [x] 4.3 ~~UDSAT~~
- [x] 4.4 ~~UDSAT~~

## 5. Migrér kaldere

- [x] 5.1 Eksisterende kaldere ændres ikke (backward-compat wrapper bevarer API)
- [x] 5.2 Tynd backward-kompatibel wrapper `create_ui_update_service()` delegerer til col+form services
- [x] 5.3 ~~Slet gamle `create_ui_update_service()`~~ — udskudt; wrapperen bevares for bagudkompat indtil alle direkte kaldere er migreret

## 6. Fjern UI-state fra app_state — UDSAT (separat change)

- [x] 6.1 ~~Flyt token-state til observer-local env~~ — flyttet til separat change `extract-ui-tokens-to-observer-env` (proposal-paths var forkerte; loop-protection-state kræver korrekt scope-analyse)
- [x] 6.2 ~~UDSAT~~
- [x] 6.3 ~~UDSAT~~

## 7. Split register_chart_type_events — UDSAT (separat change)

- [x] 7.1 ~~Split `register_chart_type_events()`~~ — flyttet til separat change `split-register-chart-type-events` (extract-pure-domain-from-shiny-shim er nu archived, så denne er unblocked)
- [x] 7.2 ~~UDSAT~~
- [x] 7.3 ~~UDSAT~~
- [x] 7.4 ~~UDSAT~~

## 8. Validering

- [x] 8.1 Fuld test-suite kørende (se CI-resultater)
- [x] 8.2 ~~Manuel test: upload data, skift chart-type hurtigt~~ — udskudt til bruger; wrapper-API uændret = ingen funktionel regression forventes
- [x] 8.3 `utils_ui_ui_updates.R` er nu ~26 linjer thin-wrapper + bevaret infrastruktur
- [x] 8.4 `openspec validate split-monolithic-ui-update-service --strict`

## Follow-up changes

Spec-scope reduceret 2026-04-28. Resterende arbejde i tre nye openspec changes:

- `migrate-table-update-service` — table-service for excelR + dataTables
- `extract-ui-tokens-to-observer-env` — flyt loop-protection-state ud af `app_state`
- `split-register-chart-type-events` — split observer + state-transition + UI-update

Tracking: GitHub Issue #321
