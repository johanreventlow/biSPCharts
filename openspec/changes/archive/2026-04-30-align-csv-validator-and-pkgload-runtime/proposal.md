> **STATUS (2026-04-30):** Phase 1 (CSV-paritet) leveret i commit `86db922`
> + `45f3dd10` (release 0.3.2). Phase 2 (pkgload-runtime) **SUPERSEDED** af
> PR #382 / ADR-019 v2: Beslutning B (`library(biSPCharts)`) blev rullet
> tilbage til Beslutning A (`pkgload::load_all()` + pkgload i Imports)
> efter pilot-deploy fejlede på Connect Cloud (error_id
> 5be1e4f7-7628-48d2-9310-3ffc8c0bb3aa). Klar til arkivering efter #382 merge.
> Detaljer: `docs/adr/ADR-019-production-entrypoint-and-pkgload-boundary.md`.

## Why

To Codex-fund med medium-til-high severity adresseres her som de er distinkte men begge handler om "kontrakt der ikke matcher implementering":

**1. CSV validator/parser-mismatch:**
`R/fct_file_validation.R:251` (CSV-validator) forventer reelt semikolon/csv2-format, mens `R/fct_file_parse_pure.R:56` (parser) understøtter en 3-strategi-kaskade (semikolon → auto-detect → komma). Konsekvens: gyldige komma- eller tab-separerede filer kan blive afvist af validator FØR parser overhovedet får chance for at håndtere dem. Brugeren modtager fejlbesked der ikke afspejler appens reelle parser-kapabilitet.

**2. pkgload-runtime-hygiene:**
`app.R:8` bruger `pkgload::load_all()` som production-entrypoint på Posit Connect Cloud. `pkgload` ligger i `Suggests` (`DESCRIPTION:49`). Hvis Connect bygger uden Suggests-pakker (default på `R CMD check --no-suggests`-flow), fejler app-start. Skrøbeligt på alle deployments der ikke explicit installerer Suggests.

## What Changes

### CSV-validator-parser-paritet

- **REFAKTOR:** Ekstraktér delimiter-detektionslogik til delt helper `R/utils_csv_delimiter_detection.R` der både validator og parser bruger.
- **MODIFIED:** `R/fct_file_validation.R:251` — udskift validator-internal delimiter-check med kald til shared helper. Validator skal acceptere ALT som parser kan håndtere.
- **MODIFIED:** `R/fct_file_parse_pure.R:56` — refaktor til at bruge shared helper (samme detektion som validator).
- **ADDED tests:**
  - `tests/testthat/test-csv-validator-parser-parity.R` — for hver delimiter (semicolon, comma, tab) som parser understøtter, validator accepterer ALSO
  - Edge cases: BOM, mixed line endings, dansk komma-decimal med tab-delimiter

### pkgload-runtime-fix

- **BESLUTNING:** To muligheder:
  - **A: Flyt `pkgload` til `Imports`** — eksplicit runtime-dependency. Strider mod Golem-best-practice (pkgload bør være dev-only).
  - **B: Fjern `pkgload::load_all()` fra production app.R** — brug installeret pakke. På Connect: `library(biSPCharts)` (kræver pakken er installeret som del af manifest).
- **Anbefaling:** Beslutning B. Production target er Connect Cloud hvor manifest installerer pakken; `pkgload` ej nødvendig.
- **MODIFIED:** `app.R` — erstat `pkgload::load_all(...)` med `library(biSPCharts)` (eller equivalent). Behold `pkgload::load_all()` som dev-flow i `dev/run_dev.R`.
- **MODIFIED:** `DESCRIPTION` — `pkgload` forbliver i `Suggests` (kun dev/test-brug); bekræft at `dev/run_dev.R` håndterer manglende `pkgload` graceful.
- **VERIFY:** `manifest.json` indeholder `biSPCharts` (skal være tilfældet via `Remotes`). Pre-deploy-check: `dev/validate_connect_manifest.R` verificerer.

## Impact

- **Affected specs:** `excel-import` (MODIFIED — validator-parser-kontrakt), `package-hygiene` (ADDED — runtime-entrypoint-policy)
- **Affected code:**
  - `R/fct_file_validation.R`
  - `R/fct_file_parse_pure.R`
  - `R/utils_csv_delimiter_detection.R` (ny)
  - `app.R`
  - `dev/run_dev.R` (verificér intakt)
- **Breaking change-risiko:**
  - CSV-paritet: Lav. Bruger får adgang til *flere* gyldige filer (ej afvisning).
  - pkgload-runtime: Medium. Kræver verificering på Connect-deployment-pipeline. Pilot-deploy først.
- **User-impact:** Færre falske CSV-afvisninger → bedre brugeroplevelse. Connect-deploy stabilitet → produktionsdrift mere robust.

## Related

- Codex-finding #1 (pkgload runtime) + #4 (CSV mismatch)
- `dev/validate_connect_manifest.R`
- ADR-kandidat: "Production entrypoint and pkgload boundary"
