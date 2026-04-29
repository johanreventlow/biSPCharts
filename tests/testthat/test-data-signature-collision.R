# test-data-signature-collision.R
# Tests for hash-kollision-prevention i generate_shared_data_signature()
#
# Verificerer at middle-row-sample er inkluderet i data_ptr-nøglen,
# så ændringer midt i datasættet opdages korrekt.

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

test_that("generate_shared_data_signature er stabil for identiske data (inkl. middle-row)", {
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

test_that("generate_shared_data_signature er konsistent med large dataset og middle-row", {
  # 100 rækker — tilstrækkeligt til at test middle-row coverage
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
