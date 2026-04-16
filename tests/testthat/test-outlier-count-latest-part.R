# Tests for count_outliers_latest_part()
#
# Kontekst:
# Trin 2 value box ("OBS. UDEN FOR KONTROLGRÆNSE") og trin 3 Typst-tabellen
# skal vise samme tal. BFHcharts' bfh_extract_spc_stats.bfh_qic_result filtrerer
# outliers til seneste part i qic_data — denne helper gør det samme på vores
# side, så anhoej_results$out_of_control_count matcher tabellen.

test_that("count_outliers_latest_part returns 0 for empty or missing signal column", {
  expect_equal(count_outliers_latest_part(data.frame()), 0L)
  expect_equal(count_outliers_latest_part(data.frame(x = 1:3)), 0L)
  expect_equal(count_outliers_latest_part(NULL), 0L)
})

test_that("count_outliers_latest_part counts all signals when no part column", {
  qd <- data.frame(sigma.signal = c(TRUE, FALSE, TRUE, NA, TRUE))

  expect_equal(count_outliers_latest_part(qd), 3L)
})

test_that("count_outliers_latest_part filters to latest part when present", {
  qd <- data.frame(
    sigma.signal = c(TRUE, TRUE, FALSE, FALSE, TRUE),
    part = c(1, 1, 1, 2, 2)
  )

  # Seneste part = 2, har 1 outlier
  expect_equal(count_outliers_latest_part(qd), 1L)
})

test_that("count_outliers_latest_part handles NA in signal vector", {
  qd <- data.frame(
    sigma.signal = c(NA, TRUE, NA, TRUE),
    part = c(1, 1, 2, 2)
  )

  expect_equal(count_outliers_latest_part(qd), 1L)
})
