# test-data-signature-collision.R
# Regression-tests for hash-kollision-prevention i generate_shared_data_signature()
#
# Issue #494: Sampling-baseret cache-key (first/middle/last row) gav kollisioner
# for datasæt med identiske endepunkter men forskelle i anden række.
# Fix: drop sampling-cache; beregn altid full xxhash64-digest.

# --- Præcis repro fra Issue #494 ---

test_that("sampling-collision repro (#494): data med forskel kun i række 2 giver forskellig signatur", {
  # Datasæt der tidligere kolliderede: identiske first/middle/last rows,
  # forskel i række 2 — udenfor 3-row-sampling med n=10 (mid=5, rows 1,5,10).
  data1 <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = 1:10,
    Kommentar = c("a", rep(NA, 9))
  )
  data2 <- data1
  data2$Kommentar <- c("a", "b", rep(NA, 8)) # forskel kun ved row 2

  sig1 <- generate_shared_data_signature(data1, include_structure = FALSE)
  sig2 <- generate_shared_data_signature(data2, include_structure = FALSE)

  expect_false(
    identical(sig1, sig2),
    info = "Datasæt der kun adskiller sig i række 2 skal give forskellig signatur (Issue #494)"
  )
})

test_that("sampling-collision repro (#494): include_structure = TRUE giver også forskellig signatur", {
  data1 <- data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = 1:10,
    Kommentar = c("a", rep(NA, 9))
  )
  data2 <- data1
  data2$Kommentar <- c("a", "b", rep(NA, 8))

  sig1 <- generate_shared_data_signature(data1, include_structure = TRUE)
  sig2 <- generate_shared_data_signature(data2, include_structure = TRUE)

  expect_false(
    identical(sig1, sig2),
    info = "include_structure = TRUE skal også detektere forskel i række 2 (#494)"
  )
})

# --- Eksisterende kollisions-tests ---

test_that("generate_shared_data_signature detekterer ændring i midterste rækker", {
  # Datasæt med 7 rækker — ændring i række 4 (midten)
  data_original <- data.frame(
    x = 1:7,
    y = c(10, 20, 30, 40, 50, 60, 70)
  )
  data_mutated <- data_original
  data_mutated$y[4] <- 999 # Ændr midterste række

  sig1 <- generate_shared_data_signature(data_original)
  sig2 <- generate_shared_data_signature(data_mutated)

  expect_false(
    identical(sig1, sig2),
    info = "Ændring i midterste række skal give forskellig signatur"
  )
})

test_that("generate_shared_data_signature er stabil for identiske data", {
  data <- data.frame(
    x = 1:10,
    y = c(5, 10, 15, 20, 25, 30, 35, 40, 45, 50)
  )

  sig1 <- generate_shared_data_signature(data)
  sig2 <- generate_shared_data_signature(data)

  expect_identical(sig1, sig2)
})

test_that("generate_shared_data_signature detekterer ændring i første række", {
  data_orig <- data.frame(x = 1:5, y = c(1, 2, 3, 4, 5))
  data_mut <- data_orig
  data_mut$y[1] <- 999

  sig1 <- generate_shared_data_signature(data_orig)
  sig2 <- generate_shared_data_signature(data_mut)

  expect_false(identical(sig1, sig2))
})

test_that("generate_shared_data_signature detekterer ændring i sidste række", {
  data_orig <- data.frame(x = 1:5, y = c(1, 2, 3, 4, 5))
  data_mut <- data_orig
  data_mut$y[5] <- 999

  sig1 <- generate_shared_data_signature(data_orig)
  sig2 <- generate_shared_data_signature(data_mut)

  expect_false(identical(sig1, sig2))
})

test_that("generate_shared_data_signature er konsistent med large dataset", {
  set.seed(42)
  large_data <- data.frame(
    x = 1:100,
    y = rnorm(100)
  )

  sig1 <- generate_shared_data_signature(large_data)
  sig2 <- generate_shared_data_signature(large_data)

  expect_identical(sig1, sig2)
})

test_that("generate_shared_data_signature detekterer ændring i én af mange midterrækker", {
  withr::with_seed(42, {
    data_orig <- data.frame(
      x  = 1:20,
      y1 = rnorm(20, mean = 50),
      y2 = rnorm(20, mean = 100)
    )
  })
  data_mut <- data_orig
  # Ændr række 10 (midten af 20-rækkers datasæt)
  data_mut$y1[10] <- -9999

  sig1 <- generate_shared_data_signature(data_orig, include_structure = FALSE)
  sig2 <- generate_shared_data_signature(data_mut, include_structure = FALSE)

  expect_false(identical(sig1, sig2))
})
