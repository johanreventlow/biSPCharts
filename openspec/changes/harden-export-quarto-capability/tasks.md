## 1. Capability-check helper

- [ ] 1.1 Opret `check_quarto_capability()` i `R/utils_export_helpers.R` der returnerer `list(available = TRUE/FALSE, quarto_version = ..., typst_supported = ..., message = ...)`
- [ ] 1.2 Implementér checks: `Sys.which("quarto")`, parse version fra `quarto --version`, check Typst-format-understøttelse
- [ ] 1.3 Cache resultat per Shiny-session (capability ændrer sig ikke runtime)
- [ ] 1.4 Tests: mock `Sys.which` og `system2` for at teste begge branches

## 2. Input-validering

- [ ] 2.1 Validér `dpi`-argument i `utils_server_export.R`: numeric + range `[72, 600]`, kast typed `export_input_error` ved out-of-range
- [ ] 2.2 Validér øvrige eksport-args (format, output-path)
- [ ] 2.3 Tilføj tests for input-validering

## 3. Erstat :::-kald

- [ ] 3.1 Identificér alle `BFHcharts:::`-kald i export-path: `grep -rn "BFHcharts:::" R/`
- [ ] 3.2 Hvis BFHcharts public Typst-API eksisterer: migrér direkte
- [ ] 3.3 Hvis ikke: opret BFHcharts issue + wrap midlertidigt med lokal helper der bruger public-API der findes + dokumentér workaround

## 4. Async-eksport

- [ ] 4.1 Vurder hvilket async-pattern: `promises::future_promise()`, `callr::r_bg()`, eller simpel observer-struktur med progress-indikator
- [ ] 4.2 Refaktorér eksport-kald i `mod_export_*.R` til async
- [ ] 4.3 Vis progress-indikator under eksport
- [ ] 4.4 Håndtér fejl i async-context: resultat-promise afviser med typed error, observer viser dansk besked

## 5. Capability-check integration

- [ ] 5.1 Ved eksport-request: kald `check_quarto_capability()` først
- [ ] 5.2 Hvis ikke tilgængelig: vis dansk besked med admin-kontakt-hint, abort eksport
- [ ] 5.3 Log struktureret: `log_warn(.context = "EXPORT", details = list(capability = capability_result))`

## 6. Test-infrastruktur

- [ ] 6.1 Opret `tests/testthat/test-export-quarto-capability.R` med mocked capability-check
- [ ] 6.2 Opret `.github/workflows/export-smoke-test.yaml`:
  - Trigger: schedule nightly + workflow_dispatch
  - Installér Quarto CLI + Typst
  - Kør end-to-end eksport mod test-fixture
  - Verificér output-PNG har forventet dimensioner og ikke er blank
- [ ] 6.3 Upload eksport-output som workflow-artifact for review

## 7. Dokumentation

- [ ] 7.1 Opdatér `docs/DEPLOYMENT_GUIDE.md` med Quarto-krav
- [ ] 7.2 Opdatér `CLAUDE.md` eksport-sektion hvis eksisterende
- [ ] 7.3 Tilføj troubleshooting-entry i `docs/TROUBLESHOOTING_GUIDE.md` for "Quarto not found"
- [ ] 7.4 Kør `openspec validate harden-export-quarto-capability --strict`

Tracking: GitHub Issue #319
