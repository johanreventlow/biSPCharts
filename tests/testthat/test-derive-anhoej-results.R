# test-derive-anhoej-results.R
# Tests for derive_anhoej_results() - ren Anhoej-udledningsfunktion
#
# Scenarie-dækning:
# 1. Baseline: korrekte output-felter og typer
# 2. Runs-signal: TRUE/FALSE baseret paa longest.run > longest.run.max
#    (#468: IKKE qic_data$runs.signal som tidligere — det er kombineret signal)
# 3. Crossings-signal: TRUE/FALSE baseret paa n.crossings < n.crossings.min
# 4. Kombineret anhoej_signal (runs ELLER crossings)
# 5. Manglende valgfrie kolonner → NA_real_ returnereres
# 6. Tomme/NULL datasaet → returnerer sikre defaults
# 7. show_phases = TRUE filtrerer til seneste part
# 8. Regression mod qic-baseline fixtures

library(testthat)

# ==============================================================================
# Helpers
# ==============================================================================

#' Byg minimal qic_data til tests
make_qic_data <- function(
  n = 20,
  runs_signal = rep(FALSE, n),
  n_crossings = 10,
  n_crossings_min = 8,
  longest_run = 3,
  longest_run_max = 8,
  sigma_signal = rep(FALSE, n),
  part = rep(1L, n),
  include_optional = TRUE
) {
  d <- data.frame(
    runs.signal = runs_signal,
    n.crossings = n_crossings,
    n.crossings.min = n_crossings_min,
    sigma.signal = sigma_signal,
    part = part,
    y = seq_len(n),
    stringsAsFactors = FALSE
  )
  if (include_optional) {
    d$longest.run <- longest_run
    d$longest.run.max <- longest_run_max
  }
  d
}

load_fixture_qic_data <- function(chart_type, scenario = "basic") {
  fixture_path <- test_path(sprintf(
    "fixtures/qic-baseline/%s-%s.rds",
    chart_type,
    scenario
  ))
  if (!file.exists(fixture_path)) {
    skip(sprintf("Baseline fixture mangler: %s", fixture_path))
  }
  readRDS(fixture_path)$qic_output$plot_data
}

# ==============================================================================
# 1. Output-struktur og typer
# ==============================================================================

test_that("derive_anhoej_results returnerer liste med ni navngivne felter", {
  qd <- make_qic_data()
  result <- derive_anhoej_results(qd)

  expect_type(result, "list")
  expected_names <- c(
    "runs_signal", "crossings_signal", "anhoej_signal",
    "longest_run", "longest_run_max",
    "n_crossings", "n_crossings_min",
    "special_cause_points", "data_points_used"
  )
  expect_named(result, expected_names, ignore.order = FALSE)
})

test_that("derive_anhoej_results returnerer korrekte typer", {
  qd <- make_qic_data()
  result <- derive_anhoej_results(qd)

  expect_type(result$runs_signal, "logical")
  expect_type(result$crossings_signal, "logical")
  expect_type(result$anhoej_signal, "logical")
  expect_type(result$longest_run, "double")
  expect_type(result$longest_run_max, "double")
  expect_type(result$n_crossings, "double")
  expect_type(result$n_crossings_min, "double")
  expect_type(result$special_cause_points, "logical")
  expect_type(result$data_points_used, "integer")
})

test_that("data_points_used matcher nrow(qic_data)", {
  qd <- make_qic_data(n = 25)
  result <- derive_anhoej_results(qd)
  expect_equal(result$data_points_used, 25L)
})

# ==============================================================================
# 2. Runs-signal
# ==============================================================================

test_that("runs_signal er FALSE naar longest.run <= longest.run.max", {
  # #468: runs_signal afhaenger nu af longest.run > longest.run.max,
  # ikke af kombineret runs.signal-kolonne.
  qd <- make_qic_data(longest_run = 3, longest_run_max = 8)
  result <- derive_anhoej_results(qd)
  expect_false(result$runs_signal)
})

test_that("runs_signal er TRUE naar longest.run > longest.run.max (#468)", {
  qd <- make_qic_data(longest_run = 12, longest_run_max = 8)
  result <- derive_anhoej_results(qd)
  expect_true(result$runs_signal)
})

test_that("runs_signal er FALSE naar longest.run-kolonner mangler", {
  qd <- make_qic_data(include_optional = FALSE)
  result <- derive_anhoej_results(qd)
  expect_false(result$runs_signal)
})

test_that("runs_signal haandterer NA i longest.run-felter (#468)", {
  # NA-guard: hvis enten longest.run eller longest.run.max er NA -> ingen signal
  qd <- make_qic_data(longest_run = NA_integer_, longest_run_max = 8)
  result <- derive_anhoej_results(qd)
  expect_false(result$runs_signal)

  qd2 <- make_qic_data(longest_run = 10, longest_run_max = NA_real_)
  result2 <- derive_anhoej_results(qd2)
  expect_false(result2$runs_signal)
})

test_that("runs_signal er IKKE drevet af qic_data\\$runs.signal (#468 regression)", {
  # qicharts2's runs.signal er kombineret signal — derive_anhoej_results
  # skal IKKE bruge det til at saette runs_signal. Crossing-only data
  # har runs.signal=TRUE men longest.run <= longest.run.max.
  qd <- data.frame(
    runs.signal = rep(TRUE, 20), # Saetter runs.signal=TRUE som qicharts2 ville
    n.crossings = 3L,
    n.crossings.min = 6L, # Kryds-violation aktiv
    longest.run = 5L,
    longest.run.max = 7L, # Ingen runs-violation
    sigma.signal = rep(FALSE, 20),
    part = rep(1L, 20),
    y = seq_len(20)
  )
  result <- derive_anhoej_results(qd)
  expect_false(result$runs_signal,
    info = "longest.run=5 <= max=7 -> ingen runs-violation, trods runs.signal=TRUE"
  )
  expect_true(result$crossings_signal)
  expect_true(result$anhoej_signal)
})

test_that("runs_signal er FALSE naar alle runs.signal er NA", {
  qd <- make_qic_data(n = 5, runs_signal = rep(NA, 5))
  result <- derive_anhoej_results(qd)
  expect_false(result$runs_signal)
})

test_that("special_cause_points matcher runs.signal-kolonnen", {
  sig <- c(FALSE, TRUE, TRUE, FALSE, FALSE)
  qd <- make_qic_data(n = 5, runs_signal = sig)
  result <- derive_anhoej_results(qd)
  expect_equal(result$special_cause_points, sig)
})

test_that("special_cause_points er logical(0) naar runs.signal mangler", {
  qd <- make_qic_data()
  qd$runs.signal <- NULL
  result <- derive_anhoej_results(qd)
  expect_equal(result$special_cause_points, logical(0))
})

# ==============================================================================
# 3. Crossings-signal
# ==============================================================================

test_that("crossings_signal er TRUE naar n_crossings < n_crossings_min", {
  # 5 kryds men minimum er 8 → signal
  qd <- make_qic_data(n_crossings = 5, n_crossings_min = 8)
  result <- derive_anhoej_results(qd)
  expect_true(result$crossings_signal)
})

test_that("crossings_signal er FALSE naar n_crossings >= n_crossings_min", {
  # 10 kryds, minimum er 8 → ingen signal
  qd <- make_qic_data(n_crossings = 10, n_crossings_min = 8)
  result <- derive_anhoej_results(qd)
  expect_false(result$crossings_signal)
})

test_that("crossings_signal er FALSE naar kolonnerne mangler", {
  qd <- make_qic_data()
  qd$n.crossings <- NULL
  qd$n.crossings.min <- NULL
  result <- derive_anhoej_results(qd)
  expect_false(result$crossings_signal)
})

test_that("crossings_signal er FALSE naar n_crossings er NA", {
  qd <- make_qic_data(n_crossings = NA_real_, n_crossings_min = 8)
  result <- derive_anhoej_results(qd)
  expect_false(result$crossings_signal)
})

test_that("n_crossings og n_crossings_min returneres korrekt", {
  qd <- make_qic_data(n_crossings = 7, n_crossings_min = 9)
  result <- derive_anhoej_results(qd)
  expect_equal(result$n_crossings, 7)
  expect_equal(result$n_crossings_min, 9)
})

test_that("n_crossings er NA_real_ naar kolonnen mangler", {
  qd <- make_qic_data()
  qd$n.crossings <- NULL
  result <- derive_anhoej_results(qd)
  expect_equal(result$n_crossings, NA_real_)
})

# ==============================================================================
# 4. Kombineret anhoej_signal
# ==============================================================================

test_that("anhoej_signal er FALSE naar baade runs og crossings er FALSE", {
  qd <- make_qic_data(runs_signal = rep(FALSE, 20), n_crossings = 10, n_crossings_min = 8)
  result <- derive_anhoej_results(qd)
  expect_false(result$anhoej_signal)
})

test_that("anhoej_signal er TRUE naar kun runs_signal er TRUE", {
  # #468: runs_signal udløses nu af longest.run > longest.run.max
  qd <- make_qic_data(
    longest_run = 12, longest_run_max = 8,
    n_crossings = 10, n_crossings_min = 8
  )
  result <- derive_anhoej_results(qd)
  expect_true(result$runs_signal)
  expect_false(result$crossings_signal)
  expect_true(result$anhoej_signal)
})

test_that("anhoej_signal er TRUE naar kun crossings_signal er TRUE", {
  qd <- make_qic_data(
    longest_run = 3, longest_run_max = 8,
    n_crossings = 3, n_crossings_min = 8
  )
  result <- derive_anhoej_results(qd)
  expect_false(result$runs_signal)
  expect_true(result$crossings_signal)
  expect_true(result$anhoej_signal)
})

test_that("anhoej_signal er TRUE naar baade runs OG crossings er TRUE", {
  qd <- make_qic_data(
    longest_run = 12, longest_run_max = 8,
    n_crossings = 3, n_crossings_min = 8
  )
  result <- derive_anhoej_results(qd)
  expect_true(result$runs_signal)
  expect_true(result$crossings_signal)
  expect_true(result$anhoej_signal)
})

# ==============================================================================
# 5. longest_run og longest_run_max
# ==============================================================================

test_that("longest_run returneres korrekt", {
  qd <- make_qic_data(longest_run = 5, longest_run_max = 8)
  result <- derive_anhoej_results(qd)
  expect_equal(result$longest_run, 5)
  expect_equal(result$longest_run_max, 8)
})

test_that("longest_run er NA_real_ naar kolonnen mangler", {
  qd <- make_qic_data(include_optional = FALSE)
  result <- derive_anhoej_results(qd)
  expect_equal(result$longest_run, NA_real_)
  expect_equal(result$longest_run_max, NA_real_)
})

test_that("longest_run er NA_real_ ved alt-NA-kolonne", {
  qd <- make_qic_data(n = 5)
  qd$longest.run <- rep(NA_real_, 5)
  result <- derive_anhoej_results(qd)
  expect_equal(result$longest_run, NA_real_)
})

# ==============================================================================
# 6. Edge cases: tom/NULL input
# ==============================================================================

test_that("derive_anhoej_results stopper ved NULL input", {
  expect_error(derive_anhoej_results(NULL))
})

test_that("derive_anhoej_results stopper ved ikke-data.frame", {
  expect_error(derive_anhoej_results(list(a = 1)))
})

test_that("tom data.frame returnerer sikre defaults", {
  qd_empty <- make_qic_data(n = 5)[0, ] # nul raekker
  result <- derive_anhoej_results(qd_empty)

  expect_false(result$runs_signal)
  expect_false(result$crossings_signal)
  expect_false(result$anhoej_signal)
  expect_equal(result$longest_run, NA_real_)
  expect_equal(result$n_crossings, NA_real_)
  expect_equal(result$special_cause_points, logical(0))
  expect_equal(result$data_points_used, 0L)
})

test_that("1-punkts datasaet haandteres uden fejl", {
  qd <- make_qic_data(n = 1, runs_signal = FALSE)
  expect_no_error(derive_anhoej_results(qd))
})

test_that("alle-NA runs.signal returnerer runs_signal = FALSE", {
  qd <- make_qic_data(n = 10, runs_signal = rep(NA, 10))
  result <- derive_anhoej_results(qd)
  expect_false(result$runs_signal)
})

# ==============================================================================
# 7. show_phases = TRUE
# ==============================================================================

test_that("show_phases = FALSE bruger hele datasaettet", {
  qd <- make_qic_data(n = 30)
  result <- derive_anhoej_results(qd, show_phases = FALSE)
  expect_equal(result$data_points_used, 30L)
})

test_that("show_phases = TRUE filtrerer til seneste part", {
  # Part 1: 20 punkter, part 2: 10 punkter
  qd <- make_qic_data(n = 30)
  qd$part <- c(rep(1L, 20), rep(2L, 10))
  result <- derive_anhoej_results(qd, show_phases = TRUE)
  expect_equal(result$data_points_used, 10L)
})

test_that("show_phases = TRUE: runs_signal baseres paa seneste part", {
  # #468: runs_signal afhaenger nu af longest.run > longest.run.max per fase
  qd <- make_qic_data(n = 30)
  qd$part <- c(rep(1L, 20), rep(2L, 10))
  # Part 1: lang run (12 > 8 max) -> runs-violation
  # Part 2: kort run (3 <= 8) -> ingen runs-violation
  qd$longest.run <- c(rep(12L, 20), rep(3L, 10))
  qd$longest.run.max <- c(rep(8L, 20), rep(8L, 10))

  result_all <- derive_anhoej_results(qd, show_phases = FALSE)
  result_latest <- derive_anhoej_results(qd, show_phases = TRUE)

  expect_true(result_all$runs_signal,
    info = "safe_max(longest.run) over alle = 12 > 8 -> TRUE"
  )
  expect_false(result_latest$runs_signal,
    info = "Kun part 2: longest.run = 3 <= 8 -> FALSE"
  )
})

test_that("show_phases = TRUE: crossings_signal baseres paa seneste part", {
  qd <- make_qic_data(n = 30)
  qd$part <- c(rep(1L, 20), rep(2L, 10))
  # Part 1 signal (3 < 8), part 2 ingen signal (10 >= 8)
  qd$n.crossings <- c(rep(3, 20), rep(10, 10))
  qd$n.crossings.min <- 8

  result_all <- derive_anhoej_results(qd, show_phases = FALSE)
  result_latest <- derive_anhoej_results(qd, show_phases = TRUE)

  # safe_max over hele datasaettet: max(3,3,...,10,10,...) = 10 >= 8 → FALSE
  expect_false(result_all$crossings_signal)
  # Kun part 2: max(10,...) = 10 >= 8 → FALSE
  expect_false(result_latest$crossings_signal)
})

test_that("show_phases = TRUE: kryds-signal kun fra seneste part naar der er signal", {
  qd <- make_qic_data(n = 30)
  qd$part <- c(rep(1L, 20), rep(2L, 10))
  # Part 1 ingen signal (10 >= 8), part 2 signal (3 < 8)
  qd$n.crossings <- c(rep(10, 20), rep(3, 10))
  qd$n.crossings.min <- 8

  result_all <- derive_anhoej_results(qd, show_phases = FALSE)
  result_latest <- derive_anhoej_results(qd, show_phases = TRUE)

  # safe_max over alle = max(10,...,3,...) = 10 >= 8 → FALSE
  expect_false(result_all$crossings_signal)
  # Kun part 2: max(3,...) = 3 < 8 → TRUE
  expect_true(result_latest$crossings_signal)
})

test_that("show_phases = TRUE uden part-kolonne returnerer hele datasaettet", {
  qd <- make_qic_data(n = 20)
  qd$part <- NULL
  result <- derive_anhoej_results(qd, show_phases = TRUE)
  expect_equal(result$data_points_used, 20L)
})

# ==============================================================================
# 8. Regression mod qic-baseline fixtures
# ==============================================================================

test_that("p-anhoej baseline: runs_signal og crossings_signal korrekte", {
  qd <- load_fixture_qic_data("p", "anhoej")
  result <- derive_anhoej_results(qd)

  # Fra fixture metadata: runs_signal = TRUE, n_crossings = 11, n_crossings_min = 13
  expect_true(result$runs_signal)
  expect_true(result$crossings_signal)
  expect_true(result$anhoej_signal)
  expect_equal(result$n_crossings, 11)
  expect_equal(result$n_crossings_min, 13)
})

test_that("p-basic baseline: ingen Anhoej-signal forventes", {
  qd <- load_fixture_qic_data("p", "basic")
  result <- derive_anhoej_results(qd)

  # Basis-scenario: ikke designet til at trigge Anhoej
  # Vi verificerer blot at funktionen korer fejlfrit
  expect_type(result$runs_signal, "logical")
  expect_type(result$crossings_signal, "logical")
  expect_type(result$anhoej_signal, "logical")
  expect_true(result$data_points_used > 0L)
})

test_that("i-anhoej baseline: korrekte metrics", {
  qd <- load_fixture_qic_data("i", "anhoej")
  result <- derive_anhoej_results(qd)
  expect_type(result$runs_signal, "logical")
  expect_type(result$longest_run, "double")
  expect_true(result$data_points_used > 0L)
})

test_that("run-anhoej baseline: korrekte metrics for run-chart", {
  qd <- load_fixture_qic_data("run", "anhoej")
  result <- derive_anhoej_results(qd)
  expect_type(result$anhoej_signal, "logical")
  expect_true(result$data_points_used > 0L)
})

test_that("c-anhoej baseline: korrekte metrics", {
  qd <- load_fixture_qic_data("c", "anhoej")
  result <- derive_anhoej_results(qd)
  expect_type(result$anhoej_signal, "logical")
  expect_true(result$data_points_used > 0L)
})

test_that("u-anhoej baseline: korrekte metrics", {
  qd <- load_fixture_qic_data("u", "anhoej")
  result <- derive_anhoej_results(qd)
  expect_type(result$anhoej_signal, "logical")
  expect_true(result$data_points_used > 0L)
})

# ==============================================================================
# 9. Konsistens med eksisterende call-sites (regressions-kontrakt)
# ==============================================================================

test_that("derive_anhoej_results er konsistent med manuelt udregnet site-1-logik", {
  # #468: Anhoej-runs-regel kraever STRICT longest.run > longest.run.max
  # (ikke >=). Tidligere udgave af denne test brugte longest.run = 8,
  # longest.run.max = 8 og forventede runs_signal=TRUE — det var forkert
  # (boundary-case). Opdateret til at bruge longest.run = 10 (klar
  # runs-violation 10 > 8).
  n <- 24
  sig <- c(rep(FALSE, 16), rep(TRUE, 8))
  qd <- data.frame(
    runs.signal = sig,
    n.crossings = 7,
    n.crossings.min = 9,
    longest.run = 10,
    longest.run.max = 8,
    sigma.signal = rep(FALSE, n),
    part = rep(1L, n),
    y = seq_len(n),
    stringsAsFactors = FALSE
  )

  result <- derive_anhoej_results(qd, show_phases = FALSE)

  expect_true(result$runs_signal)
  expect_true(result$crossings_signal)
  expect_true(result$anhoej_signal)
  expect_equal(result$longest_run, 10)
  expect_equal(result$longest_run_max, 8)
  expect_equal(result$n_crossings, 7)
  expect_equal(result$n_crossings_min, 9)
  expect_equal(result$data_points_used, n)
})

test_that("derive_anhoej_results: boundary longest.run == max NOT runs_signal (#468)", {
  # Anhoej-runs-regel: signal kun ved STRICT longest.run > longest.run.max.
  # Boundary-case (8 == 8) skal IKKE udloese runs_signal.
  qd <- data.frame(
    runs.signal = rep(FALSE, 10),
    n.crossings = 5L,
    n.crossings.min = 3L,
    longest.run = 8L,
    longest.run.max = 8L,
    part = rep(1L, 10),
    y = seq_len(10)
  )

  result <- derive_anhoej_results(qd, show_phases = FALSE)

  expect_false(result$runs_signal,
    info = "8 == 8 er ikke runs-violation"
  )
  expect_false(result$crossings_signal,
    info = "5 > 3 er ikke crossings-violation"
  )
  expect_false(result$anhoej_signal)
})
