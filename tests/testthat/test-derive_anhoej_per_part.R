# Tests for derive_anhoej_per_part()
# Pure funktion: per-part Anhoej-statistik over qic_data med flere parts.

test_that("derive_anhoej_per_part returnerer en liste med ét element per unik part", {
  qic_data <- data.frame(
    part = c(1L, 1L, 1L, 2L, 2L, 2L, 3L, 3L, 3L),
    y = c(1, 2, 3, 4, 5, 6, 7, 8, 9),
    runs.signal = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
    n.crossings = c(2, 2, 2, 2, 2, 2, 2, 2, 2),
    n.crossings.min = c(1, 1, 1, 1, 1, 1, 1, 1, 1),
    longest.run = c(3, 3, 3, 3, 3, 3, 3, 3, 3),
    longest.run.max = c(5, 5, 5, 5, 5, 5, 5, 5, 5)
  )
  result <- derive_anhoej_per_part(qic_data)
  expect_length(result, 3L)
  expect_equal(vapply(result, function(p) p$part, integer(1)), c(1L, 2L, 3L))
})

test_that("derive_anhoej_per_part beregner per-part Anhoej-metrics korrekt", {
  # Part 1: lang serie (runs_signal = TRUE)
  # Part 2: stabil
  # Part 3: for faa kryds (crossings_signal = TRUE)
  qic_data <- data.frame(
    part = c(1L, 1L, 1L, 1L, 2L, 2L, 2L, 2L, 3L, 3L, 3L, 3L),
    y = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12),
    runs.signal = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
    n.crossings = c(2, 2, 2, 2, 3, 3, 3, 3, 0, 0, 0, 0),
    n.crossings.min = c(1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2),
    longest.run = c(8, 8, 8, 8, 3, 3, 3, 3, 4, 4, 4, 4),
    longest.run.max = c(5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5)
  )
  result <- derive_anhoej_per_part(qic_data)
  expect_true(result[[1]]$runs_signal)
  expect_false(result[[1]]$crossings_signal)
  expect_false(result[[2]]$runs_signal)
  expect_false(result[[2]]$crossings_signal)
  expect_false(result[[3]]$runs_signal)
  expect_true(result[[3]]$crossings_signal)
})

test_that("derive_anhoej_per_part returnerer enkelt 'part 1' hvis part-kolonne mangler", {
  qic_data <- data.frame(
    y = c(1, 2, 3, 4, 5),
    runs.signal = c(FALSE, FALSE, FALSE, FALSE, FALSE),
    n.crossings = c(2, 2, 2, 2, 2),
    n.crossings.min = c(1, 1, 1, 1, 1),
    longest.run = c(2, 2, 2, 2, 2),
    longest.run.max = c(5, 5, 5, 5, 5)
  )
  result <- derive_anhoej_per_part(qic_data)
  expect_length(result, 1L)
  expect_equal(result[[1]]$part, 1L)
  expect_equal(result[[1]]$data_points_used, 5L)
})

test_that("derive_anhoej_per_part returnerer enkelt 'part 1' hvis part-kolonne kun har NA", {
  qic_data <- data.frame(
    part = c(NA_integer_, NA_integer_, NA_integer_),
    y = c(1, 2, 3),
    runs.signal = c(FALSE, FALSE, FALSE),
    n.crossings = c(2, 2, 2),
    n.crossings.min = c(1, 1, 1),
    longest.run = c(1, 1, 1),
    longest.run.max = c(5, 5, 5)
  )
  result <- derive_anhoej_per_part(qic_data)
  expect_length(result, 1L)
  expect_equal(result[[1]]$part, 1L)
})

test_that("derive_anhoej_per_part returnerer tom liste for tomt qic_data", {
  qic_data <- data.frame(
    part = integer(0),
    y = numeric(0),
    runs.signal = logical(0),
    n.crossings = numeric(0),
    n.crossings.min = numeric(0)
  )
  result <- derive_anhoej_per_part(qic_data)
  expect_equal(result, list())
})

test_that("derive_anhoej_per_part fejler ikke ved manglende valgfrie kolonner", {
  qic_data <- data.frame(
    part = c(1L, 1L, 2L, 2L),
    y = c(1, 2, 3, 4),
    runs.signal = c(FALSE, FALSE, FALSE, FALSE),
    n.crossings = c(2, 2, 2, 2),
    n.crossings.min = c(1, 1, 1, 1)
    # ingen longest.run / longest.run.max
  )
  result <- derive_anhoej_per_part(qic_data)
  expect_length(result, 2L)
  expect_true(is.na(result[[1]]$longest_run))
  expect_true(is.na(result[[1]]$longest_run_max))
})

test_that("derive_anhoej_per_part bevarer kontrakt fra derive_anhoej_results pr. part", {
  qic_data <- data.frame(
    part = c(1L, 1L, 2L, 2L),
    y = c(1, 2, 3, 4),
    runs.signal = c(TRUE, TRUE, FALSE, FALSE),
    n.crossings = c(0, 0, 2, 2),
    n.crossings.min = c(1, 1, 1, 1),
    longest.run = c(2, 2, 2, 2),
    longest.run.max = c(3, 3, 3, 3)
  )
  result <- derive_anhoej_per_part(qic_data)
  expected_fields <- c(
    "part", "runs_signal", "crossings_signal", "anhoej_signal",
    "longest_run", "longest_run_max", "n_crossings", "n_crossings_min",
    "special_cause_points", "data_points_used"
  )
  expect_setequal(names(result[[1]]), expected_fields)
})

test_that("derive_anhoej_per_part respekterer part-rækkefølgen i input-data", {
  # Parts kan være ude af numerisk orden (fx 3, 1, 2) — vi bevarer
  # observations-rækkefølge, ikke numerisk sortering.
  qic_data <- data.frame(
    part = c(3L, 3L, 1L, 1L, 2L, 2L),
    y = c(1, 2, 3, 4, 5, 6),
    runs.signal = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
    n.crossings = c(2, 2, 2, 2, 2, 2),
    n.crossings.min = c(1, 1, 1, 1, 1, 1)
  )
  result <- derive_anhoej_per_part(qic_data)
  expect_length(result, 3L)
  # Parts opstår i input-rækkefølge: 3, 1, 2
  expect_equal(vapply(result, function(p) p$part, integer(1)), c(3L, 1L, 2L))
})
