# ADR-019: Production-entrypoint og pkgload-boundary

**Status:** Accepted

**Dato:** 2026-04-29

## Kontekst

`app.R` (production-entrypoint på Posit Connect) brugte `pkgload::load_all()` til at loade pakken:

```r
pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
```

`pkgload` er listet i `DESCRIPTION`'s `Suggests` (development-only). Connect Cloud
installerer ikke garanteret `Suggests`-pakker — `R CMD check --no-suggests`-flow
springer dem over. Hvis Connect bygger miljøet uden Suggests, fejler app-start med
"der er ingen pakke med navn 'pkgload'".

Dertil er `pkgload::load_all()` designet til *source-loading* under udvikling
(loader R/-filer direkte fra disk). På Connect er pakken installeret som binary;
`load_all()` i production er semantisk forkert og potentielt skrøbelig.

## Beslutning

**Beslutning B: Fjern `pkgload::load_all()` fra `app.R`; brug `library(biSPCharts)`.**

`app.R` er nu:

```r
options(shiny.autoload.r = FALSE)
library(biSPCharts)
options("golem.app.prod" = TRUE)
shiny::shinyApp(ui = app_ui, server = app_server)
```

`pkgload` forbliver i `Suggests` — det bruges fortsat i development-flow
(`dev/run_dev.R` via `devtools::load_all()`).

## Alternativer overvejet

**Beslutning A: Flyt `pkgload` til `Imports`.**
Eksplicit runtime-dependency. Strider mod Golem best-practice (pkgload er
development-tooling, ej runtime). Ville forurene production-bundle med dev-deps.
Fravalgt.

## Konsekvenser

**Positive:**
- Production-entrypoint er nu korrekt: installeret pakke loades via `library()`
- `pkgload` behøves ikke i production-bundle; kan fjernes fra manifest ved
  næste `rsconnect::writeManifest()` kald
- Semantisk klar separation: `app.R` = production; `dev/run_dev.R` = development

**Risici:**
- `library(biSPCharts)` kræver at pakken er installeret som del af Connect-bundlet.
  Connect's model: app deployes som source-bundle; Connect installerer pakken.
  Dette er standardadfærden — men **kræver pilot-deploy-verifikation** (tasks 2.8).
- Hvis Connect-miljø af ukendte årsager ikke installerer biSPCharts korrekt,
  fejler app-start. Mitigering: pilot-deploy på dev-environment inden production.

## Enforcement

Lintr-check (eller manuel review): `pkgload::` i filer uden `requireNamespace()`-guard
i production-stier (`app.R`, `R/app_server_main.R`) → flag som fejl.

`dev/run_dev.R` er undtaget — det er et development-script.

## Related

- OpenSpec: `align-csv-validator-and-pkgload-runtime`
- Codex-finding #1 (pkgload runtime hygiene)
- Tasks 2.8: pilot-deploy til Connect dev-environment (pending)
