## Why

Ekstern Gemini-review (2026-04-23) identificerede at `find_numeric_columns()` i
`R/fct_autodetect_helpers.R:215` bruger `as.numeric()` til at vurdere om en kolonne
er numerisk. `as.numeric("10,5")` returnerer `NA` i R, så kolonner med dansk
talformat (komma som decimalseparator) detekteres ikke som numeriske. Brugeren
tvinges til manuelt at vælge kolonner, selvom appen reklamerer med auto-detection.

`parse_danish_number()` eksisterer allerede i `R/utils_danish_locale.R` og bruges
korrekt i `utils_spc_data_processing.R` og `utils_qic_preparation.R` — den
mangler blot at blive kaldt fra auto-detect-motoren.

GitHub Issue: #302

## What Changes

- **`R/fct_autodetect_helpers.R:215`** (detection gate — primær fix):
  ```r
  # Nuværende:
  converted <- suppressWarnings(as.numeric(test_sample))

  # Fix:
  converted <- suppressWarnings(parse_danish_number(test_sample))
  ```

- **`R/fct_autodetect_helpers.R:422`** (scoring-funktion):
  ```r
  # Nuværende:
  clean_data <- suppressWarnings(as.numeric(as.character(clean_data)))

  # Fix:
  clean_data <- suppressWarnings(parse_danish_number(as.character(clean_data)))
  ```

- **`R/fct_autodetect_helpers.R:502`** (scoring-funktion — identisk mønster):
  Samme ændring som linje 422.

- **Nye tests** i `tests/testthat/test-fct_autodetect_helpers.R`:
  - `find_numeric_columns()` returnerer korrekte kolonner for data med dansk
    talformat (`"10,5"`, `"3,14"`)
  - Regression: engelske tal (punktum) virker fortsat
  - `find_numeric_columns()` returnerer tom vektor for rene tekst-kolonner

## Impact

- **Affected specs**: `autodetect` (eksisterende capability)
- **Affected code**:
  - `R/fct_autodetect_helpers.R` (3 linjer)
  - `tests/testthat/test-fct_autodetect_helpers.R` (nye tests)
- **Risks**: Ingen — `parse_danish_number()` håndterer punktum og komma,
  så engelske talformater (den nuværende succescase) fortsat virker.
- **Non-breaking**: Ingen ændring af public API eller UI-adfærd. Brugere af
  dansk CSV-data oplever bedre auto-detection.

## Success Criteria

- `parse_danish_number(c("10,5", "3,14", "100"))` returnerer `c(10.5, 3.14, 100)`
- `find_numeric_columns()` returnerer kolonne med `c("10,5", "3,14")` som numerisk
- Alle eksisterende autodetect-tests består
- Ingen regression i engelske talformater
