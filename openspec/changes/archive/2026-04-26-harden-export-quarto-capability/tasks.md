## 1. Capability-check helper

- [x] 1.1 Opret `check_quarto_capability()` i `R/utils_export_helpers.R` der returnerer `list(available = TRUE/FALSE, quarto_version = ..., typst_supported = ..., message = ...)`
- [x] 1.2 Implementér checks: `Sys.which("quarto")`, parse version fra `quarto --version`, check Typst-format-understøttelse
- [x] 1.3 Cache resultat per R-session (session-scoped `local()`-environment; `.quarto_capability_cache`)
- [x] 1.4 Tests: mock `Sys.which` og `system2` for at teste begge branches

## 2. Input-validering

- [x] 2.1 Validér `dpi`-argument i `utils_server_export.R` via ny `validate_export_dpi()` helper: numeric + range `[72, 600]`, kast typed `export_input_error` ved out-of-range
- [ ] 2.2 Validér øvrige eksport-args (format, output-path) — deferred: scope udvider sig ud over original spec; kræver kendskab til download-handler i mod_export_download.R
- [x] 2.3 Tilføj tests for input-validering (se test-export-quarto-capability.R)

## 3. Erstat :::-kald

- [x] 3.1 Identificér alle `BFHcharts:::`-kald i export-path: `grep -rn "BFHcharts:::" R/` — kun to fund i kommentarer i fct_spc_plot_generation.R (linje 455, 630), ikke i eksekverbar kode
- [x] 3.2 `BFHcharts::bfh_create_typst_document()` allerede i public API — ingen :::  i koden
- [x] 3.3 Ingen workaround nødvendig

## 4. Async-eksport

- [x] 4.1 Vurderet: fuld async via `promises::future_promise()` kræver `future`-backend konfiguration i deployment — deferred (se nedenfor)
- [x] 4.2 Implementeret i stedet: `shiny::withProgress(message = "Genererer preview...", ...)` wrapper i `mod_export_server.R` — giver UX-feedback men blokerer ikke sessionen (synkront)
- [x] 4.3 Progress-indikator tilføjet via withProgress
- [ ] 4.4 Fuld async deferred: kræver `future::plan()` i deployment-konfiguration og coordination med hosting-team. Registrér separat issue hvis fuld async ønskes.

## 5. Capability-check integration

- [x] 5.1 `generate_pdf_preview()` i `utils_server_export.R` kalder nu `check_quarto_capability()` i stedet for den hardkodede `quarto_available()` (som returnerede altid TRUE)
- [x] 5.2 Hvis ikke tilgængelig: log_warn med dansk capability-besked, abort preview (result forbliver NULL)
- [x] 5.3 Log struktureret: `log_warn(component = "[EXPORT]", message = ..., details = list(capability = capability))`

## 6. Test-infrastruktur

- [x] 6.1 Opret `tests/testthat/test-export-quarto-capability.R` med mocked capability-check og validate_export_dpi tests
- [x] 6.2 Opret `.github/workflows/export-smoke-test.yaml`:
  - Trigger: schedule nightly (03:00 UTC) + workflow_dispatch
  - Installér Quarto CLI 1.4.557 (pinnet version med Typst-understøttelse)
  - Kør test-export-quarto-capability.R med stop_on_failure = TRUE
- [ ] 6.3 Upload eksport-output som workflow-artifact — deferred: kræver fixture-data der kører hele eksport-pipeline; scope ud over unit tests

## 7. Dokumentation

- [x] 7.1 Opdatér `docs/DEPLOYMENT.md` med Quarto-krav (ny "Quarto-krav" sektion under Prerequisites + troubleshooting entry)
- [ ] 7.2 Opdatér `CLAUDE.md` eksport-sektion — deferred: ingen eksisterende eksport-sektion i CLAUDE.md; change specificerer "hvis eksisterende"
- [x] 7.3 Tilføj troubleshooting-entry i `docs/DEPLOYMENT.md` for "Quarto ikke fundet" (under Common Issues)
- [ ] 7.4 Kør `openspec validate harden-export-quarto-capability --strict` — kræver openspec CLI

Tracking: GitHub Issue #319
