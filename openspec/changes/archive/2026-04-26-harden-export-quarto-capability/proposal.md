## Why

Reviews (Claude + Codex, 2026-04-24) identificerede at export/preview-pipelinen i `R/utils_server_export.R:333-362` har tre skrøbelige afhængigheder: (1) Intern `BFHcharts:::bfh_create_typst_document()`-kald, (2) `system2("quarto", args = c("typst", "compile", ...))` der antager Quarto + Typst er i PATH uden capability-check, (3) Kører synchrone i Shiny reactive context — blokerer UI for store PDF/PNG-eksports. Konsekvens: produktion-deployment kan fejle på miljøer uden Quarto, og brugeren får uforudsigelig adfærd. Der mangler integrationstest i CI der verificerer hele eksport-preview-pipelinen.

## What Changes

- Opret nyt capability `export-preview` der kodificerer eksport-pipelinens garantier.
- Tilføj `check_quarto_capability()`-helper der verificerer (a) `Sys.which("quarto")` returnerer path, (b) Quarto-version er ≥ 1.3 (Typst-support), (c) nødvendige fonts er tilgængelige.
- Wrap `system2("quarto", ...)`-kald i `utils_server_export.R` med capability-check + dansk fallback-fejlbesked: "Preview kræver Quarto 1.3+. Denne Shiny-installation har: <version eller missing>. Kontakt administrator."
- Validér `dpi`-argument eksplicit som numeric + range `[72, 600]` før `system2`-kald.
- Refaktorér eksport-flow til at bruge `future_promise()` eller tilsvarende async-pattern så UI ikke blokerer. Vis progress-indikator under eksport.
- Erstat `BFHcharts:::bfh_create_typst_document()` med public-API-kald (afhængighed: `fix-dependency-namespace-guards`).
- Tilføj integrationstest `tests/testthat/test-export-quarto-capability.R` der (a) tester capability-check-logik med mocked Quarto, (b) kan køres i CI med installeret Quarto som smoke-test.
- Opret separat CI-workflow `export-smoke-test.yaml` (nightly + on-demand) der faktisk installerer Quarto og kører end-to-end eksport-preview mod test-fixture.

## Impact

- **Affected specs**: Nyt capability `export-preview` (ADDED)
- **Affected code**:
  - `R/utils_server_export.R` (capability-check, async-wrapper, fjern `:::`)
  - Ny: `R/utils_export_capability.R` eller tilføj til `utils_export_helpers.R`
  - Ny: `tests/testthat/test-export-quarto-capability.R`
  - Ny: `.github/workflows/export-smoke-test.yaml`
- **Afhængighed**: Depends on `fix-dependency-namespace-guards` for BFHcharts public-API-erstatning.
- **Risks**:
  - Async-refaktor ændrer timing-karakteristikker — verificér UI ikke afhænger af synkron eksport-completion
  - BFHcharts public Typst-API eksisterer muligvis ikke — kan kræve sideløbende BFHcharts-PR
- **Non-breaking for brugere**: Eksport-adfærd uændret ved normal brug; fejlbesked bedre ved missing-Quarto.

## Related

- GitHub Issue: #319
- Review-rapport: Claude (V4 system2-härdning) + Codex (K4 Export/preview)
