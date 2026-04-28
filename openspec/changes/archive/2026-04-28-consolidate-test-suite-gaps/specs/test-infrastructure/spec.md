## ADDED Requirements

### Requirement: Kritiske filer SHALL have dedikerede testfiler

Hver af følgende kernekomponenter SHALL have mindst én dedikeret testfil i `tests/testthat/`:
- `R/state_management.R` → `test-state-management.R`
- `R/app_server_main.R` → `test-app-server-main.R`
- `R/utils_event_context_handlers.R` → `test-utils-event-context-handlers.R`
- `R/mod_spc_chart_server.R` (full flow) → `test-spc-chart-full-flow.R`

#### Scenario: Audit finder manglende testfil

- **WHEN** statisk audit kører `ls R/<file>.R` og `ls tests/testthat/test-<file>.R`
- **AND** testfilen mangler for en kernekomponent
- **THEN** audit fejler
- **AND** en ny testfil SHALL oprettes eller eksplicit dispensation dokumenteres i `tests/testthat/README.md`

#### Scenario: Full-flow-test for chart-module

- **GIVEN** `tests/testthat/test-spc-chart-full-flow.R` eksekveres
- **WHEN** testen simulerer upload → kolonnevalg → chart-type → render → eksport
- **THEN** alle stadier lykkes eller rapporterer klar fejl
- **AND** testen bruger `testServer()` for Shiny-reactive-context

### Requirement: Ingen placeholder-tests i testsuite

Testsuite SHALL ikke indeholde `test_that`-blokke hvor eneste assertion er `expect_true(TRUE)`, `expect_equal(1, 1)`, eller `expect_no_error()` uden opfølgende assertions. Placeholder-tests SHALL enten erstattes med reelle assertions, slettes, eller konverteres til eksplicit `skip("TODO: #<issue>")` med åbent issue-reference.

#### Scenario: Audit finder placeholder

- **WHEN** `grep -rn "expect_true(TRUE)\|expect_equal(1, 1)" tests/testthat/` kører
- **THEN** resultatet er tomt (0 matches)

#### Scenario: `expect_no_error` uden opfølgning

- **WHEN** lint-check finder `expect_no_error({...})` uden efterfølgende `expect_*`-assertions i samme `test_that`-blok
- **THEN** lint flagger forekomsten
- **AND** PR fejler hvis nye forekomster introduceres uden `# nolint`

### Requirement: Test-duplikater SHALL konsolideres efter emne

Testfiler der tester samme capability eller samme bug-kategori SHALL konsolideres til én fil med klart scope. Duplikatet `test-<emne>-<variant>.R` × N er NOT tilladt medmindre hver variant tester en distinkt concern dokumenteret i filens header-kommentar.

#### Scenario: Logging-tests konsolideret

- **WHEN** en udvikler søger efter logging-tests
- **THEN** de findes primært i `test-logging.R`
- **AND** gamle filer `test-logging-debug-cat.R`, `test-logging-precedence.R`, `test-logging-standardization.R`, `test-logging-system.R` er enten (a) slettet (indhold flyttet til `test-logging.R`), eller (b) har klart distinkt scope dokumenteret i header

#### Scenario: Coverage-regression-check

- **GIVEN** en PR konsoliderer test-filer
- **WHEN** CI kører coverage-measurement
- **THEN** pakken-coverage er ≥ baseline fra før konsolidering
- **AND** hvis coverage falder, skal PR-beskrivelsen redegøre for hvilke tests blev fjernet og hvorfor

### Requirement: Assertion-density SHALL rapporteres per fil

CI audit-rapport SHALL rapportere assertion-density (antal `expect_*`-kald / antal `test_that`-blokke) per testfil. Filer med density < 2.0 SHALL flagges som low-quality kandidater for review.

#### Scenario: Audit output

- **WHEN** `dev/audit_tests.R` kører
- **THEN** JSON-output indeholder `assertion_density`-felt per fil
- **AND** markdown-rapport lister top 5 laveste density-filer som "needs review"
