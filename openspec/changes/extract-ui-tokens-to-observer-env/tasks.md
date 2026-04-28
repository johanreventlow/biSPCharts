## 1. Audit

- [ ] 1.1 `grep -rn "app_state\\\$ui\\\$pending_programmatic\|programmatic_token_counter\|queued_updates" R/ tests/` — kortlæg alle referencer
- [ ] 1.2 Identificér observer-setup-funktioner der har brug for token-env
- [ ] 1.3 Dokumentér nuværende token-livscyklus per observer

## 2. Design

- [ ] 2.1 Beslut env-creation-pattern: én env per observer-setup vs. én delt env per session
- [ ] 2.2 Opdater `safe_programmatic_ui_update()` API: tag `token_env` som parameter
- [ ] 2.3 Beskriv migration-strategi: backward-compat-flag eller hård cutover

## 3. Implementér

- [ ] 3.1 Opdatér `safe_programmatic_ui_update()` til at acceptere `token_env`
- [ ] 3.2 Modificér `create_column_update_service()` + `create_form_update_service()` til at oprette/modtage token-env
- [ ] 3.3 Fjern `pending_programmatic_inputs`, `programmatic_token_counter`, `queued_updates` fra `app_state$ui` i `R/state_management.R`
- [ ] 3.4 Opdatér observer-setup-call-sites (utils_server_initialization.R, øvrige setup-funktioner)

## 4. Tests

- [ ] 4.1 Opdatér eksisterende tests så de ikke læser/muterer fjernede `app_state`-felter
- [ ] 4.2 Tilføj test: token-env er isoleret per observer-scope
- [ ] 4.3 Tilføj test: ingen lækage mellem sessions

## 5. Validering

- [ ] 5.1 `grep -rn "app_state\\\$ui\\\$pending_programmatic\|programmatic_token_counter\|queued_updates" R/` returnerer tom
- [ ] 5.2 Fuld test-suite grøn
- [ ] 5.3 Manuel test: programmatisk UI-update virker (chart-type-skift, kolonne-mapping)
- [ ] 5.4 `openspec validate extract-ui-tokens-to-observer-env --strict`
