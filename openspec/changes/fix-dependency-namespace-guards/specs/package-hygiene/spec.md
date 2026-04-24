## ADDED Requirements

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
