# test-fct_autodetect_pure.R
# Unit-tests for run_autodetect() og AutodetectResult S3-struktur
# Ingen Shiny-session kræves

# Tests: run_autodetect() med data ------------------------------------------

test_that("run_autodetect returnerer AutodetectResult for data med kendte kolonner", {
  data <- data.frame(
    Dato   = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")),
    Vaerdi = c(10, 20, 15),
    N      = c(100, 200, 150)
  )

  result <- run_autodetect(data)

  expect_s3_class(result, "AutodetectResult")
  expect_named(
    result,
    c("x_col", "y_col", "n_col", "skift_col", "frys_col", "kommentar_col", "scores", "timestamp"),
    ignore.order = TRUE
  )
})

test_that("run_autodetect finder Dato-kolonne som x_col", {
  data <- data.frame(
    Dato   = as.Date(c("2024-01-01", "2024-02-01")),
    Vaerdi = c(10, 20)
  )

  result <- run_autodetect(data)

  # Dato-kolonnen bør detekteres (allerede Date-klasse)
  expect_equal(result$x_col, "Dato")
})

test_that("run_autodetect returnerer NULL-felter for tom data.frame", {
  data <- data.frame()

  result <- run_autodetect(data)

  expect_s3_class(result, "AutodetectResult")
  expect_null(result$x_col)
  expect_null(result$y_col)
})

test_that("run_autodetect fungerer med NULL data (navn-baseret)", {
  result <- run_autodetect(
    data  = NULL,
    hints = list(col_names = c("Dato", "Vaerdi", "N"))
  )

  expect_s3_class(result, "AutodetectResult")
  # Dato-mønster bør detekteres
  expect_equal(result$x_col, "Dato")
})

test_that("run_autodetect fungerer med hints$prefer_name_based = TRUE", {
  data <- data.frame(
    Dato   = c("2024-01-01", "2024-02-01"),
    Vaerdi = c(10, 20)
  )

  result <- run_autodetect(data, hints = list(prefer_name_based = TRUE))

  expect_s3_class(result, "AutodetectResult")
  expect_equal(result$x_col, "Dato")
})

test_that("run_autodetect har timestamp tæt på Sys.time()", {
  data <- data.frame(x = 1:5, y = 1:5)
  before <- Sys.time()
  result <- run_autodetect(data)
  after <- Sys.time()

  expect_true(result$timestamp >= before)
  expect_true(result$timestamp <= after)
})

# Tests: edge cases ---------------------------------------------------------

test_that("run_autodetect finder ikke Skift/Frys i standard SPC-data", {
  data <- data.frame(
    Dato   = as.Date(c("2024-01-01", "2024-02-01")),
    Vaerdi = c(10, 20)
  )

  result <- run_autodetect(data)

  expect_null(result$skift_col)
  expect_null(result$frys_col)
})

test_that("run_autodetect finder Skift-kolonne ved matchende navn", {
  data <- data.frame(
    Dato   = as.Date(c("2024-01-01", "2024-02-01")),
    Vaerdi = c(10, 20),
    Skift  = c(FALSE, TRUE)
  )

  result <- run_autodetect(
    data  = NULL,
    hints = list(col_names = c("Dato", "Vaerdi", "Skift"))
  )

  expect_equal(result$skift_col, "Skift")
})

# Tests: print-metode -------------------------------------------------------

test_that("print.AutodetectResult kører uden fejl", {
  result <- run_autodetect(
    data  = NULL,
    hints = list(col_names = c("Dato", "Vaerdi"))
  )
  expect_output(print(result), "AutodetectResult")
})

# Tests: new_autodetect_result konstruktør -----------------------------------

test_that("new_autodetect_result opretter korrekt S3-objekt", {
  raw <- list(
    x_col = "Dato", y_col = "Vaerdi", n_col = NULL,
    skift_col = NULL, frys_col = NULL, kommentar_col = NULL
  )
  result <- new_autodetect_result(raw)

  expect_s3_class(result, "AutodetectResult")
  expect_equal(result$x_col, "Dato")
  expect_equal(result$y_col, "Vaerdi")
  expect_null(result$n_col)
})
