## Why

Følge-op til `split-monolithic-ui-update-service` (archived 2026-04-28). Token-baseret loop-protection-state (`pending_programmatic_inputs`, `programmatic_token_counter`, `queued_updates`) lever p.t. på `app_state$ui$*`, men det er Shiny-observer-infrastruktur-state — ikke domæne-state. At have det på `app_state` blander observer-mekanik med applikations-state og gør det svært at:

- Reasone om `app_state` (domæne vs infrastruktur)
- Teste observers isoleret (kræver setup af shared `app_state`)
- Garbage-collecte token-state per observer-cleanup

Note: oprindeligt proposal i `split-monolithic-ui-update-service` brugte forkerte paths (`ui_cache` vs `ui`); denne change leverer korrekt scope-analyse først.

## What Changes

- Audit alle nuværende referencer til `app_state$ui$pending_programmatic_inputs`, `app_state$ui$programmatic_token_counter`, `app_state$ui$queued_updates`
- Designér token-env-pattern: `ui_update_tokens <- new.env(parent = emptyenv())` oprettet i hver observer-setup-funktion
- Migrér token-læsning/skrivning til lokal env i hver observer-scope
- Fjern `pending_programmatic_inputs`, `programmatic_token_counter`, `queued_updates` fra `app_state$ui` i `R/state_management.R`
- Opdatér `safe_programmatic_ui_update()` til at acceptere token-env som parameter (i stedet for at læse fra `app_state`)
- Opdatér tests så de ikke længere muterer disse felter på `app_state`

## Impact

- **Affected specs**: `ui-update-service` (ADDED — ny requirement om token-scope)
- **Affected code**:
  - Modificeret: `R/state_management.R` (fjern token-felter fra `app_state$ui`)
  - Modificeret: `R/utils_ui_ui_updates.R` (`safe_programmatic_ui_update()` API-ændring)
  - Modificeret: `R/utils_ui_column_update_service.R`, `R/utils_ui_form_update_service.R` (modtag/opret token-env)
  - Modificeret: `R/utils_server_initialization.R` og andre observer-setup-call-sites
  - Modificeret: tests der refererer til de fjernede `app_state`-felter

**Breaking change-risiko:** Lav. Token-state er intern infrastruktur, ikke public API. Ingen brugervendt adfærd ændres.

## Related

- Forløb: `split-monolithic-ui-update-service` (archived 2026-04-28-split-monolithic-ui-update-service)
- GitHub Issue #321 (parent tracking)
