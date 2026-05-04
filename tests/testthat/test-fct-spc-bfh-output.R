# Unit tests for fct_spc_bfh_output.R::transform_bfh_output()
# (M1 / #455). Filen var tidligere uden direkte tests trods at den
# sidder i facade-trin 4 (output-standardisering) — fejl her giver
# silent broken plot.

# Helper: byg minimum bfh_result der består duck-type-validering
# (list med plot + qic_data + required cols x, y, cl).
make_bfh_result <- function(qic_data = NULL, plot = NULL) {
  if (is.null(qic_data)) {
    qic_data <- data.frame(
      x = 1:5,
      y = c(10, 12, 11, 13, 14),
      cl = rep(12, 5),
      ucl = rep(15, 5),
      lcl = rep(9, 5)
    )
  }
  # Tilføj Anhøj-kolonner hvis ej supplied (#468 BFHcharts 0.15.0 kontrakt:
  # derive_anhoej_per_part() kræver runs.signal, n.crossings, n.crossings.min).
  # Brug NA-defaults så tests ikke utilsigtet trigger Anhøj-warning.
  for (col in c("runs.signal", "n.crossings", "n.crossings.min")) {
    if (!col %in% names(qic_data)) {
      qic_data[[col]] <- if (col == "runs.signal") FALSE else NA_real_
    }
  }
  if (is.null(plot)) {
    # Brug minimal ggplot for at undgå BFHcharts-dep i unit-test
    plot <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
      ggplot2::geom_line()
  }
  list(plot = plot, qic_data = qic_data)
}

test_that("transform_bfh_output: gyldigt input returnerer alle 4 keys", {
  result <- transform_bfh_output(make_bfh_result())

  expect_false(is.null(result))
  expect_named(result, c("plot", "qic_data", "metadata", "bfh_qic_result"),
    ignore.order = TRUE
  )
  expect_s3_class(result$plot, "ggplot")
  expect_s3_class(result$qic_data, "tbl_df")
})

test_that("transform_bfh_output: NULL input returnerer NULL via safe_operation fallback", {
  result <- transform_bfh_output(NULL)
  expect_null(result)
})

test_that("transform_bfh_output: ikke-list input returnerer NULL", {
  result <- transform_bfh_output("not a list")
  expect_null(result)
})

test_that("transform_bfh_output: manglende required cols (x, y, cl) returnerer NULL", {
  bad_data <- data.frame(x = 1:3, y = 4:6) # mangler cl
  result <- transform_bfh_output(make_bfh_result(qic_data = bad_data))
  expect_null(result)
})

test_that("transform_bfh_output: multiply skalerer y/cl/ucl/lcl korrekt", {
  result <- transform_bfh_output(make_bfh_result(), multiply = 100)

  expect_equal(result$qic_data$y, c(1000, 1200, 1100, 1300, 1400))
  expect_equal(result$qic_data$cl, rep(1200, 5))
  expect_equal(result$qic_data$ucl, rep(1500, 5))
  expect_equal(result$qic_data$lcl, rep(900, 5))
})

test_that("transform_bfh_output: manglende ucl/lcl udfyldes med NA", {
  qic_data <- data.frame(x = 1:3, y = c(10, 11, 12), cl = rep(11, 3))
  result <- transform_bfh_output(make_bfh_result(qic_data = qic_data))

  expect_true("ucl" %in% names(result$qic_data))
  expect_true("lcl" %in% names(result$qic_data))
  expect_true(all(is.na(result$qic_data$ucl)))
  expect_true(all(is.na(result$qic_data$lcl)))
})

test_that("transform_bfh_output: eksisterende anhoej.signal videresendes til signal-kolonne", {
  qic_data <- data.frame(
    x = 1:5,
    y = c(10, 12, 11, 13, 14),
    cl = rep(12, 5),
    anhoej.signal = c(FALSE, FALSE, TRUE, FALSE, TRUE)
  )
  result <- transform_bfh_output(make_bfh_result(qic_data = qic_data))

  expect_equal(result$qic_data$signal, c(FALSE, FALSE, TRUE, FALSE, TRUE))
})

test_that("transform_bfh_output: manglende part-kolonne defaulter til factor(rep(1, n))", {
  result <- transform_bfh_output(make_bfh_result())

  expect_true("part" %in% names(result$qic_data))
  expect_s3_class(result$qic_data$part, "factor")
  expect_equal(as.integer(as.character(result$qic_data$part)), rep(1L, 5))
})

test_that("transform_bfh_output: metadata indeholder n_points + n_phases + chart_type", {
  result <- transform_bfh_output(
    make_bfh_result(),
    chart_type = "i",
    multiply = 1,
    freeze_applied = TRUE
  )

  expect_equal(result$metadata$n_points, 5L)
  expect_equal(result$metadata$n_phases, 1L)
  expect_equal(result$metadata$chart_type, "i")
  expect_true(result$metadata$freeze_applied)
})

test_that("transform_bfh_output: metadata$signals_detected tæller pr part", {
  qic_data <- data.frame(
    x = 1:6,
    y = c(10, 11, 12, 13, 14, 15),
    cl = rep(12, 6),
    part = factor(c(1, 1, 1, 2, 2, 2)),
    anhoej.signal = c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE)
  )
  result <- transform_bfh_output(make_bfh_result(qic_data = qic_data))

  # Part 1 har signal (én af tre), part 2 har ej -> samlet signals_detected = 1
  expect_equal(result$metadata$signals_detected, 1L)
  expect_equal(result$metadata$n_phases, 2L)
})

test_that("transform_bfh_output: bfh_qic_result feltet indeholder full original input", {
  bfh_input <- make_bfh_result()
  result <- transform_bfh_output(bfh_input)

  # bfh_qic_result skal være den fulde original-input til export-funktioner
  expect_identical(result$bfh_qic_result, bfh_input)
})
