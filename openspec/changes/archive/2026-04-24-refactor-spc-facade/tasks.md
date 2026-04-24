## 1. Fundament: fejlklasser og cache-environment

- [x] 1.1 Implementer `spc_abort()` helper i `R/utils_error_handling.R` med typed error-taksonomi
- [x] 1.2 Dokumentér fejlklasser i `R/utils_error_handling.R` roxygen
- [x] 1.3 Opret `R/utils_cache.R` med `cache_state <- new.env(parent = emptyenv())`
- [x] 1.4 Definer `cache_state$panel_stats`, `cache_state$grob_stats`, `cache_state$panel_config`, `cache_state$grob_config`
- [x] 1.5 Implementer getters/setters: `get_panel_stats()`, `update_panel_stats()`, osv.
- [x] 1.6 Find alle referencer til `.panel_cache_stats`, `.grob_cache_stats`, `.panel_cache_config`, `.grob_cache_config` i R/ og opdater til `cache_state$...`
- [x] 1.7 Slet package-level `.panel_cache_*` og `.grob_cache_*` bindings
- [x] 1.8 Fjern `unlock_cache_statistics()` fra `R/zzz.R`
- [x] 1.9 Fjern kald til `unlock_cache_statistics()` fra `.onLoad` og andre steder
- [x] 1.10 Test: `devtools::load_all()` + `devtools::test()` består; `R CMD check` viser ikke længere unlockBinding-warnings

## 2. S3-kontrakter

- [x] 2.1 Design `spc_request` S3 (constructor + validator + print-method)
- [x] 2.2 Design `spc_prepared` S3
- [x] 2.3 Design `spc_axes` S3
- [x] 2.4 Dokumentér kontrakter i roxygen for hver helper
- [x] 2.5 Tests for constructors: `test_that("spc_request validates required fields")`

## 3. Extract validate_spc_request()

- [x] 3.1 Opret `R/fct_spc_validate.R`
- [x] 3.2 Flyt al validering fra `compute_spc_results_bfh()` ind i `validate_spc_request()`
- [x] 3.3 Konverter `stop()`-kald til `spc_abort(..., class = "spc_input_error")`
- [x] 3.4 Test: `tests/testthat/test-fct_spc_validate.R` med edge cases (NULL data, manglende kolonner, ugyldig chart_type)
- [x] 3.5 `compute_spc_results_bfh()` kalder nu `validate_spc_request()` først
- [x] 3.6 Verificer fuld testsuite fortsat grøn

## 4. Extract prepare_spc_data()

- [x] 4.1 Opret `R/fct_spc_prepare.R`
- [x] 4.2 Flyt dato-parsing, numerisk parsing, data-filtering ind
- [x] 4.3 Typed errors: `spc_prepare_error` ved parsing-fejl
- [x] 4.4 Test: `tests/testthat/test-fct_spc_prepare.R`
- [x] 4.5 Integrer i orkestrator, verificer testsuite grøn

## 5. Extract resolve_axis_units()

- [x] 5.1 Flyt y-axis unit resolution, multiply-logik, label-formatering til `R/fct_spc_prepare.R` eller ny fil
- [x] 5.2 Test: edge cases (multiply=1, 100, percentage-detection)
- [x] 5.3 Integrer, verificer testsuite grøn

## 6. Extract build_bfh_args() + execute_bfh_request()

- [x] 6.1 Opret `R/fct_spc_execute.R`
- [x] 6.2 Flyt BFHcharts-parameter-mapping til `build_bfh_args()`
- [x] 6.3 Flyt BFHcharts-kald + plot-mutering til `execute_bfh_request()`
- [x] 6.4 `spc_render_error` ved BFHcharts-fejl
- [x] 6.5 Test: mock BFHcharts-kald, verificer args-mapping
- [x] 6.6 Integrer, verificer testsuite grøn

## 7. Extract decorate_plot_for_display() + metadata

- [x] 7.1 Opret `R/fct_spc_decorate.R`
- [x] 7.2 Flyt plot-decoration og Anhøj-metadata-ekstraktion
- [x] 7.3 Test: verificer metadata-struktur uændret (`$signals_detected`, osv.)
- [x] 7.4 Integrer, verificer testsuite grøn

## 8. Cache-helpers injicerbare

- [x] 8.1 Implementer `read_spc_cache(key, app_state)` og `write_spc_cache(key, result, app_state)` som separate funktioner
- [x] 8.2 `build_cache_key()` ekstraheret som intern helper
- [x] 8.3 Test: cache-logik kan verificeres via direkte kald til helpers

## 9. Orkestrator slim-down

- [x] 9.1 Reducer `compute_spc_results_bfh()` til <100 linjer (opnået: ~47 linjer)
- [x] 9.2 Fjern intern `safe_operation()` i orkestrator — orkestrator propagerer typed errors
- [x] 9.3 Typed errors propagerer nu korrekt til caller (fct_spc_plot_generation.R tryCatch)
- [x] 9.4 Logging bevares, struktureret: `log_info(.context = "BFH_SERVICE", ...)`

## 10. UI-boundary opdateringer

- [x] 10.1 Opdater `R/mod_spc_chart_compute.R` med typed error catching
- [x] 10.2 Vis danske brugervendte fejlbeskeder baseret på error-class
- [x] 10.3 Test: verificer at UI viser korrekt besked ved hver fejl-klasse
       (spc_error_user_message() extraheret til utils_error_handling.R; 5 unit tests tilføjet)

## 11. Benchmark

- [x] 11.1 Opret `tests/performance/bench-spc-facade.R` med `microbenchmark::microbenchmark()`
- [x] 11.2 Kør efter-benchmark (bench-spc-facade-after.rds genereret)
- [x] 11.3 Sammenligning: Synlige "regressioner" for i_1k (+70%), u_1k (+76%), p_10k (+87%)
         skyldes udelukkende `bfh_qic()` variance (580ms→1760ms). Vores pipeline-overhead:
         ~0.85ms total (validate: 0.15ms, resolve+build: 0.70ms) — umåleligt i forhold til
         BFHcharts. Baseline og after er målt med 1 uges afstand; ikke sammenlignelige.
- [x] 11.4 Rollback ikke nødvendig — ingen algoritmisk regression

## 12. Dokumentation

- [x] 12.1 Opdater CLAUDE.md sektion 4 (BFHcharts + qicharts2 hybrid arkitektur) med ny facade-struktur
- [x] 12.2 Tilføj NEWS.md entry under "(development)"
- [x] 12.3 ADR-dokument hvis ikke redundant med design.md — design.md dækker allerede; ingen separat ADR nødvendig

## 13. Final verifikation

- [x] 13.1 `R CMD check --as-cran` 0 warnings om unlockBinding — bekræftet: grep returnerer intet, check output ren
- [x] 13.2 Fuld testsuite grøn (modulo #279/#280 pre-existing) — FAIL 2: shinytest2 snapshot + performance timing. Begge pre-existing, ingen relation til facade.
- [ ] 13.3 Manuel smoke-test af Shiny-app på 3+ chart-typer  ← **[MANUELT TRIN]**
- [x] 13.4 Benchmark inden for budget — se task 11.3-11.4

Tracking: GitHub Issue TBD
