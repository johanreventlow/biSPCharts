# test-anhoej-thresholds.R
# Tests for n<12-tærskel for Anhøj-fortolkning og multi-fase aggregering.
# Spec: openspec/changes/fix-spc-domain-correctness/specs/domain-core/spec.md

library(testthat)

# Hjælper: lav minimal qic_data med n observationer
make_qic_data <- function(n_obs, n_crossings_min = NA, n_crossings = NA) {
  data.frame(
    x = seq_len(n_obs),
    y = runif(n_obs),
    runs.signal = rep(FALSE, n_obs),
    n.crossings = rep(n_crossings, n_obs),
    n.crossings.min = rep(n_crossings_min, n_obs),
    longest.run = rep(2, n_obs),
    longest.run.max = rep(8, n_obs),
    part = rep(1L, n_obs)
  )
}

# --- derive_anhoej_results: crossings_signal skal være NA ved n.crossings.min = NA ---

test_that("derive_anhoej_results: crossings_signal er NA når n.crossings.min er NA (n=8)", {
  qic <- make_qic_data(8, n_crossings_min = NA, n_crossings = NA)
  result <- derive_anhoej_results(qic, show_phases = FALSE)
  expect_true(is.na(result$crossings_signal),
    info = "crossings_signal skal være NA (ikke FALSE) ved n_crossings_min = NA"
  )
})

test_that("derive_anhoej_results: crossings_signal er NA propageret korrekt", {
  qic <- make_qic_data(8, n_crossings_min = NA, n_crossings = NA)
  result <- derive_anhoej_results(qic, show_phases = FALSE)
  # anhoej_signal skal reflektere at vi ikke kan vurdere
  # (enten NA eller FALSE -- det vigtige er at crossings ikke er FALSE ved NA min)
  expect_true(is.na(result$crossings_signal))
})

# --- interpret_anhoej_signal_da: kort serie skal give "Utilstrækkelige data" ---

test_that("interpret_anhoej_signal_da returnerer 'Utilstrækkelige data' ved n_crossings_min = NA", {
  anhoej_result <- list(
    runs_signal = FALSE,
    crossings_signal = NA,
    n_crossings_min = NA,
    data_points_used = 8L
  )
  result <- interpret_anhoej_signal_da(anhoej_result)
  expect_true(
    grepl("Utilstr", result, ignore.case = TRUE) ||
      grepl("n<12", result, ignore.case = TRUE) ||
      grepl("tilstr", result, ignore.case = TRUE),
    info = paste("Forventede 'Utilstrækkelige data', fik:", result)
  )
})

test_that("interpret_anhoej_signal_da returnerer IKKE 'Stabil proces' ved crossings_signal = NA", {
  anhoej_result <- list(
    runs_signal = FALSE,
    crossings_signal = NA,
    n_crossings_min = NA,
    data_points_used = 8L
  )
  result <- interpret_anhoej_signal_da(anhoej_result)
  expect_false(
    grepl("Stabil", result),
    info = paste("'Stabil proces' er falsk tryghed ved n<12. Fik:", result)
  )
})

# --- Lang serie bevarer eksisterende fortolkning (regression) ---

test_that("interpret_anhoej_signal_da: lang serie med gyldige signals bevarer eksisterende fortolkning", {
  anhoej_stabil <- list(
    runs_signal = FALSE,
    crossings_signal = FALSE,
    n_crossings_min = 4,
    data_points_used = 15L
  )
  result <- interpret_anhoej_signal_da(anhoej_stabil)
  expect_equal(result, "Stabil proces (ingen særskilt årsag)")
})

test_that("interpret_anhoej_signal_da: runs_signal trigger ved lang serie", {
  anhoej_runs <- list(
    runs_signal = TRUE,
    crossings_signal = FALSE,
    n_crossings_min = 4,
    data_points_used = 15L
  )
  result <- interpret_anhoej_signal_da(anhoej_runs)
  expect_equal(result, "Særskilt årsag: lang serie")
})

# --- Multi-fase: extract_anhoej_metadata aggregerer korrekt ---

make_multiphase_qic <- function(n_cross1, n_cross_min1, n_cross2, n_cross_min2) {
  n_per_phase <- 10
  n_total <- n_per_phase * 2
  data.frame(
    x = seq_len(n_total),
    y = runif(n_total),
    runs.signal = rep(FALSE, n_total),
    n.crossings = c(rep(n_cross1, n_per_phase), rep(n_cross2, n_per_phase)),
    n.crossings.min = c(rep(n_cross_min1, n_per_phase), rep(n_cross_min2, n_per_phase)),
    longest.run = rep(2, n_total),
    longest.run.max = rep(8, n_total),
    part = c(rep(1L, n_per_phase), rep(2L, n_per_phase))
  )
}

test_that("extract_anhoej_metadata: single-fase returnerer skalær n_crossings (regression)", {
  qic <- data.frame(
    x = 1:15,
    y = runif(15),
    runs.signal = rep(FALSE, 15),
    n.crossings = rep(5, 15),
    n.crossings.min = rep(4, 15),
    longest.run = rep(2, 15),
    longest.run.max = rep(8, 15),
    part = rep(1L, 15)
  )
  meta <- extract_anhoej_metadata(qic)
  expect_false(meta$crossings_signal)
  expect_equal(meta$n_crossings, 5)
  expect_equal(meta$n_crossings_min, 4)
})

test_that("extract_anhoej_metadata: 2-fase returnerer NA for skalær n_crossings", {
  qic <- make_multiphase_qic(n_cross1 = 5, n_cross_min1 = 4, n_cross2 = 2, n_cross_min2 = 4)
  meta <- extract_anhoej_metadata(qic)
  expect_true(is.na(meta$n_crossings),
    info = "Skalær n_crossings skal være NA for multi-fase (ingen enkelt overall)"
  )
  expect_true(is.na(meta$n_crossings_min),
    info = "Skalær n_crossings_min skal være NA for multi-fase"
  )
})

test_that("extract_anhoej_metadata: 2-fase crossings_signal = TRUE hvis part 2 fejler", {
  # Part 1: OK (5 >= 4). Part 2: fejler (2 < 4).
  qic <- make_multiphase_qic(n_cross1 = 5, n_cross_min1 = 4, n_cross2 = 2, n_cross_min2 = 4)
  meta <- extract_anhoej_metadata(qic)
  expect_true(meta$crossings_signal,
    info = "crossings_signal skal være TRUE når part 2 fejler -- skjult signal afsløret"
  )
})

test_that("extract_anhoej_metadata: 2-fase begge OK -- crossings_signal = FALSE", {
  qic <- make_multiphase_qic(n_cross1 = 5, n_cross_min1 = 4, n_cross2 = 5, n_cross_min2 = 4)
  meta <- extract_anhoej_metadata(qic)
  expect_false(meta$crossings_signal)
})
