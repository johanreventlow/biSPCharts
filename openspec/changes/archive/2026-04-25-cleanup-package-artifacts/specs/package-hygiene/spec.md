## ADDED Requirements

### Requirement: Ingen Tomme Placeholder-filer i R/

`R/`-mappen SHALL NOT indeholde filer med udelukkende kommentarer og ingen funktionsdefinitioner. Placeholder-filer SHALL enten (a) indeholde faktisk implementation, (b) flyttes til `dev/` hvis de er udviklings-stubs, eller (c) slettes.

#### Scenario: Audit finder tom fil

- **WHEN** statisk audit scanner `R/`-mappen for filer hvor alle non-blank-linjer starter med `#`
- **THEN** scriptet rapporterer filen
- **AND** filen SHALL slettes eller forsynes med implementation før næste release

### Requirement: Ingen `cat()` eller `print()` i Production-kode

Production-kode i `R/` (ekskluderer `tests/`, `dev/`, `data-raw/`) SHALL NOT indeholde direkte `cat(...)` eller `print(...)`-kald til stdout. Al diagnostik SHALL gå gennem `log_debug()`, `log_info()`, `log_warn()`, `log_error()` med passende `.context`-label. Bruger-facing output SHALL gå gennem `message()`, `showNotification()`, eller UI-outputs.

#### Scenario: Ny cat()-kald introduceres

- **WHEN** en PR tilføjer `cat("Processing...")` i en R/-fil
- **THEN** lintr-pass fejler PRen med besked "Brug log_debug() eller log_info() i stedet for cat()"
- **AND** undtagelser kræver eksplicit `# nolint: cat_linter` med begrundelse

#### Scenario: Eksisterende rogue cat()

- **WHEN** audit kører mod nuværende R/-mappe
- **THEN** antal forekomster er 0 efter cleanup
- **AND** `log_*()`-kald har `.context`-label der matcher fil/modul

### Requirement: Konsoliderede Test-skip-placeholders

Permanent eller midlertidige test-skips der peger på samme underlying issue SHALL konsolideres i én placeholder-fil pr. issue, ikke spredt som duplicate-stubs i hele testsuiten.

#### Scenario: Flere tests venter på samme issue

- **GIVEN** 10 testfiler har `skip("TODO: #230 testServer-migration")`
- **WHEN** konsolidering udføres
- **THEN** resultat er én fil `tests/testthat/test-pending-issue-230.R` med centraliseret dokumentation af scope
- **AND** de oprindelige 10 duplicate-skips er slettet

#### Scenario: Fremtidig bred skip

- **WHEN** en udvikler skal skippe N tests pga. samme issue
- **THEN** konventionen er at placere én samlet placeholder-fil med tydelig issue-reference
- **AND** CI skip-inventory-rapporten grupperer dem som ét item
