# test-auto-detection.R
# Tests af auto-detection produktionskode i fct_autodetect_unified.R og fct_autodetect_helpers.R
# Alle tests kalder faktiske eksporterede funktioner (ikke lokale re-implementeringer)

test_that("detect_date_columns_robust finder Date-objekter", {
  test_data <- data.frame(
    ID = 1:5,
    Dato = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01", "2024-05-01")),
    Tæller = c(90, 85, 92, 88, 94),
    stringsAsFactors = FALSE
  )

  result <- detect_date_columns_robust(test_data)

  # Resultatet er en named list med kolonne-navne som keys
  # Dato-kolonnen skal identificeres (har en entry i resultatet)
  expect_true("Dato" %in% names(result))
  # ID og Tæller er ikke datoer
  expect_false("ID" %in% names(result))
  expect_false("Tæller" %in% names(result))
})

test_that("find_numeric_columns identificerer numeriske kolonner", {
  test_data <- data.frame(
    Navn = c("A", "B", "C"),
    Tæller = c(90, 85, 92),
    Nævner = c(100, 95, 100),
    Rate = c(0.9, 0.89, 0.92),
    stringsAsFactors = FALSE
  )

  result <- find_numeric_columns(test_data)

  # Numeriske kolonner skal findes
  expect_true("Tæller" %in% result)
  expect_true("Nævner" %in% result)
  expect_true("Rate" %in% result)
  # Tekst-kolonne skal ikke
  expect_false("Navn" %in% result)
})

test_that("detect_columns_name_based finder danske kolonne navne", {
  col_names <- c("Dato", "Tæller", "Nævner", "Kommentar", "Skift", "Frys", "ID")

  result <- detect_columns_name_based(col_names)

  # Dato-kolonne
  expect_equal(result$x_col, "Dato")
  # Tæller/Nævner
  expect_equal(result$y_col, "Tæller")
  expect_equal(result$n_col, "Nævner")
  # Kommentar
  expect_equal(result$kommentar_col, "Kommentar")
})

test_that("detect_columns_name_based håndterer tomme input", {
  result <- detect_columns_name_based(character(0))

  expect_null(result$x_col)
  expect_null(result$y_col)
  expect_null(result$n_col)
})

test_that("score_by_name_patterns giver højere score til x-relevante navne", {
  # Dato-lignende navne bør score højt for x_column rolle
  dato_score <- score_by_name_patterns("Dato", role = "x_column")
  id_score <- score_by_name_patterns("ID", role = "x_column")

  expect_gt(dato_score, id_score)
})

test_that("score_by_name_patterns giver højere score til y-relevante navne", {
  tæller_score <- score_by_name_patterns("Tæller", role = "y_column")
  random_score <- score_by_name_patterns("RandomCol", role = "y_column")

  expect_gt(tæller_score, random_score)
})
