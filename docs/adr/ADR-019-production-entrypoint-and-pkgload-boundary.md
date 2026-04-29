# ADR-019: Production-entrypoint og pkgload-boundary

**Status:** Superseded — revideret 2026-04-29 efter pilot-deploy-fejl

**Dato (oprindelig):** 2026-04-29
**Dato (revision):** 2026-04-29

## Kontekst

`app.R` (production-entrypoint på Posit Connect Cloud) brugte oprindeligt
`pkgload::load_all()` til at loade pakken:

```r
pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
```

Første ADR-revision (Beslutning B) skiftede til `library(biSPCharts)` med
antagelse om at "Connect deployer source-bundle og installerer pakken selv".

**Pilot-deploy verificerede antagelsen som forkert.** Posit Connect Cloud
installerer dependencies fra `manifest.json::packages` men installerer IKKE
selve repo'et som pakke. App-start fejlede med:

```
Fejl i library(biSPCharts) : der er ingen pakke med navn 'biSPCharts'
```

## Beslutning (revideret)

**Beslutning A: Brug `pkgload::load_all()` i `app.R`; flyt `pkgload` til
`Imports`.**

`app.R` er:

```r
options(shiny.autoload.r = FALSE)
pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
options("golem.app.prod" = TRUE)
shiny::shinyApp(ui = app_ui, server = app_server)
```

`pkgload` flyttet fra `Suggests` til `Imports` (med `>= 1.3.0` lower-bound).
Det sikrer at Connect Cloud installerer pkgload som dependency, og at
`pkgload::load_all()` kan loade pakken fra source-bundlet uden self-install.

## Alternativer (revideret)

**Beslutning B (oprindelig, fravalgt efter pilot-deploy):**
`library(biSPCharts)`. Antog at Connect installerer self-package fra
source-bundle. Connect Cloud gør dette IKKE — kun Connect on-prem (med
`rsconnect::deployApp()` + tarball) understøtter self-install.

**Beslutning C (overvejet, fravalgt):**
Drop pkgload, lad shiny auto-source `R/`. Kolliderer med Golem-pakke-struktur
(DESCRIPTION + NAMESPACE). Connect Cloud advarsel om R/-dir + pakke. Skrøbelig
og strider mod golem-konvention.

**Beslutning D (overvejet, fravalgt):**
Inkluder biSPCharts som GitHub-remote i manifest med self-reference. Connect
Cloud cirkulær-dependency-håndtering ej dokumenteret; usikkert om understøttet.

## Konsekvenser

**Positive:**
- Production-entrypoint virker på Connect Cloud (verificeret)
- `pkgload` eksplicit runtime-dependency — ingen "magisk" Suggests-håndtering
- Source-bundle-loading semantisk korrekt på Connect Cloud (ingen self-install)

**Negative:**
- `pkgload` (development-tooling) i production-bundle. Strider mod Golem
  best-practice for on-prem Connect, men nødvendigt på Connect Cloud
- Lidt øget bundle-size (pkgload + dependencies)

**Risici:**
- pkgload's `load_all()` semantik ændrer sig i breaking releases. Lower-bound
  `>= 1.3.0` afgrænser API-stabilitet; review ved pkgload major-bumps.

## Enforcement

`pkgload::load_all()` tilladt i `app.R` (production-entrypoint på Connect Cloud).
`pkgload::` i øvrige R/-filer kræver `requireNamespace()`-guard.

`dev/run_dev.R` bruger `devtools::load_all()` (development-flow, ej Connect).

## Pilot-deploy post-mortem

**Hvad fejlede:** Antagelse om Connect Cloud-source-bundle-self-install (uden
pilot-deploy-verifikation før merge til master).

**Hvorfor:** Tasks 2.8 (pilot-deploy til Connect dev-environment) blev sprunget
over i Phase 2-implementering. ADR-019 første revision blev accepted uden
empirisk validering.

**Læring:**
- Connect Cloud != Connect on-prem mht. self-install-model
- ADR'er der ændrer production-entrypoint-adfærd kræver pilot-deploy før merge
- "Source-bundle" er flertydigt term; verificér konkret platform-adfærd

## Related

- OpenSpec: `align-csv-validator-and-pkgload-runtime`
- Codex-finding #1 (pkgload runtime hygiene)
- Pilot-deploy-fejl 2026-04-29: error_id=5be1e4f7-7628-48d2-9310-3ffc8c0bb3aa
