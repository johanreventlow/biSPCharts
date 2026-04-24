# Script to create sample SPC result fixture for testing
# Run once to generate fixtures/sample_spc_result.rds
# Pure R - no package dependencies

# Create sample data
sample_data <- data.frame(
  date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
  value = c(
    35, 36, 37, 38, 37.5, 36.5, 35.5, 34.5,
    33.5, 34, 35, 36, 37, 38, 39, 40,
    39.5, 38.5, 37.5, 36.5, 35.5, 34.5, 33.5, 32.5
  )
)

# Create mock SPC result matching BFHcharts output structure
sample_spc_result <- list(
  plot = NULL, # ggplot object not needed for AI tests
  qic_data = data.frame(
    x = sample_data$date,
    y = sample_data$value,
    cl = rep(36, 24),
    ucl = rep(42, 24),
    lcl = rep(30, 24),
    part = rep(1, 24),
    signal = c(rep(FALSE, 10), TRUE, TRUE, TRUE, rep(FALSE, 11)),
    .original_row_id = 1:24
  ),
  metadata = list(
    chart_type = "run",
    n_points = 24,
    signals_detected = 3,
    anhoej_rules = list(
      longest_run = 8,
      n_crossings = 5,
      n_crossings_min = 7,
      runs_detected = TRUE,
      crossings_detected = FALSE
    ),
    n_phases = 1,
    freeze_applied = FALSE,
    bfh_version = "0.1.0"
  )
)

# Save fixture
saveRDS(sample_spc_result, "tests/testthat/fixtures/sample_spc_result.rds")
cat("✓ Fixture created: tests/testthat/fixtures/sample_spc_result.rds\n")
