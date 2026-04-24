# Tests for utils_error_handling.R

# safe_operation() ------------------------------------------------------------

test_that("safe_operation returnerer resultat ved succes", {
  result <- safe_operation("test op", code = {
    42
  })
  expect_equal(result, 42)
})

test_that("safe_operation returnerer fallback ved fejl", {
  result <- safe_operation("test op", code = {
    stop("test error")
  }, fallback = "default")
  expect_equal(result, "default")
})

test_that("safe_operation returnerer NULL som default fallback", {
  result <- safe_operation("test op", code = {
    stop("test error")
  })
  expect_null(result)
})

test_that("safe_operation kalder fallback funktion med error", {
  result <- safe_operation("test op", code = {
    stop("specific error")
  }, fallback = function(e) {
    paste("caught:", e$message)
  })
  expect_equal(result, "caught: specific error")
})

test_that("safe_operation håndterer komplekse return values", {
  result <- safe_operation("test op", code = {
    list(a = 1, b = "hello", c = TRUE)
  })
  expect_equal(result$a, 1)
  expect_equal(result$b, "hello")
  expect_true(result$c)
})

test_that("safe_operation håndterer data frame return", {
  df <- data.frame(x = 1:3, y = 4:6)
  result <- safe_operation("test op", code = {
    df
  })
  expect_equal(result, df)
})

# validate_exists() -----------------------------------------------------------

test_that("validate_exists returnerer TRUE for eksisterende objekter", {
  test_var <- 42
  env <- environment()
  expect_true(validate_exists(test_var = env))
})

test_that("validate_exists fejler for manglende objekter", {
  env <- new.env(parent = emptyenv())
  expect_error(
    validate_exists(nonexistent_var = env),
    "missing: nonexistent_var"
  )
})

# safe_getenv() ---------------------------------------------------------------

test_that("safe_getenv returnerer character default", {
  result <- safe_getenv("NONEXISTENT_VAR_XYZ_123", default = "fallback")
  expect_equal(result, "fallback")
})

test_that("safe_getenv konverterer numerisk type", {
  withr::with_envvar(c("TEST_NUM" = "42"), {
    result <- safe_getenv("TEST_NUM", default = 0, type = "numeric")
    expect_equal(result, 42)
  })
})

test_that("safe_getenv konverterer logisk type", {
  withr::with_envvar(c("TEST_BOOL" = "TRUE"), {
    result <- safe_getenv("TEST_BOOL", default = FALSE, type = "logical")
    expect_true(result)
  })
})

test_that("safe_getenv returnerer default for tom numerisk var", {
  result <- safe_getenv("NONEXISTENT_XYZ", default = 100, type = "numeric")
  expect_equal(result, 100)
})

# spc_error_user_message() ----------------------------------------------------

test_that("spc_error_user_message giver dansk besked for spc_input_error", {
  e <- structure(
    class = c("spc_input_error", "spc_error", "error", "condition"),
    list(message = "Ugyldig chart_type: 'xyz'", call = NULL)
  )
  msg <- spc_error_user_message(e)
  expect_equal(msg, "Ugyldigt input: Ugyldig chart_type: 'xyz'")
})

test_that("spc_error_user_message giver dansk besked for spc_prepare_error", {
  e <- structure(
    class = c("spc_prepare_error", "spc_error", "error", "condition"),
    list(message = "For få rækker efter filtrering", call = NULL)
  )
  msg <- spc_error_user_message(e)
  expect_equal(msg, "Datafejl: For få rækker efter filtrering")
})

test_that("spc_error_user_message giver generisk besked for spc_render_error", {
  e <- structure(
    class = c("spc_render_error", "spc_error", "error", "condition"),
    list(message = "BFHcharts failed", call = NULL)
  )
  msg <- spc_error_user_message(e)
  expect_equal(msg, "Grafgenerering fejlede. Kontroller venligst dine data og indstillinger.")
})

test_that("spc_error_user_message giver generisk besked for ukendt fejlklasse", {
  e <- structure(
    class = c("error", "condition"),
    list(message = "uventet fejl", call = NULL)
  )
  msg <- spc_error_user_message(e)
  expect_equal(msg, "Grafgenerering fejlede. Kontroller venligst dine data og indstillinger.")
})

test_that("spc_error_user_message returnerer character scalar", {
  e <- structure(
    class = c("spc_input_error", "spc_error", "error", "condition"),
    list(message = "test", call = NULL)
  )
  msg <- spc_error_user_message(e)
  expect_type(msg, "character")
  expect_length(msg, 1L)
})
