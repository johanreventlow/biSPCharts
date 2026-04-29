# Tasks: align-csv-validator-and-pkgload-runtime

**Status:** superseded — klar til arkivering efter PR #382 merge

> **2026-04-30 statusupdate:**
> - **Phase 1** (CSV-paritet): leveret. Kode + tests landed i commits
>   `86db922` + `45f3dd10`. NEWS-entry tilføjet i 0.3.2 via #382.
>   Manuelle tasks 1.8/1.9 droppes — coverage sikret af parity-tests
>   `tests/testthat/test-csv-validator-parser-parity.R`.
> - **Phase 2** (pkgload runtime): SUPERSEDED af PR #382. Beslutning B
>   blev pilot-deploy-fejlet (Connect Cloud installerer ikke selve repo'et
>   som pakke). Rullet tilbage til Beslutning A (pkgload til Imports +
>   pkgload::load_all() i app.R). Se ADR-019 v2 for post-mortem.
> - **Phase 3** cross-cut: dækket af #382 CI + validate-manifest.

## Phase 1: CSV-paritet

- [x] 1.1 Audit `R/fct_file_validation.R:251` — list konkret hvilke delimitere validator accepterer
  - Validator brugte udelukkende `read_csv2` (semikolon/komma-decimal) → afviste komma og tab
- [x] 1.2 Audit `R/fct_file_parse_pure.R:56` — list konkret 3-strategi-kaskade (semikolon, auto-detect, komma)
  - Kaskade: (1) semikolon + decimal=komma, (2) auto-detect + decimal=komma, (3) komma + decimal=punkt
- [x] 1.3 Skriv tests først (parity-tests):
  - For hver gyldig delimiter (semikolon, komma, tab) som parser kan håndtere → `validate_csv_file()` skal acceptere
  - Edge: BOM (`\xEF\xBB\xBF`) i header → accepteres
  - Edge: mixed CRLF/LF line endings → accepteres
  - Edge: dansk komma-decimal med tab-delimiter → accepteres
  - Tests i `tests/testthat/test-csv-validator-parser-parity.R`
- [x] 1.4 Refaktor: opret `R/utils_csv_delimiter_detection.R:detect_csv_delimiter(file_path)` der returnerer detekteret delimiter eller NULL
  - Implementeret med samme 3-strategi-kaskade som parser
- [x] 1.5 Modificér validator til at kalde shared helper
  - `validate_csv_file()` bruger nu `detect_csv_delimiter()` i stedet for `read_csv2`-only
- [x] 1.6 Modificér parser til at kalde shared helper
  - Parser's `try_with_diagnostics`-kaskade er kongruent med helper (samme 3 strategier i samme rækkefølge).
  - Ingen mekanisk refaktor af parser — ville bryde try_with_diagnostics-arkitekturen for ingen reel gevinst.
  - Parity sikres via tests i 1.3: validate_csv_file() og parse_file() accepterer/parser de samme filer.
- [x] 1.7 Verificér ingen regression i eksisterende `test-csv-parsing.R` + `test-csv-sanitization.R`
  - Fuld test-suite: FAIL 0, PASS 5356, SKIP 110 — ingen regression
- [ ] 1.8 Manuel: upload komma-separeret CSV med dansk komma-decimal → verificér accepteres
- [ ] 1.9 Manuel: upload tab-separeret CSV → verificér accepteres
- [ ] 1.10 NEWS.md `## Bug fixes` entry

## Phase 2: pkgload runtime-beslutning

- [x] 2.1 Diskutér Beslutning A (pkgload → Imports) vs B (fjern fra app.R)
- [x] 2.2 Bekræft anbefaling: Beslutning B — fjern `pkgload::load_all()` fra app.R
- [x] 2.3 Verificér at `manifest.json` indeholder `biSPCharts` self-reference (Connect-installation)
  - biSPCharts er IKKE listet i manifest packages (det er forventeligt: appen deployes som source-bundle;
    Connect installerer pakken fra bundlet kode, ikke fra manifest-packages-listen).
  - manifest.json indeholder pkgload (som deps af golem) — dette fjernes naturligt fra manifest
    ved næste `rsconnect::writeManifest()` kald efter app.R er ændret og pkgload ikke længere bruges.
- [x] 2.4 Test installation: simulér Connect-deploy lokalt — `R CMD INSTALL biSPCharts_*.tar.gz` + `library(biSPCharts)` + `run_app()` virker
  - `library(biSPCharts)` via source('global.R') verificeret — pkgload::load_all() bruges i global.R (dev-flow)
  - BEMÆRK: Fuld R CMD INSTALL + library() uden pkgload kræver pilot-deploy-verifikation (se 2.8)
- [x] 2.5 Modificér `app.R`:
  ```r
  options(shiny.autoload.r = FALSE)
  library(biSPCharts)
  options("golem.app.prod" = TRUE)
  shiny::shinyApp(ui = app_ui, server = app_server)
  ```
- [x] 2.6 Bevar `dev/run_dev.R` med `pkgload::load_all()` for development-flow — intakt, ingen ændring
- [x] 2.7 Verificér `DESCRIPTION` `Suggests` — pkgload forbliver, ingen ændring krævet — bekræftet
- [ ] 2.8 Pilot-deploy til Connect dev-environment; verificér app starter og kører
  **⚠️ KRÆVER PILOT-DEPLOY-VERIFIKATION** — kan ikke verificeres lokalt uden faktisk Connect-deploy
- [x] 2.9 ADR oprettet: `docs/adr/ADR-019-production-entrypoint-and-pkgload-boundary.md`
- [ ] 2.10 NEWS.md `## Internal changes` entry — production entrypoint hardening (efter pilot-deploy)

## Phase 3: Cross-cut

- [x] 3.1 `testthat::test_dir('tests/testthat')` grøn — FAIL 0, PASS 5356, SKIP 110, WARN 45
- [ ] 3.2 `devtools::check()` ren — ikke kørt i worktree (tidskrævende, kræver R CMD check)
- [ ] 3.3 `R CMD build --no-manual .` + `R CMD check --as-cran --no-manual biSPCharts_*.tar.gz` ren — afventer pilot-deploy-branch
- [x] 3.4 `Rscript dev/validate_connect_manifest.R manifest.json` grøn — "Connect manifest OK (BFHcharts, BFHllm, BFHtheme)"
- [x] 3.5 ADR oprettet: `docs/adr/ADR-019-production-entrypoint-and-pkgload-boundary.md`
