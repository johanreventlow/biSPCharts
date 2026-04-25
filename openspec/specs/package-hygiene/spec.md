# package-hygiene Specification

## Purpose
TBD - created by archiving change improve-package-hygiene. Update Purpose after archive.
## Requirements
### Requirement: R CMD Check Gate

Pakken SHALL bestå `R CMD check --as-cran --no-tests --no-manual --no-vignettes --no-build-vignettes` uden WARNINGs før enhver release-tag må oprettes. NOTEs SHALL dokumenteres i `docs/PRE_RELEASE_CHECKLIST.md` med begrundelse.

#### Scenario: Ren check ved release
- **WHEN** release-tag `vX.Y.Z` er klar til oprettelse
- **THEN** `R CMD check --as-cran ...` kører og returnerer 0 WARNINGs
- **AND** eventuelle NOTEs er dokumenteret og accepteret

#### Scenario: Check fejler
- **WHEN** WARNINGs opstår i `R CMD check`
- **THEN** tag oprettes NOT
- **AND** WARNINGs SHALL løses eller eksplicit accepteres via spec-amendment før release

### Requirement: LICENSE Fil Eksisterer

Repositoriet SHALL indeholde en `LICENSE`-fil der matcher `License:`-feltet i DESCRIPTION. Når DESCRIPTION siger `MIT + file LICENSE` SHALL `LICENSE`-filen eksistere i rod og indeholde gyldig MIT-skabelon.

#### Scenario: LICENSE findes ved package build
- **WHEN** `R CMD build` kører
- **THEN** `LICENSE`-filen inkluderes i tarball uden advarsel

### Requirement: R Version Minimum Matcher Syntaks

`Depends: R (>= X.Y.Z)` i DESCRIPTION SHALL være mindst så høj som den højeste R-version der kræves af syntaks brugt i pakken. Ved brug af native pipe `|>` SHALL minimum være `4.1.0` eller højere.

#### Scenario: Native pipe brugt
- **WHEN** pakken indeholder `|>` i R-kildefiler
- **THEN** `Depends:` SHALL være `R (>= 4.1.0)` eller højere

### Requirement: Imports Matcher Faktisk Brug

Alle pakker brugt direkte via `pkg::fun()` eller `library(pkg)` i R/ SHALL være deklareret i `Imports:` eller `Depends:` i DESCRIPTION. Omvendt SHALL ubrugte pakker NOT stå i `Imports:`.

#### Scenario: Direkte brug af ikke-deklareret pakke
- **WHEN** R-kode kalder `htmltools::HTML(...)` uden `htmltools` i Imports
- **THEN** `R CMD check` giver WARNING og release blokeres

#### Scenario: Ubrugt pakke i Imports
- **WHEN** en pakke står i `Imports:` men ingen kald findes i R/
- **THEN** pakken SHALL fjernes fra `Imports:` eller flyttes til `Suggests:` hvis den kun bruges i tests/vignettes

### Requirement: Enkelt NAMESPACE-kilde

Pakken SHALL have nøjagtigt én `NAMESPACE`-fil i rod, genereret af `devtools::document()`. Der SHALL NOT eksistere en `R/NAMESPACE`-fil eller anden parallel namespace-deklaration.

#### Scenario: R/NAMESPACE findes
- **WHEN** filen `R/NAMESPACE` eksisterer
- **THEN** den SHALL slettes eller omdøbes til ikke-NAMESPACE-navn
- **AND** alle exports SHALL håndteres via `@export`-roxygen-tags

### Requirement: Struktureret Logging Uden Silent Failures

Alle kald til `log_debug()`, `log_info()`, `log_warn()`, `log_error()` SHALL bruge parametre der er eksplicit deklareret i funktionssignaturen. Session-id og lignende metadata SHALL gå via `details = list(...)`-parameteren, ikke via top-level argumenter.

#### Scenario: log_warn med session_id
- **WHEN** kode logger en advarsel med session-kontekst
- **THEN** kaldet SHALL være `log_warn(msg, .context = "CTX", details = list(session_id = sanitize_session_token(session$token)))`
- **AND** NOT `log_warn(msg, .context = "CTX", session_id = ...)` som silently ignoreres

#### Scenario: Regression test verificerer signatur
- **WHEN** testsuite kører
- **THEN** mindst én test verificerer at `log_warn()` kaldet i rate-limit handleren ikke genererer uventet fejl

### Requirement: Ingen Artefakter i Version Control

Repositoriet SHALL NOT indeholde auto-genererede eller OS-specifikke artefakter: `.DS_Store`, `Rplots.pdf`, `testthat-problems.rds`, `test_output.pdf` eller lignende. `.gitignore` SHALL blokere disse fremadrettet.

#### Scenario: Artefakt committes ved uheld
- **WHEN** en udvikler prøver at committe `.DS_Store`
- **THEN** `.gitignore` SHALL forhindre det automatisk

### Requirement: DESCRIPTION Metadata Matcher Projektstruktur

`LazyData`, `VignetteBuilder` og lignende metadata-felter i DESCRIPTION SHALL kun være til stede hvis den tilsvarende projektstruktur eksisterer (`data/`, `vignettes/`).

#### Scenario: LazyData uden data/
- **WHEN** DESCRIPTION indeholder `LazyData: true` men `data/` mappe ikke findes
- **THEN** feltet SHALL fjernes fra DESCRIPTION

#### Scenario: VignetteBuilder uden vignettes/
- **WHEN** DESCRIPTION indeholder `VignetteBuilder: knitr` men `vignettes/` mappe ikke findes
- **THEN** feltet SHALL fjernes indtil vignettes faktisk skrives

### Requirement: Tarball SHALL ikke indeholde udviklingsartefakter

Package-tarball (`biSPCharts_*.tar.gz`) genereret af `R CMD build` SHALL NOT indeholde nogen af følgende paths: `.claude/`, `.worktrees/`, `.Rproj.user/`, `.DS_Store`, `..Rcheck/`, `Rplots.pdf`, `*.backup`, `logs/`, `rsconnect/`, `todo/`, `updates/`. `.Rbuildignore` SHALL blokere dem via regex-patterns.

#### Scenario: Tarball audit finder artefakt

- **WHEN** CI-step `tar -tzf biSPCharts_*.tar.gz | grep -E '...'` kører
- **AND** matching path findes i tarball
- **THEN** workflow fejler
- **AND** error-besked indeholder den specifikke path og linje fra `.Rbuildignore` der burde have blokeret den

#### Scenario: Ren tarball

- **WHEN** audit-step kører på ren pakke
- **THEN** ingen matches fundet
- **AND** tarball-størrelse logges til workflow-output for regression-monitorering

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

