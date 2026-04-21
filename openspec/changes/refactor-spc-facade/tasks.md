## 1. Fundament: fejlklasser og cache-environment

- [ ] 1.1 Implementer `spc_abort()` helper i `R/utils_error_handling.R` med typed error-taksonomi
- [ ] 1.2 Dokumentér fejlklasser i `R/utils_error_handling.R` roxygen
- [ ] 1.3 Opret `R/utils_cache.R` med `cache_state <- new.env(parent = emptyenv())`
- [ ] 1.4 Definer `cache_state$panel_stats`, `cache_state$grob_stats`, `cache_state$panel_config`, `cache_state$grob_config`
- [ ] 1.5 Implementer getters/setters: `get_panel_stats()`, `update_panel_stats()`, osv.
- [ ] 1.6 Find alle referencer til `.panel_cache_stats`, `.grob_cache_stats`, `.panel_cache_config`, `.grob_cache_config` i R/ og opdater til `cache_state$...`
- [ ] 1.7 Slet package-level `.panel_cache_*` og `.grob_cache_*` bindings
- [ ] 1.8 Fjern `unlock_cache_statistics()` fra `R/zzz.R`
- [ ] 1.9 Fjern kald til `unlock_cache_statistics()` fra `.onLoad` og andre steder
- [ ] 1.10 Test: `devtools::load_all()` + `devtools::test()` består; `R CMD check` viser ikke længere unlockBinding-warnings

## 2. S3-kontrakter

- [ ] 2.1 Design `spc_request` S3 (constructor + validator + print-method)
- [ ] 2.2 Design `spc_prepared` S3
- [ ] 2.3 Design `spc_axes` S3
- [ ] 2.4 Dokumentér kontrakter i roxygen for hver helper
- [ ] 2.5 Tests for constructors: `test_that("spc_request validates required fields")`

## 3. Extract validate_spc_request()

- [ ] 3.1 Opret `R/fct_spc_validate.R`
- [ ] 3.2 Flyt al validering fra `compute_spc_results_bfh()` ind i `validate_spc_request()`
- [ ] 3.3 Konverter `stop()`-kald til `spc_abort(..., class = "spc_input_error")`
- [ ] 3.4 Test: `tests/testthat/test-fct_spc_validate.R` med edge cases (NULL data, manglende kolonner, ugyldig chart_type)
- [ ] 3.5 `compute_spc_results_bfh()` kalder nu `validate_spc_request()` først
- [ ] 3.6 Verificer fuld testsuite fortsat grøn

## 4. Extract prepare_spc_data()

- [ ] 4.1 Opret `R/fct_spc_prepare.R`
- [ ] 4.2 Flyt dato-parsing, numerisk parsing, data-filtering ind
- [ ] 4.3 Typed errors: `spc_prepare_error` ved parsing-fejl
- [ ] 4.4 Test: `tests/testthat/test-fct_spc_prepare.R`
- [ ] 4.5 Integrer i orkestrator, verificer testsuite grøn

## 5. Extract resolve_axis_units()

- [ ] 5.1 Flyt y-axis unit resolution, multiply-logik, label-formatering til `R/fct_spc_prepare.R` eller ny fil
- [ ] 5.2 Test: edge cases (multiply=1, 100, percentage-detection)
- [ ] 5.3 Integrer, verificer testsuite grøn

## 6. Extract build_bfh_args() + execute_bfh_request()

- [ ] 6.1 Opret `R/fct_spc_execute.R`
- [ ] 6.2 Flyt BFHcharts-parameter-mapping til `build_bfh_args()`
- [ ] 6.3 Flyt BFHcharts-kald + plot-mutering til `execute_bfh_request()`
- [ ] 6.4 `spc_render_error` ved BFHcharts-fejl
- [ ] 6.5 Test: mock BFHcharts-kald, verificer args-mapping
- [ ] 6.6 Integrer, verificer testsuite grøn

## 7. Extract decorate_plot_for_display() + metadata

- [ ] 7.1 Opret `R/fct_spc_decorate.R`
- [ ] 7.2 Flyt plot-decoration og Anhøj-metadata-ekstraktion
- [ ] 7.3 Test: verificer metadata-struktur uændret (`$signals_detected`, osv.)
- [ ] 7.4 Integrer, verificer testsuite grøn

## 8. Cache-helpers injicerbare

- [ ] 8.1 Implementer `read_spc_cache(key)` og `write_spc_cache(key, result)` som separate funktioner
- [ ] 8.2 `cache_reader` og `cache_writer` parametre på `compute_spc_results_bfh()` (default til real-funktioner, kan overrides i test)
- [ ] 8.3 Test: kør med mock cache, verificer hit/miss logik

## 9. Orkestrator slim-down

- [ ] 9.1 Reducer `compute_spc_results_bfh()` til <100 linjer
- [ ] 9.2 Fjern intern `safe_operation()` i orkestrator — orkestrator propagerer typed errors
- [ ] 9.3 Tilføj top-level `tryCatch(spc_error = ...)` der bevarer NULL-returnering for bagudkompatibilitet
- [ ] 9.4 Logging bevares, men struktureret: `log_error(.context = "SPC_ORCHESTRATOR", ...)`

## 10. UI-boundary opdateringer

- [ ] 10.1 Opdater `R/mod_spc_chart_compute.R` med typed error catching
- [ ] 10.2 Vis danske brugervendte fejlbeskeder baseret på error-class
- [ ] 10.3 Test: verificer at UI viser korrekt besked ved hver fejl-klasse

## 11. Benchmark

- [ ] 11.1 Opret `tests/performance/bench-spc-facade.R` med `microbenchmark::microbenchmark()`
- [ ] 11.2 Kør før/efter-benchmark på repræsentative datasæt (10k, 100k rows, 4 chart-types)
- [ ] 11.3 Dokumentér resultat i PR-body
- [ ] 11.4 Rollback hvis p50 regression >5% eller p99 >10%

## 12. Dokumentation

- [ ] 12.1 Opdater CLAUDE.md sektion 4 (BFHcharts + qicharts2 hybrid arkitektur) med ny facade-struktur
- [ ] 12.2 Tilføj NEWS.md entry under "(development)"
- [ ] 12.3 ADR-dokument hvis ikke redundant med design.md

## 13. Final verifikation

- [ ] 13.1 `R CMD check --as-cran` 0 warnings om unlockBinding
- [ ] 13.2 Fuld testsuite grøn (modulo #279/#280 pre-existing)
- [ ] 13.3 Manuel smoke-test af Shiny-app på 3+ chart-typer
- [ ] 13.4 Benchmark inden for budget

Tracking: GitHub Issue TBD
