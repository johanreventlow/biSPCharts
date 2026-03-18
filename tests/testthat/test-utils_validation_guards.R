# Tests for utils_validation_guards.R

# validate_data_or_return() ---------------------------------------------------

test_that("validate_data_or_return returnerer data for valid data frames", {
  df <- data.frame(x = 1:5, y = 6:10)
  result <- validate_data_or_return(df)
  expect_equal(result, df)
})

test_that("validate_data_or_return returnerer fallback for NULL", {
  expect_null(validate_data_or_return(NULL))
  expect_equal(validate_data_or_return(NULL, fallback = data.frame()), data.frame())
})

test_that("validate_data_or_return returnerer fallback for non-data.frame", {
  expect_null(validate_data_or_return(list(a = 1)))
  expect_null(validate_data_or_return("text"))
  expect_null(validate_data_or_return(42))
})

test_that("validate_data_or_return tjekker minimum rows og cols", {
  df <- data.frame(x = 1:3)

  # Bestå: nok rækker

  expect_equal(validate_data_or_return(df, min_rows = 3), df)
  # Fejl: for få rækker
  expect_null(validate_data_or_return(df, min_rows = 5))
  # Fejl: for få kolonner
  expect_null(validate_data_or_return(df, min_cols = 2))
})

test_that("validate_data_or_return håndterer tom data frame", {
  empty_df <- data.frame(x = numeric(0))
  expect_null(validate_data_or_return(empty_df, min_rows = 1))
})

# value_or_default() ----------------------------------------------------------

test_that("value_or_default returnerer value når valid", {
  expect_equal(value_or_default("hello"), "hello")
  expect_equal(value_or_default(42), 42)
  expect_equal(value_or_default(TRUE), TRUE)
})

test_that("value_or_default returnerer default for NULL", {
  expect_equal(value_or_default(NULL, default = "fallback"), "fallback")
  expect_equal(value_or_default(NULL, default = 0), 0)
})

test_that("value_or_default returnerer default for tom streng", {
  expect_equal(value_or_default("", default = "fallback"), "fallback")
  expect_equal(value_or_default("  ", default = "fallback"), "fallback")
})

test_that("value_or_default returnerer default for tom vektor", {
  expect_equal(value_or_default(character(0), default = "x"), "x")
})

test_that("value_or_default validerer type", {
  expect_equal(value_or_default("hello", allowed_types = "character"), "hello")
  expect_equal(value_or_default("hello", default = 0, allowed_types = "numeric"), 0)
  expect_equal(value_or_default(42, default = "x", allowed_types = "character"), "x")
})

# validate_column_exists() ----------------------------------------------------

test_that("validate_column_exists returnerer TRUE for eksisterende kolonne", {
  df <- data.frame(Dato = 1:3, Værdi = 4:6)
  expect_true(validate_column_exists(df, "Dato"))
  expect_true(validate_column_exists(df, "Værdi"))
})

test_that("validate_column_exists returnerer FALSE for manglende kolonne", {
  df <- data.frame(x = 1:3)
  expect_false(validate_column_exists(df, "nonexistent"))
})

test_that("validate_column_exists returnerer kolonne data med return_column", {
  df <- data.frame(x = 1:3, y = 4:6)
  result <- validate_column_exists(df, "x", return_column = TRUE)
  expect_equal(result, 1:3)
})

test_that("validate_column_exists returnerer fallback for manglende kolonne med return_column", {
  df <- data.frame(x = 1:3)
  result <- validate_column_exists(df, "missing", return_column = TRUE, fallback = numeric(0))
  expect_equal(result, numeric(0))
})

test_that("validate_column_exists håndterer NULL input", {
  expect_false(validate_column_exists(NULL, "x"))
  expect_false(validate_column_exists(data.frame(), NULL))
})

test_that("validate_column_exists håndterer tom streng som kolonne navn", {
  df <- data.frame(x = 1:3)
  expect_false(validate_column_exists(df, ""))
  expect_false(validate_column_exists(df, "  "))
})

# validate_function_exists() --------------------------------------------------

test_that("validate_function_exists finder eksisterende funktioner", {
  expect_true(validate_function_exists("mean"))
  expect_true(validate_function_exists("sum"))
})

test_that("validate_function_exists returnerer FALSE for manglende", {
  expect_false(validate_function_exists("this_function_does_not_exist_xyz"))
})

test_that("validate_function_exists håndterer ugyldig input", {
  expect_false(validate_function_exists(NULL))
  expect_false(validate_function_exists(""))
  expect_false(validate_function_exists("  "))
})

# validate_config_value() -----------------------------------------------------

test_that("validate_config_value ekstraherer værdier fra list", {
  config <- list(x_col = "Dato", y_col = "Værdi")
  expect_equal(validate_config_value(config, "x_col"), "Dato")
  expect_equal(validate_config_value(config, "y_col"), "Værdi")
})

test_that("validate_config_value returnerer default for manglende felt", {
  config <- list(x_col = "Dato")
  expect_equal(validate_config_value(config, "missing", default = "fallback"), "fallback")
})

test_that("validate_config_value returnerer default for NULL config", {
  expect_equal(validate_config_value(NULL, "field", default = "x"), "x")
})

test_that("validate_config_value behandler tom streng som ugyldig", {
  config <- list(field = "")
  expect_equal(validate_config_value(config, "field", default = "x"), "x")
  # Med allow_empty = TRUE
  expect_equal(validate_config_value(config, "field", default = "x", allow_empty = TRUE), "")
})

test_that("validate_config_value virker med environments", {
  env <- new.env(parent = emptyenv())
  env$key <- "value"
  expect_equal(validate_config_value(env, "key"), "value")
  expect_equal(validate_config_value(env, "missing", default = "x"), "x")
})

# validate_state_transition() -------------------------------------------------

test_that("validate_state_transition returnerer valid for alle checks bestået", {
  result <- validate_state_transition(
    app_state = list(),
    checks = list(check1 = TRUE, check2 = TRUE),
    operation_name = "test"
  )
  expect_true(result$valid)
  expect_length(result$failed_checks, 0)
})

test_that("validate_state_transition rapporterer fejlede checks", {
  result <- validate_state_transition(
    app_state = list(),
    checks = list(check1 = TRUE, check2 = FALSE, check3 = TRUE),
    operation_name = "test"
  )
  expect_false(result$valid)
  expect_equal(result$failed_checks, "check2")
})

test_that("validate_state_transition med allow_proceed=TRUE giver valid=TRUE trods fejl", {
  result <- validate_state_transition(
    app_state = list(),
    checks = list(check1 = FALSE),
    operation_name = "test",
    allow_proceed = TRUE
  )
  expect_true(result$valid)
  expect_length(result$failed_checks, 1)
})
