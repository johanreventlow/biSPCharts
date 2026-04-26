## 1. Kortlæg eksisterende Anhøj-call-sites

- [x] 1.1 `grep -rn "anhoej\|Anhøj\|crossings\|longest_run" R/` — dokumentér alle call-sites
- [x] 1.2 Sammenlign `mod_spc_chart_compute.R:410` vs cache-aware observer input-preparation
- [x] 1.3 Dokumentér eksisterende divergenser (hvis nogen) i `dev/audit-output/anhoej-call-sites.md`
- [x] 1.4 Capture nuværende output for ≥10 test-fixtures (baseline-snapshot for regression — via qic-baseline/*.rds fixtures i tests)

## 2. Design pure-funktion API

- [x] 2.1 Design signatur: `derive_anhoej_results(qic_data, show_phases = FALSE)` (chart_type ekskluderet — bruges kun til message-formatering i caller)
- [x] 2.2 Afklar input-kontrakt: `qic_data` er data.frame fra qicharts2/BFHcharts med kolonner `runs.signal`, `n.crossings`, `n.crossings.min` (og valgfrit `longest.run`, `longest.run.max`, `part`, `y`)
- [x] 2.3 Dokumentér output-kontrakt med roxygen (ni felter)

## 3. Implementér

- [x] 3.1 Opret `R/fct_spc_anhoej_derivation.R` med pure funktion
- [x] 3.2 Funktionen kræver ikke `require_qicharts2()` — den beregner fra allerede-computed qic_data (ingen direkte qicharts2-kald)
- [x] 3.3 Ingen Shiny-imports, ingen `app_state`-reference
- [x] 3.4 Roxygen med @examples (@dontrun)

## 4. Tests

- [x] 4.1 Opret `tests/testthat/test-derive-anhoej-results.R`
- [x] 4.2 Test baseline fixture: syntetisk qic_data med kendte resultater (output-struktur, typer, runs/crossings signal)
- [x] 4.3 Test edge cases: tom data, 1 punkt, alle NA runs.signal, manglende valgfrie kolonner
- [x] 4.4 Test med show_phases=TRUE og part-kolonne
- [x] 4.5 Test med kontrolgrænse-brud (crossings_signal TRUE/FALSE scenarios)
- [x] 4.6 Regression-test: 6 qic-baseline fixtures (p, i, run, c, u, s) verificeret mod derive_anhoej_results()

## 5. Refaktorér call-sites

- [x] 5.1 Opdatér `mod_spc_chart_compute.R` primær observer til kald af `derive_anhoej_results()`
- [x] 5.2 Opdatér cache-aware observer til `derive_anhoej_results()`
- [x] 5.3 `fct_spc_bfh_signals.R::calculate_combined_anhoej_signal()` bevaret uændret — anden semantik (per-punkt signal fra data.frame med explicit kolonne-navne, tjener decorator-path); ikke scope for dette change
- [x] 5.4 Fjern duplicate input-preparation-kode i `update_anhoej_results()` — qic_data/show_phases-parametre fjernet, re-derivationsblok fjernet

## 6. Regression-verifikation

- [x] 6.1 Kør fuld test-suite — exit code 0 (alle Anhøj-relaterede tests bestod)
- [x] 6.2 Kør test-anhoej-rules.R: FAIL 0 / PASS 52; test-anhoej-metadata-local.R: FAIL 3 (pre-eksisterende timing-tests)
- [x] 6.3 Pre-push gate (fast mode) bestod: 152s
- [ ] 6.4 Manuel verificering: upload test-CSV, sammenlign Anhøj-metadata (kræver kørende app)

PR: https://github.com/johanreventlow/biSPCharts/pull/331
Tracking: GitHub Issue #318
