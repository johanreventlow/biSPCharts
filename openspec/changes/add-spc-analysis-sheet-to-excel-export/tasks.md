## 1. Pure Anhøj per-part-derivation

- [x] 1.1 Tilføj `derive_anhoej_per_part(qic_data)` i `R/fct_spc_anhoej_derivation.R` — pure funktion, returnerer liste af `derive_anhoej_results()`-output per unik `part`-værdi (eller én "part 1" hvis kolonnen mangler)
- [x] 1.2 Tilføj `interpret_anhoej_signal_da(anhoej_result)` i `R/fct_spc_anhoej_derivation.R` — mapper signal-flag til dansk klinisk-venlig tekst per beslutnings-tabel i design.md §Decision 7
- [x] 1.3 TDD: skriv `tests/testthat/test-derive_anhoej_per_part.R` — fixture med 3 parts, runs+crossings combinations, edge cases (1 part, manglende `part`-kolonne, tomt qic_data); test før implementation
- [x] 1.4 TDD: skriv `tests/testthat/test-interpret_anhoej_signal_da.R` — alle 4 signal-kombinationer fra design-tabel
- [x] 1.5 Kør `devtools::document()` hvis nye exports tilføjes (sandsynligt `@keywords internal` → ingen export)

## 2. Excel sektion-builders (pure)

- [x] 2.1 Opret `R/fct_spc_excel_analysis.R` med modulhead-roxygen og `@name fct_spc_excel_analysis`
- [x] 2.2 Implementér `build_overview_section(qic_data, metadata, anhoej_per_part, y_axis_unit, freeze_position, computed_at, pkg_versions)` → returnerer 2-kolonne data.frame (Felt/Værdi) med charttype, N obs, antal parts, freeze-info, target+Δ, ooc-rækker, freeze-baseline, dansk samlet tolkning, beregningsdato, versioner
- [x] 2.3 Implementér `build_per_part_section(qic_data, y_axis_unit, target_value, phase_names)` → returnerer data.frame med kolonner Part │ Phase-navn │ Fra │ Til │ N │ CL │ UCL │ LCL │ Mean │ Median │ Target │ Δ til CL; tids-y-akse konverteres til UI-enhed via reverse-helper
- [x] 2.4 Implementér `build_anhoej_section(anhoej_per_part)` → returnerer data.frame med kolonner Part │ Længste serie │ Maks tilladt │ Antal kryds │ Min krævet │ Runs-signal │ Crossings-signal │ Samlet signal │ Dansk tolkning
- [x] 2.5 Implementér `build_special_cause_section(qic_data, original_data, y_axis_unit, kommentar_column, n_column)` → returnerer data.frame med kolonner Række │ Dato │ Værdi │ CL │ UCL │ LCL │ Out-of-limits │ Runs-signal │ Notes │ Nævner (n); kun rækker med ooc eller runs.signal=TRUE
- [x] 2.6 Implementér orkestrator `build_spc_analysis_sheet(qic_data, metadata, original_data, options)` → returnerer named list `list(overview = df, per_part = df, anhoej = df, special_cause = df)`; returnerer `NULL` hvis qic_data tomt eller invalid
- [x] 2.7 Tilføj reverse time-formatter `format_time_from_minutes(minutes, target_unit)` i `R/utils_time_parsing.R` (modpart til `parse_time_to_minutes`)

## 3. TDD for Excel sektion-builders

- [x] 3.1 ~~RDS-fixture~~ — erstattet af programmatiske fixtures i `tests/testthat/helper-spc-excel-analysis-fixtures.R` (mere robust på tværs af R-versioner; ingen binær-files i repo)
- [x] 3.2 ~~RDS-fixture~~ — `fixture_qic_data_run_chart()` i samme helper-fil
- [x] 3.3 ~~RDS-fixture~~ — `fixture_qic_data_time_hours()` i samme helper-fil
- [x] 3.4 Skriv `tests/testthat/test-fct_spc_excel_analysis.R` — 23 expectations dækker alle scenarios fra spec
- [x] 3.5 Verifér purity via `grep -n "app_state\|session\|reactiveValues\|reactive(\|isolate(\|observeEvent\|observe("` — kun match er kommentar-header

## 4. Integration i `build_spc_excel()`

- [x] 4.1 Udvid `build_spc_excel(data, metadata, qic_data = NULL, original_data = NULL, ...)` i `R/fct_spc_file_save_load.R` til at acceptere `qic_data` + relaterede inputs
- [x] 4.2 Hvis `qic_data` er ikke-NULL: kald `build_spc_analysis_sheet(...)`, addWorksheet `SPC-analyse`, skriv hver sektion via `.write_spc_analysis_sheet()` med blank-rækker + sektions-headere (A/B/C/D)
- [x] 4.3 Hvis `build_spc_analysis_sheet()` returnerer `NULL`: spring arket over, log-warning med kontekst `EXCEL_EXPORT`, fortsæt download
- [x] 4.4 Wrap kald i `safe_operation("Build SPC-analyse sheet", ...)` så fejl ikke blokerer Excel-download

## 5. Wizard-gate-kalder opdatering

- [x] 5.1 I `R/utils_server_wizard_gates.R::spc_save_content`: hent qic_data via `build_export_plot()` (samme pipeline som UI-grafen)
- [x] 5.2 Hvis `build_export_plot()` fejler eller returnerer NULL: SPC-analyse springes over (build_spc_excel håndterer NULL graciously)
- [x] 5.3 Pass `qic_data`, `original_data` og `analysis_options` (pkg_versions, computed_at) til `build_spc_excel()`

## 6. Round-trip regression

- [x] 6.1 `tests/testthat/test-spc_excel_round_trip.R` — 5 tests: 3-ark Excel parses korrekt, ingen leak fra SPC-analyse
- [x] 6.2 Bagudkompatibilitet: 2-ark Excel parses uden fejl (test #2)
- [x] 6.3 `parse_spc_excel()` uændret — eksisterende kode læser kun "Indstillinger"-arket, ignorerer øvrige

## 7. Edge cases & non-blocking-test

- [x] 7.1 `qic_data = NULL` → 2-ark Excel (testet via "Bagudkompatibilitet")
- [x] 7.2 Tomt qic_data → SPC-analyse springes over (testet via round-trip + sektion-builder tests)
- [x] 7.3 Run-chart → UCL/LCL tomme i sektion B (testet i fct_spc_excel_analysis)
- [x] 7.4 Ingen ooc → "Ingen special cause-punkter detekteret"-besked (testet i round-trip)
- [x] 7.5 Target ikke sat → tomme delta-celler (testet via default-args i build_per_part_section)
- [x] 7.6 Ingen freeze → tomme freeze-felter (testet via default-args i build_overview_section)

## 8. Performance & logging

- [ ] 8.1 ~~Benchmark 100 parts × 10000 obs~~ — udskudt; målt manuelt under TDD: 3 parts × 12 obs <50ms; ingen indikation af problem ved typiske kliniske datasæt (<10 parts, <500 obs)
- [x] 8.2 `log_debug(.context = "EXCEL_EXPORT", message = "SPC-analyse-ark bygget", details = list(n_parts, n_obs, n_special_cause))` tilføjet i `build_spc_excel()`
- [x] 8.3 Ny log-context `LOG_CONTEXTS$export$excel = "EXCEL_EXPORT"` registreret i `R/config_log_contexts.R`

## 9. Dokumentation

- [x] 9.1 Roxygen-kommentarer på alle nye funktioner med `@param`, `@return`, `@examples \dontrun{...}`, `@keywords internal`
- [x] 9.2 NEWS.md — bullet under "## Nye features" (biSPCharts 0.3.0)
- [x] 9.3 CLAUDE.md §2 — ny "### Excel Download (3-ark struktur)"-sektion

## 10. Quality gates

- [x] 10.1 `devtools::test()` — 1758 filer, 0 failed, 0 errors, 123 skipped (uændret baseline)
- [x] 10.2 `lintr::lint()` på nye filer — 0 lints i `fct_spc_excel_analysis.R`; pre-existing UPPER_CASE-konstant-lints i øvrige filer er projekt-konvention
- [x] 10.3 `styler::style_file()` på alle ændrede filer — `utils_server_wizard_gates.R` re-formatteret; alle øvrige uændrede
- [ ] 10.4 ~~`devtools::check()`~~ — udskudt til pre-push gate (lintr + tests grønne; check er heavy og dækkes af CI)
- [ ] 10.5 ~~Manuel verifikation~~ — udskudt til bruger (kræver interaktiv app + CSV-upload)
- [x] 10.6 UTF-8 fix i Excel-output — kolonneoverskrifter, sektion-headers og labels skrives nu med korrekte danske bogstaver (Værdi/Række/Anhøj/Længste/Nævner/Øvre/grænse/krævet) i stedet for ASCII-translit (Vaerdi/Raekke/Anhoej osv.). Tests opdateret. 214/214 grønne i berørte testfiler.

## 11. OpenSpec ↔ GitHub-integration (afventer bruger-godkendelse)

- [ ] 11.1 Opret GitHub issue — afventer bruger; kræver `gh issue create` (ekstern mutation)
- [ ] 11.2 Tilføj issue-nummer til `proposal.md` under `## Related`
- [ ] 11.3 Skift label til `openspec-implementing` ved start af apply
- [ ] 11.4 Skift label til `openspec-deployed`, luk issue ved `/opsx:archive`
