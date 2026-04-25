## Why

Claude-review (2026-04-24) identificerede `create_ui_update_service()` i `R/utils_ui_ui_updates.R:21-558` som en ~537-linjers closure der blander: (a) læsning fra `app_state`, (b) mutation af `app_state$ui_cache`, (c) token-baseret loop-protection, (d) faktiske `shiny::updateSelectizeInput()`-kald. Flere ansvarsområder i ét scope = umuligt at unit-teste, svær at reasone om ved bug-jagt. UI-cache og tokens (`pending_programmatic_inputs`, `programmatic_token_counter`, `queued_updates`) hører hjemme i observer-local environment, ikke på shared `app_state`. Relateret: `register_chart_type_events()` i `R/utils_server_events_chart.R` (574 linjer, linje 27+) gør for meget: input-observation + column-normalization + cache-invalidation + UI-opdatering + event-emission.

## What Changes

- Opret nyt capability `ui-update-service` der kodificerer separation mellem UI-opdaterings-logik og state.
- Split `create_ui_update_service()` i tre uafhængige services:
  - `create_column_update_service(session)` — kolonne-inputs (selectizeInput med observer-priority)
  - `create_form_update_service(session)` — form-fields (text, numeric inputs)
  - `create_table_update_service(session)` — excelR + dataTables
- Hver service er en tynd closure (< 150 linjer) med eksplicit API: `update(id, value, options)`, `disable(id)`, `reset(id)`.
- Flyt token-baseret loop-protection til observer-local environment: opret `ui_update_tokens`-environment i hver observer-setup, ikke på `app_state`.
- Fjern `app_state$ui_cache$pending_programmatic_inputs`, `programmatic_token_counter`, `queued_updates` — de er Shiny-observer-state, ikke app-state.
- Split `register_chart_type_events()` i separate funktioner:
  - `observe_chart_type_input(input, session, emit)` — observerer kun input-ændring
  - `sync_chart_type_to_state(state, new_type)` — pure state-transition (afhænger af `extract-pure-domain-from-shiny-shim`)
  - `update_ui_for_chart_type(service, new_type)` — UI-kald via update-service
- Tilføj unit-tests for hver split service + separate observer/transition/UI-funktioner.

## Impact

- **Affected specs**: Nyt capability `ui-update-service` (ADDED)
- **Affected code**:
  - Stor refaktor: `R/utils_ui_ui_updates.R` (875 linjer → ≤3 filer á ~200-250 linjer)
  - Refaktor: `R/utils_server_events_chart.R` (574 linjer, split efter ansvar)
  - Modificeret: `R/state_management.R` (fjern ui_cache-state)
  - Modificeret: alle kaldere af `create_ui_update_service()` (søg og opdater)
  - Nye: `tests/testthat/test-ui-update-service-{column,form,table}.R`, `test-register-chart-type-split.R`
- **Afhængighed**: Anbefalet landet efter `extract-pure-domain-from-shiny-shim` for at få state-transition-helper-mønstret tilgængeligt.
- **Risks**:
  - Race conditions under refaktor — token-protection-logik skal verificeres bevaret efter split
  - Eksisterende tests kan fejle hvis de afhænger af `app_state$ui_cache` direkte — opdater dem
- **Non-breaking for brugere**: Ingen UI-ændring. Intern refaktor.

## Related

- GitHub Issue: #321
- Review-rapport: Claude K2 (monolitisk UI-update-service) + Codex (utils_ui_ui_updates 875 linjer)
