# test-autodetect-x-col-not-denominator.R
#
# Regression: numerisk x-kolonne (fx "Uge" = 1..36) blev valgt som naevner,
# fordi n_candidates kun ekskluderede y_col. Resultat: run chart plottede
# antal/Uge og auto-satte y-enhed til "percent" i stedet for raa taeller.

make_uge_data <- function(uge) {
  data.frame(
    Uge = uge,
    antal = c(
      0, 11.11, 37.5, 40, 14.29, 50, 20, 42.86, 0, 14.29, 20, 25,
      16.67, 11.11, 18.18, 12.5, 12.5, 11.11, 37.5, 16.67, 11.11, 0, 0, 16.67,
      0, 57.14, 100, 50, 20, 12.5, 18.18, 33.33, 35.71, 0, 33.33, 0
    ),
    stringsAsFactors = FALSE
  )
}

test_that("detect_columns_full_analysis vaelger ikke x-kolonnen som naevner", {
  skip_if_not(exists("detect_columns_full_analysis", mode = "function"))

  for (uge in list(1:36, as.character(1:36))) {
    results <- detect_columns_full_analysis(make_uge_data(uge))
    expect_equal(results$x_col, "Uge")
    expect_equal(results$y_col, "antal")
    expect_null(results$n_col,
      info = paste("Uge (", class(uge), ") maa ikke blive naevner")
    )
  }
})

test_that("detect_columns_full_analysis bevarer aegte naevner ved siden af numerisk x", {
  skip_if_not(exists("detect_columns_full_analysis", mode = "function"))

  data <- make_uge_data(1:36)
  data$Naevner <- rep(120, 36)
  results <- detect_columns_full_analysis(data)
  expect_equal(results$x_col, "Uge")
  expect_equal(results$y_col, "antal")
  expect_equal(results$n_col, "Naevner")
})
