## ADDED Requirements

### Requirement: UI-opdaterings-tokens SHALL holdes i observer-local env

Token-baseret loop-protection (`pending_programmatic_inputs`, `programmatic_token_counter`, `queued_updates`) SHALL opholde i lokalt environment oprettet i hvert observer-scope, IKKE på `app_state`. `app_state` SHALL ikke indeholde UI-opdaterings-infrastruktur-state.

#### Scenario: Observer-init opretter lokalt env

- **GIVEN** observer-setup-funktion (fx `setup_column_observers(session, app_state)`) kaldes
- **WHEN** funktionen initialiseres
- **THEN** et lokalt `ui_update_tokens <- new.env(parent = emptyenv())` oprettes i closure
- **AND** dette env er tilgængeligt kun inden for observers skopet
- **AND** `app_state$ui` indeholder ikke længere `pending_programmatic_inputs`, `programmatic_token_counter` eller `queued_updates`

#### Scenario: safe_programmatic_ui_update modtager env

- **GIVEN** `safe_programmatic_ui_update()` kaldes fra observer-scope
- **WHEN** funktionen kaldes
- **THEN** `token_env` SHALL være eksplicit parameter (ikke implicit hentet fra `app_state`)
- **AND** funktionen muterer kun `token_env`, aldrig `app_state`

#### Scenario: Audit bekræfter fravær

- **WHEN** `grep -rn "app_state\\\$ui\\\$pending_programmatic\|programmatic_token_counter\|queued_updates" R/` kører
- **THEN** resultatet er tomt
- **AND** token-logik findes kun i observer-scoped helpers

#### Scenario: Isolation mellem sessions

- **GIVEN** to samtidige Shiny-sessions
- **WHEN** begge udfører programmatiske UI-opdateringer
- **THEN** token-env i session A påvirker ikke session B
- **AND** garbage collection af session A frigør session A's token-env
