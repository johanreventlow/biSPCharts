# Test Fixtures

Pre-genererede test-datasæt til brug i testthat-tests. Formålet er:

1. **Determinisme** — fast seed sikrer reproducerbare resultater
2. **Performance** — undgå `rnorm()` / `sample()` ved hver test-kørsel
3. **Delt kontrakt** — ensarted data-shape på tværs af relaterede tests

## Filer

| Fil | Rows | Cols | Formål |
|---|---|---|---|
| `sample_spc_result.rds` | 24 | — | Mock SPC-result for AI-suggestion tests |
| `large_numeric_1000.rds` | 1000 | 3 | Performance-tests med numerisk data |
| `large_spc_500.rds` | 500 | 3 | SPC-tidsserier (Dato/Tæller/Nævner) |
| `cache_signature_10000.rds` | 10000 | 3 | Cache-signature performance-tests |
| `qic-baseline/*.rds` | varierer | — | qicharts2 regression-baseline (#31) |

## Brug i tests

```r
test_that("large data pipeline behaves correctly", {
  # Load pre-genereret fixture
  test_data <- readRDS(testthat::test_path("fixtures/large_numeric_1000.rds"))

  # Test-logik uden rnorm/sample
  result <- process_data(test_data)
  expect_equal(nrow(result), 1000)
})
```

## Regeneration

Fixtures opdateres manuelt når:
- Data-schema ændres (brug relevante generator-script)
- Størrelse-behov ændres
- Seed skal varieres (undgå — determinisme er vigtigt)

Kør:
```bash
# Core fixtures
Rscript tests/testthat/fixtures/create_large_test_data.R
Rscript tests/testthat/fixtures/create_sample_spc_result.R

# qicharts2 baseline (se scripts i qic-baseline/)
Rscript tests/testthat/fixtures/qic-baseline/capture_baselines.R
```

## §3.2.4 Foundation

Dette er foundation for §3.2.4 af `harden-test-suite-regression-gate` openspec change. Eksisterende tests der genererer store datasæt inline (500+ rows via `rnorm()`) kan konvertere til `readRDS(test_path("fixtures/large_*.rds"))` for at reducere test-runtime og sikre determinisme uden individuelle `set.seed()`-kald.

**Migrationskandidater (jf. baseline-scan):**
- `test-edge-cases-comprehensive.R` — flere `rnorm(100+)` kald
- `test-cache-data-signature-bugs.R` — `rnorm(10000)` matcher `cache_signature_10000.rds`
- `test-anhoej-metadata-local.R` — `rnorm(500)` matcher `large_spc_500.rds`
- `test-e2e-workflows.R` — `rnorm(1000)` matcher `large_numeric_1000.rds`

Migration er optional — gennemføres ad-hoc når en test bliver flaky eller langsom.
