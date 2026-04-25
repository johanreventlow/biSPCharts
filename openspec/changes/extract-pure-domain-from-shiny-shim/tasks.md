## 1. Design og planlægning

- [ ] 1.1 Opret `openspec/changes/extract-pure-domain-from-shiny-shim/design.md` der dokumenterer:
  - Pure funktion API-signaturer
  - State-transition-helper konvention
  - Migration-plan (inkrementel)
  - Atomicity-garantier for state-transitions
- [ ] 1.2 Kortlæg nuværende `app_state$...<-`-assignments: `grep -rn "app_state\\\$.*<-" R/ | wc -l` (baseline-tælling)
- [ ] 1.3 Prioritér call-sites efter impact: file-upload > autodetect > visualization

## 2. File-parse pure extraktion

- [ ] 2.1 Opret `R/fct_file_parse_pure.R` med `parse_file(path, format, encoding_hints)` → `ParsedFile`-struktur
- [ ] 2.2 `ParsedFile` er S3-klasse med felter: `data`, `meta` (rows, cols, encoding, format), `warnings`
- [ ] 2.3 Flyt CSV-fallback-logik (fra `harden-csv-parse-error-reporting`) ind i pure funktion
- [ ] 2.4 Opret `apply_parsed_file_to_state(parsed, app_state, session, emit)` shim i `fct_file_operations.R`
- [ ] 2.5 Refaktorér `setup_file_upload()` til at kalde pure + shim
- [ ] 2.6 Tests: `tests/testthat/test-fct_file_parse_pure.R` med baseline-fixtures

## 3. Autodetect pure extraktion

- [ ] 3.1 Opret `R/fct_autodetect_pure.R` med `run_autodetect(data, hints)` → `AutodetectResult`
- [ ] 3.2 Flyt scoring-logik fra `fct_autodetect_helpers.R::score_by_*` ind i pure funktion
- [ ] 3.3 Opret `apply_autodetect_to_state(result, app_state, emit)` shim
- [ ] 3.4 Refaktorér `autodetect_engine()` (fct_autodetect_unified.R:17+) til pure + shim
- [ ] 3.5 Tests: `tests/testthat/test-fct_autodetect_pure.R`

## 4. Visualization-config pure extraktion

- [ ] 4.1 Opret `R/fct_visualization_config_pure.R` med `build_visualization_config(data, autodetect, user_overrides)`
- [ ] 4.2 Refaktorér `setup_visualization()` (fct_visualization_server.R:20-80) til pure + shim
- [ ] 4.3 Tests: `tests/testthat/test-fct_visualization_config_pure.R`

## 5. State-transition-helpers

- [ ] 5.1 Opret `R/utils_state_transitions.R`
- [ ] 5.2 Implementér: `transition_upload_to_ready(state, parsed_file)`, `transition_autodetect_complete(state, result)`, `transition_chart_config_updated(state, config)`
- [ ] 5.3 Hver helper: pure, ingen Shiny-imports, tager gammel state + input, returnerer ny state
- [ ] 5.4 Central `apply_state_transition(app_state, transition_fn, ...)` wrapper håndterer atomicity + reactive-trigger
- [ ] 5.5 Refaktorér eksisterende observers/handlers til at bruge helpers i stedet for direkte assignment
- [ ] 5.6 Tests: `tests/testthat/test-state-transitions.R` med contract-tests

## 6. Audit og verifikation

- [ ] 6.1 Opdatér `grep -rn "app_state\\\$.*<-" R/` — verificér reduktion ≥50% fra §1.2-baseline
- [ ] 6.2 Kør fuld test-suite — alle tests skal fortsat passere
- [ ] 6.3 Benchmark før/efter for upload + autodetect + chart-render (performance-regression-check)
- [ ] 6.4 Kør `openspec validate extract-pure-domain-from-shiny-shim --strict`

Tracking: GitHub Issue #320
