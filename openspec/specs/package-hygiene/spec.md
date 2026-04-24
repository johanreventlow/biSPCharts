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

