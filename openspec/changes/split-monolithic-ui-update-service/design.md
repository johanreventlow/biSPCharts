# Design: Split monolithic UI update service

## Scope-beslutninger (reconcilerede med faktisk kode)

### 1. State-path korrektion
Proposal refererer `app_state$ui_cache$pending_programmatic_inputs` etc.
Virkelighed: disse felter ligger på `app_state$ui$*` (state_management.R:212-238).
`app_state$ui_cache` er en tom `reactiveValues()` (linje 245) — bruges til kolonne-cache i `utils_server_column_input.R`, ikke loop-protection.

**Beslutning:** Task 6 (fjern UI-state fra app_state) udsættes til separat PR.
Loop-protection-state (`updating_programmatically`, `queued_updates`, etc.) er legitimt
delt app-state — det kan ikke isoleres til closure-local uden at bryde observer-koordination.

### 2. Table service
Proposal: `create_table_update_service(session)` — excelR + dataTables.
Virkelighed: excelR-kode ligger i `utils_server_column_management.R:273-370` med
`renderExcel`/`excelTable`. Det er ikke inden for `create_ui_update_service()`.

**Beslutning:** Table service er out-of-scope for dette PR. Kræver separat migration
af `utils_server_column_management.R`. Dokumenteres som fremtidig task i issue #321.

### 3. Task 7 (register_chart_type_events)
Afhængighed `extract-pure-domain-from-shiny-shim` er 0/27 tasks. Task 7.2 kræver
state-transition-pattern fra den dependency.

**Beslutning:** Task 7 udsættes til separat PR efter `extract-pure-domain-from-shiny-shim` lander.

## Implementeret split

### `create_column_update_service(session, app_state)`
Fil: `R/utils_ui_column_update_service.R` (< 150 linjer)

API:
- `update_column_choices(choices, selected, columns, clear_selections)` — unified col opdatering
- `update_all_columns(choices, selected, columns)` — batch update
- `update_all_columns_from_state(choices, columns_state, log_context)` — state-driven med isolate

### `create_form_update_service(session, app_state, column_service = NULL)`
Fil: `R/utils_ui_form_update_service.R` (< 200 linjer)

API:
- `update_form_fields(metadata, fields)` — restore/metadata load
- `reset_form_fields()` — delegerer til column_service$update_column_choices ved reset
- `toggle_ui_element(element_id, show)` — show/hide
- `validate_form_fields(field_rules, show_feedback)` — validering
- `show_user_feedback(message, type, duration, modal)` — notifikationer/modals
- `update_ui_conditionally(conditions)` — conditional updates

### Backward-compat wrapper (bevaret, deprecation-path)
`create_ui_update_service(session, app_state)` i `utils_ui_ui_updates.R` opretter
begge services og merger API-listerne. Eksisterende kaldere ændres ikke.

## State-migration-strategi (frem mod næste PR)

Felter på `app_state$ui` der er kandidater til fremtidig fjernelse:
- `pending_programmatic_inputs` — sættes ikke i `create_ui_update_service()`, konsumeres
  i `utils_server_column_input.R` og `utils_server_events_chart.R`. Separat migration.
- `programmatic_token_counter` — token-generator, relateret til ovenstående.
- `queued_updates` / `queue_processing` — deles mellem services, fjern KUN efter
  `safe_programmatic_ui_update()` er refaktoreret til closure-local strategy.

## Kalderanalyse

Eneste direkte kalde af `create_ui_update_service()`: `utils_server_initialization.R:60`.
Backward-compat wrapper bevarer denne kalder intakt.

Faktisk API-overflade (verificeret via grep):
- `$update_column_choices()` — 2 steder
- `$update_all_columns()` — 2 steder
- `$update_all_columns_from_state()` — 1 sted
- `$update_form_fields()` — 3 steder
- `$reset_form_fields()` — 3 steder

Ueksponerede (kun interne): toggle_ui_element, validate_form_fields, show_user_feedback,
update_ui_conditionally. Bevares i form service til potentiel fremtidig eksponering.
