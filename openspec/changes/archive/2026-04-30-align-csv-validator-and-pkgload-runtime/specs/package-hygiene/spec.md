## ADDED Requirements

### Requirement: Production-entrypoint bruger installeret pakke, ikke pkgload

`app.R` (production-entrypoint på Posit Connect) SHALL anvende `library(biSPCharts)` for at loade pakken, IKKE `pkgload::load_all()`. `pkgload` er en udviklings-pakke og forbliver i `Suggests` udelukkende til development-flow (`dev/run_dev.R`).

Begrundelse: Connect-deploy-pipelines installerer ikke garanteret `Suggests`-pakker. `pkgload::load_all()` i production fejler hvis pkgload ikke er installeret. Korrekt model: pakken er installeret som del af Connect-manifest; production-entrypoint bruger den installerede version.

#### Scenario: Production app.R bruger library()
- **WHEN** `app.R` inspiceres
- **THEN** filen indeholder `library(biSPCharts)` (eller equivalent installed-package-load)
- **AND** filen indeholder IKKE `pkgload::load_all()`

#### Scenario: Development run_dev.R bevarer pkgload
- **WHEN** `dev/run_dev.R` inspiceres
- **THEN** filen anvender `pkgload::load_all()` for hot-reload-development
- **AND** dette flow er dokumenteret i README + DEPLOYMENT.md

#### Scenario: Manifest indeholder biSPCharts
- **WHEN** `Rscript dev/validate_connect_manifest.R manifest.json` køres
- **THEN** scriptet bekræfter at biSPCharts (eller dens GitHub-Remote) er listet i manifest packages

### Requirement: Suggests-pakker bruges ikke i production-runtime-stier

Pakker i `DESCRIPTION` `Suggests:` SHALL kun bruges i development, test, eller optional-feature-stier (med `requireNamespace()`-guard). De SHALL IKKE bruges i kald-veje fra production-entrypoint (app.R → run_app() → server-init → render).

#### Scenario: Lint-check identificerer Suggests-misbrug
- **WHEN** ny kode importerer en Suggests-pakke i production-sti uden requireNamespace-guard
- **THEN** lintr-rule (eller manuel review-checkliste) flagger dette
