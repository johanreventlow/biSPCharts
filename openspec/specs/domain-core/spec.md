# domain-core Specification

## Purpose
TBD - created by archiving change extract-pure-domain-from-shiny-shim. Update Purpose after archive.
## Requirements
### Requirement: Domænelogik SHALL være pure og Shiny-uafhængig

Filer der indeholder domænelogik (`fct_*_pure.R`) SHALL udelukkende eksportere pure funktioner uden Shiny-imports, uden `app_state`-reference, uden reactiveValues-mutation, og uden side-effects. Al Shiny-integration SHALL ske gennem separate shim-filer (`fct_*_operations.R`, `fct_*_unified.R`).

#### Scenario: Unit-test af file-parse i isoleret session

- **GIVEN** en test kører i fresh R-session uden `shiny`-load
- **WHEN** testen kalder `parse_file(path, "csv", list(encoding = "UTF-8"))`
- **THEN** funktionen returnerer `ParsedFile`-struktur
- **AND** ingen fejl om manglende session/reactive context
- **AND** ingen fil-side-effects uden for input-path

#### Scenario: Audit identificerer shim-grænse

- **WHEN** statisk audit scanner `R/fct_file_parse_pure.R`
- **THEN** ingen `library(shiny)`, `observe(...)`, `reactive(...)`, `app_state$...`-reference findes
- **AND** filens funktioner kan kaldes i `future()`-worker uden fejl

### Requirement: State-transitions SHALL ske gennem navngivne pure helpers

Ændringer af `app_state` SHALL udføres via navngivne pure funktioner i `R/utils_state_transitions.R` med signatur `transition_<name>(state, input...) -> new_state`. Direkte `app_state$xxx <- value`-assignments uden for state-laget er NOT tilladt (undtagelser: event-counter-increments, UI-cache-tokens).

#### Scenario: Observer håndterer file-upload

- **GIVEN** observer fanger en parsed file
- **WHEN** observeren skal opdatere state
- **THEN** den kalder `app_state |> apply_state_transition(transition_upload_to_ready, parsed_file)`
- **AND** direkte `app_state$data$current_data <- parsed_file$data`-assignment findes NOT i observer-koden

#### Scenario: Contract-test af transition-helper

- **GIVEN** unit-test for `transition_upload_to_ready(state, parsed_file)`
- **WHEN** testen kører med mock-state
- **THEN** resultat indeholder opdateret `data$current_data`, `data$original_data`, `data$file_info`
- **AND** events-counter er incrementet
- **AND** gamle state-felter er preserveret (immutable-update-pattern)

### Requirement: Reduktion i direkte app_state-mutation

Antallet af `app_state$...<-`-assignments uden for `R/utils_state_transitions.R`, `R/state_management.R`, og registrerede observer-setup-funktioner SHALL reduceres med minimum 50% fra baseline målt ved proposal-start.

#### Scenario: Baseline audit

- **WHEN** `grep -rn "app_state\\\$.*<-" R/` kører før implementation
- **THEN** optælling gemmes i `dev/audit-output/app-state-mutations-baseline.txt`

#### Scenario: Post-implementation audit

- **WHEN** samme grep kører efter alle tasks er implementeret
- **THEN** antal er ≤ 50% af baseline
- **AND** resterende assignments er i dokumenterede legitime scopes (state-transitions, event-counters, UI-cache-tokens)

