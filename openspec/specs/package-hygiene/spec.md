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

### Requirement: Optional-package Guards for Suggests-dependencies

Alle pakker deklareret i `Suggests:` i DESCRIPTION SHALL kun kaldes via `pkg::fun()`-syntaks når et forudgående `requireNamespace(pkg, quietly = TRUE)`-check (eller dedikeret `require_<pkg>()`-helper) har bekræftet pakken er tilgængelig. Ubeskyttede `pkg::`-kald til Suggests-pakker er NOT tilladt.

#### Scenario: qicharts2 ikke installeret

- **GIVEN** `qicharts2` er i `Suggests:` og ikke installeret
- **WHEN** brugeren udløser en Anhøj-metadata-beregning
- **THEN** koden kaster en typed `spc_dependency_error` med dansk besked "Pakken 'qicharts2' er påkrævet for Anhøj-regler. Installér med install.packages('qicharts2')"
- **AND** appen crasher NOT; fejlen håndteres af observers og vises som brugerbesked

#### Scenario: Statisk audit finder ubeskyttet kald

- **WHEN** lint/audit-scriptet scanner `R/` for `qicharts2::`-kald
- **THEN** hvert kald har en forudgående `require_qicharts2()` eller `requireNamespace("qicharts2", quietly = TRUE)` i samme scope
- **AND** scriptet returnerer exit 0 hvis alle er beskyttede

### Requirement: Ingen Triple-Colon Kald til Eksterne Pakker

Pakken SHALL NOT kalde funktioner i eksterne pakker via `pkg:::fun()`-syntaks (triple-colon, intern API). Alle kald SHALL bruge `pkg::fun()` på dokumenterede exports.

#### Scenario: BFHcharts intern API

- **WHEN** `grep -rn "BFHcharts:::" R/` kører
- **THEN** resultatet er tomt (0 matches)
- **AND** al tidligere funktionalitet der afhang af intern BFHcharts API er migreret til public API eller wrapped med lokal implementation

#### Scenario: Ny `:::`-brug introduceres

- **WHEN** en PR introducerer `pkg:::fun()`-kald
- **THEN** CI-lint-check fejler PRen
- **AND** maintainer skal enten (a) migrere til public API, (b) oprette issue i upstream-pakke, eller (c) eksplicit dokumentere undtagelsen med begrundelse i `docs/KNOWN_ISSUES.md`

### Requirement: Optional-feature Opstarts-rapport

Pakken SHALL ved load rapportere status for alle optional-features (BFHllm, qicharts2, Quarto/Typst) via struktureret logging på INFO-niveau. Rapporten SHALL indeholde `feature_name` og `available` (TRUE/FALSE).

#### Scenario: Pakke loades med alle optional installeret

- **WHEN** `library(biSPCharts)` kaldes og BFHllm + qicharts2 + Quarto er tilgængelige
- **THEN** logs indeholder tre INFO-entries: `optional_feature=BFHllm available=TRUE`, `optional_feature=qicharts2 available=TRUE`, `optional_feature=quarto available=TRUE`

#### Scenario: Optional-feature mangler

- **WHEN** `library(biSPCharts)` kaldes og BFHllm mangler
- **THEN** logs indeholder `optional_feature=BFHllm available=FALSE`
- **AND** appen fortsætter med at starte; AI-forbedringsforslag-featuren degraderer gracefully

### Requirement: Version-bounds på Alle Imports

Alle pakker i `Imports:` i DESCRIPTION SHALL have en eksplicit lower-bound i formatet `pkg (>= X.Y.Z)`. Pakker uden version-bound er NOT tilladt.

#### Scenario: Pakke uden lower-bound

- **WHEN** `tools::package_dependencies()` eller manuel inspektion finder en Imports-pakke uden `(>= X.Y.Z)`-suffix
- **THEN** DESCRIPTION SHALL opdateres med mindst den version maintaineren har testet mod (typisk installed version på review-tidspunkt)

### Requirement: Maintainer-email er Ægte

`Authors@R` og `Maintainer:`-felter i DESCRIPTION SHALL indeholde ægte, kontaktbar email-adresse. Placeholder-domæner som `example.com`, `noreply@*` er NOT tilladt.

#### Scenario: R CMD check ved release

- **WHEN** `R CMD check --as-cran` kører på release-candidate
- **THEN** `Maintainer:`-feltet har gyldig kontakt-email
- **AND** `example.com` og `noreply`-domæner er ikke til stede

### Requirement: Public NAMESPACE SHALL kun indeholde intentional public API

`NAMESPACE` SHALL kun eksportere funktioner der udgør intentional stabil public API-kontrakt. Interne helpers, UI-builders brugt af egen `run_app()`, og intern analytics-pipeline SHALL være markeret `@keywords internal` og ikke eksporteres.

#### Scenario: Audit identificerer intentional exports

- **WHEN** maintainer inspicerer NAMESPACE
- **THEN** hver eksport kan begrundes med spørgsmålet: "Forventes eksterne brugere at kalde dette direkte via `biSPCharts::fn`?"
- **AND** svaret er dokumenteret i ADR "ADR-NNN: Minimal public API surface"

#### Scenario: Intern funktion ved uheld markeret @export

- **WHEN** PR tilføjer `@export` på funktion der ikke er intentional public
- **THEN** review flagger forekomsten
- **AND** funktionen får `@keywords internal` i stedet

### Requirement: Breaking changes i public API SHALL dokumenteres i NEWS.md

Når en eksport fjernes fra NAMESPACE (markeret internal eller slettet), SHALL `NEWS.md` opdateres med `## Breaking changes`-sektion der lister hver ændring + migration-hint. Pre-1.0 MAY indeholde breaking i MINOR, men SHALL altid markeres eksplicit.

#### Scenario: Eksport fjernet

- **GIVEN** PR fjerner `mod_landing_ui` fra exports
- **WHEN** PR-review kører
- **THEN** `NEWS.md`-diff indeholder entry under `## Breaking changes` for kommende version
- **AND** entry-tekst nævner funktionsnavn + migration-hint (fx "intern funktion — kaldes automatisk af run_app()")

### Requirement: Cross-repo downstream SHALL verificeres før export-removal

Før eksport fjernes SHALL maintainer verificere at ingen sibling-pakke (BFHcharts, BFHtheme, BFHllm) bruger den via `biSPCharts::fn`-prefix. Verifikation SHALL dokumenteres i proposal.md under "Downstream-verifikation".

#### Scenario: Sibling-pakke bruger eksport

- **GIVEN** BFHcharts har en `biSPCharts::some_helper()`-kald
- **WHEN** proposal foreslår at fjerne `some_helper` fra exports
- **THEN** proposal beskriver enten (a) at funktionen beholdes som public indtil BFHcharts migrerer, eller (b) sideløbende BFHcharts-PR er åbnet

#### Scenario: Ingen downstream-brug

- **GIVEN** grep i sibling-repos ikke finder `biSPCharts::fn`-kald til eksport
- **THEN** eksport kan fjernes uden sideløbende downstream-arbejde
- **AND** proposal dokumenterer verifikationsresultat

