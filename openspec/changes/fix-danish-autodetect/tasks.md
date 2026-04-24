## 1. Fix auto-detection af dansk talformat

- [x] 1.1 Erstat `as.numeric(test_sample)` med `parse_danish_number(test_sample)` på linje 215 i `R/fct_autodetect_helpers.R`
- [x] 1.2 Erstat `as.numeric(as.character(clean_data))` med `parse_danish_number(as.character(clean_data))` på linje 422
- [x] 1.3 Tilsvarende fix på linje 502 (identisk mønster)

## 2. Tests

- [x] 2.1 Test: `find_numeric_columns()` returnerer kolonne med dansk talformat (`"10,5"`, `"3,14"`) korrekt
- [x] 2.2 Test: engelske tal (punktum) virker fortsat (regression)
- [x] 2.3 Test: `find_numeric_columns()` returnerer tom vektor for rene tekst-kolonner

## 3. Verifikation

- [x] 3.1 Alle autodetect-tests bestået
- [x] 3.2 PR #304 oprettet og merged ind i develop

Tracking: GitHub Issue #302
