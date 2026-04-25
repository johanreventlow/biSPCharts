## 1. Kortlæg eksisterende Anhøj-call-sites

- [ ] 1.1 `grep -rn "anhoej\|Anhøj\|crossings\|longest_run" R/` — dokumentér alle call-sites
- [ ] 1.2 Sammenlign `mod_spc_chart_compute.R:410` vs cache-aware observer input-preparation
- [ ] 1.3 Dokumentér eksisterende divergenser (hvis nogen) i `dev/audit-output/anhoej-call-sites.md`
- [ ] 1.4 Capture nuværende output for ≥10 test-fixtures (baseline-snapshot for regression)

## 2. Design pure-funktion API

- [ ] 2.1 Design signatur: `derive_anhoej_results(qic_data, chart_type, show_phases = FALSE) -> list(crossings, longest_run, runs_signal, crossings_signal, special_cause_points, data_points_used)`
- [ ] 2.2 Afklar input-kontrakt: hvad er `qic_data` præcist (data.frame returneret af qic() med return.data=TRUE)?
- [ ] 2.3 Dokumentér output-kontrakt med roxygen

## 3. Implementér

- [ ] 3.1 Opret `R/fct_spc_anhoej_derivation.R` med pure funktion
- [ ] 3.2 Funktionen kalder `require_qicharts2()` først (hvis qicharts2-calls nødvendige)
- [ ] 3.3 Ingen Shiny-imports, ingen `app_state`-reference
- [ ] 3.4 Roxygen med @examples

## 4. Tests

- [ ] 4.1 Opret `tests/testthat/test-derive-anhoej-results.R`
- [ ] 4.2 Test baseline fixture: 20 random-walk-punkter, run-chart → kendte resultater
- [ ] 4.3 Test edge cases: tom data, 1 punkt, alle NA, alle ens
- [ ] 4.4 Test med show_phases=TRUE og skift-kolonne
- [ ] 4.5 Test med kontrolgrænse-brud (p-chart, c-chart)
- [ ] 4.6 Regression-test: for hver baseline-fixture, verificér output matcher snapshot fra §1.4

## 5. Refaktorér call-sites

- [ ] 5.1 Opdatér `mod_spc_chart_compute.R:410` til kald af `derive_anhoej_results()`
- [ ] 5.2 Opdatér cache-aware observer (find eksakt linje)
- [ ] 5.3 Konsolidér `fct_spc_bfh_signals.R::calculate_combined_anhoej_signal()` — enten erstat med wrapper eller dokumentér bevaret API
- [ ] 5.4 Fjern duplicate input-preparation-kode

## 6. Regression-verifikation

- [ ] 6.1 Kør fuld test-suite — alle Anhøj-relaterede tests skal fortsat passere
- [ ] 6.2 Kør test-bfhcharts-integration.R, test-anhoej-metadata-local.R, test-centerline-handling.R eksplicit
- [ ] 6.3 Manuel verificering: upload test-CSV, sammenlign Anhøj-metadata før/efter refaktor
- [ ] 6.4 Kør `openspec validate extract-anhoej-derivation-pure --strict`

Tracking: GitHub Issue #318
