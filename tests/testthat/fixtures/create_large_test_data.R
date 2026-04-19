# ==============================================================================
# create_large_test_data.R
# ==============================================================================
# §3.2.4 af harden-test-suite-regression-gate openspec change.
#
# Genererer `.rds`-fixtures til store test-datasæt (>50 rækker).
# Formål: reducere test-runtime ved at erstatte inline rnorm/sample-kald
# med pre-genererede datasæt. Sikrer også determinisme via fast seed.
#
# Kør manuelt når fixtures skal opdateres:
#   Rscript tests/testthat/fixtures/create_large_test_data.R
#
# Brug i tests:
#   fixture_path <- testthat::test_path("fixtures/large_numeric_1000.rds")
#   test_data <- readRDS(fixture_path)
# ==============================================================================

set.seed(42L) # Determinisk seed for reproducerbarhed

fixtures_dir <- if (basename(getwd()) == "fixtures") {
  "."
} else if (dir.exists("tests/testthat/fixtures")) {
  "tests/testthat/fixtures"
} else {
  stop("Kør scriptet fra projekt-rod eller tests/testthat/fixtures/")
}

# ------------------------------------------------------------------------------
# large_numeric_1000.rds — 1000-rækker numerisk dataset
# ------------------------------------------------------------------------------

large_numeric_1000 <- data.frame(
  x = seq_len(1000L),
  y = rnorm(1000, mean = 25, sd = 5),
  n = rep(100L, 1000L),
  stringsAsFactors = FALSE
)

saveRDS(large_numeric_1000, file.path(fixtures_dir, "large_numeric_1000.rds"))
cat(sprintf(
  "large_numeric_1000.rds (%d rows, %d cols)\n",
  nrow(large_numeric_1000), ncol(large_numeric_1000)
))

# ------------------------------------------------------------------------------
# large_spc_500.rds — 500-rækker SPC-formateret dataset (tidsserier)
# ------------------------------------------------------------------------------

large_spc_500 <- data.frame(
  Dato = seq.Date(from = as.Date("2020-01-01"), by = "day", length.out = 500L),
  Tæller = round(rnorm(500, mean = 50, sd = 10), 1),
  Nævner = rep(100L, 500L),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

saveRDS(large_spc_500, file.path(fixtures_dir, "large_spc_500.rds"))
cat(sprintf(
  "large_spc_500.rds (%d rows, %d cols)\n",
  nrow(large_spc_500), ncol(large_spc_500)
))

# ------------------------------------------------------------------------------
# cache_signature_10000.rds — 10k rows til cache-signature performance-tests
# ------------------------------------------------------------------------------

cache_signature_10000 <- data.frame(
  x1 = rnorm(10000L),
  x2 = rnorm(10000L),
  x3 = rnorm(10000L),
  stringsAsFactors = FALSE
)

saveRDS(cache_signature_10000, file.path(fixtures_dir, "cache_signature_10000.rds"))
cat(sprintf(
  "cache_signature_10000.rds (%d rows, %d cols)\n",
  nrow(cache_signature_10000), ncol(cache_signature_10000)
))

cat("\nAlle fixtures genereret (seed=42)\n")
