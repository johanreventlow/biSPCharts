test_that("validate_spc_request returns spc_request on valid input", {
  df <- data.frame(
    dato = seq(as.Date("2023-01-01"), by = "week", length.out = 10),
    vaerdi = 1:10
  )
  req <- validate_spc_request(df, "dato", "vaerdi", "run")
  expect_s3_class(req, "spc_request")
  expect_equal(req$chart_type, "run")
  expect_equal(req$x_var, "dato")
  expect_equal(req$y_var, "vaerdi")
})

test_that("validate_spc_request normalizes chart_type to lowercase", {
  df <- data.frame(dato = as.Date("2023-01-01") + 0:9, vaerdi = 1:10)
  req <- validate_spc_request(df, "dato", "vaerdi", "RUN")
  expect_equal(req$chart_type, "run")
})

test_that("validate_spc_request kaster spc_input_error ved NULL data", {
  expect_error(
    validate_spc_request(NULL, "x", "y", "run"),
    class = "spc_input_error"
  )
})

test_that("validate_spc_request kaster spc_input_error ved ikke-data.frame", {
  expect_error(
    validate_spc_request(list(x = 1:10), "x", "y", "run"),
    class = "spc_input_error"
  )
})

test_that("validate_spc_request kaster spc_input_error ved manglende x_var", {
  df <- data.frame(x = 1:10, y = 1:10)
  expect_error(
    validate_spc_request(df, NULL, "y", "run"),
    class = "spc_input_error"
  )
  expect_error(
    validate_spc_request(df, "", "y", "run"),
    class = "spc_input_error"
  )
})

test_that("validate_spc_request kaster spc_input_error ved manglende y_var", {
  df <- data.frame(x = 1:10, y = 1:10)
  expect_error(
    validate_spc_request(df, "x", NULL, "run"),
    class = "spc_input_error"
  )
})

test_that("validate_spc_request kaster spc_input_error ved ugyldig chart_type", {
  df <- data.frame(x = 1:10, y = 1:10)
  expect_error(
    validate_spc_request(df, "x", "y", "banana"),
    class = "spc_input_error"
  )
  # Fejlbesked matcher eksisterende test-kontrakt
  expect_error(
    validate_spc_request(df, "x", "y", "banana"),
    "Must be one of"
  )
})

test_that("validate_spc_request kaster spc_input_error ved tom data.frame", {
  empty_df <- data.frame(x = numeric(0), y = numeric(0))
  expect_error(
    validate_spc_request(empty_df, "x", "y", "run"),
    class = "spc_input_error"
  )
})

test_that("validate_spc_request kaster spc_input_error ved for få rækker", {
  df <- data.frame(x = 1:2, y = 1:2)
  expect_error(
    validate_spc_request(df, "x", "y", "run"),
    class = "spc_input_error"
  )
})

test_that("validate_spc_request kaster spc_input_error når kolonne ikke eksisterer", {
  df <- data.frame(x = 1:10, y = 1:10)
  expect_error(
    validate_spc_request(df, "ikke_eksisterende", "y", "run"),
    class = "spc_input_error"
  )
  expect_error(
    validate_spc_request(df, "x", "ikke_eksisterende", "run"),
    class = "spc_input_error"
  )
})

test_that("validate_spc_request kaster spc_input_error ved alle-NA y-kolonne", {
  df <- data.frame(x = 1:10, y = rep(NA_real_, 10))
  expect_error(
    validate_spc_request(df, "x", "y", "run"),
    class = "spc_input_error"
  )
})

test_that("validate_spc_request kaster spc_input_error ved manglende n_var for p-kort", {
  df <- data.frame(dato = 1:10, tæller = 1:10)
  expect_error(
    validate_spc_request(df, "dato", "tæller", "p"),
    class = "spc_input_error"
  )
})

# 0-row pipeline (#588) =======================================================

test_that("compute_spc_results_bfh kaster spc_input_error ved 0 rækker", {
  empty_df <- data.frame(
    dato = as.Date(character(0)),
    vaerdi = numeric(0)
  )
  expect_error(
    compute_spc_results_bfh(empty_df, "dato", "vaerdi", "run"),
    class = "spc_input_error"
  )
})

test_that("compute_spc_results_bfh fejlbesked nævner 'tom' eller 'empty' ved 0 rækker", {
  empty_df <- data.frame(dato = as.Date(character(0)), vaerdi = numeric(0))
  err <- tryCatch(
    compute_spc_results_bfh(empty_df, "dato", "vaerdi", "run"),
    spc_input_error = function(e) e
  )
  expect_true(
    grepl("tom|empty|ingen|0", conditionMessage(err), ignore.case = TRUE),
    info = paste("Fejlbesked mangler 'tom'/'empty'/'ingen'/'0':", conditionMessage(err))
  )
})

test_that("validate_spc_request accepterer p-kort med n_var", {
  df <- data.frame(dato = 1:10, tæller = 1:10, naevner = rep(100L, 10))
  req <- validate_spc_request(df, "dato", "tæller", "p", n_var = "naevner")
  expect_s3_class(req, "spc_request")
  expect_equal(req$n_var, "naevner")
})

test_that("validate_spc_request kaster spc_input_error ved nul-nævner for p-kort", {
  df <- data.frame(dato = 1:10, tæller = 1:10, naevner = c(0L, rep(100L, 9)))
  expect_error(
    validate_spc_request(df, "dato", "tæller", "p", n_var = "naevner"),
    class = "spc_input_error"
  )
})

test_that("validate_spc_request gemmer options fra ...", {
  df <- data.frame(x = 1:10, y = 1:10)
  req <- validate_spc_request(df, "x", "y", "run", target_value = 5, y_axis_unit = "count")
  expect_equal(req$options$target_value, 5)
  expect_equal(req$options$y_axis_unit, "count")
})

test_that("validate_spc_request accepterer dansk talformat i y-kolonne", {
  df <- data.frame(x = 1:10, y = c(
    "1,5", "2,3", "3,1", "4,2", "5,0",
    "1,5", "2,3", "3,1", "4,2", "5,0"
  ))
  req <- validate_spc_request(df, "x", "y", "run")
  expect_s3_class(req, "spc_request")
})

test_that("validate_spc_request fejlbesked ved ugyldig chart_type arver fra spc_error", {
  df <- data.frame(x = 1:10, y = 1:10)
  err <- tryCatch(
    validate_spc_request(df, "x", "y", "invalid"),
    spc_error = function(e) e
  )
  expect_true(inherits(err, "spc_error"))
  expect_true(inherits(err, "spc_input_error"))
})

test_that("spc fejlklasser producerer korrekte UI-brugermeddelelser", {
  make_err <- function(msg, cls) {
    tryCatch(spc_abort(msg, class = cls), error = function(e) e)
  }
  classify_msg <- function(e) {
    if (inherits(e, "spc_input_error")) {
      paste("Ugyldigt input:", e$message)
    } else if (inherits(e, "spc_prepare_error")) {
      paste("Datafejl:", e$message)
    } else if (inherits(e, "spc_render_error")) {
      "Grafgenerering fejlede. Kontroller venligst dine data og indstillinger."
    } else {
      "Grafgenerering fejlede. Kontroller venligst dine data og indstillinger."
    }
  }
  expect_true(startsWith(classify_msg(make_err("kolonne mangler", "spc_input_error")), "Ugyldigt input:"))
  expect_true(startsWith(classify_msg(make_err("for få punkter", "spc_prepare_error")), "Datafejl:"))
  expect_match(classify_msg(make_err("rendering", "spc_render_error")), "Grafgenerering fejlede")
  expect_match(classify_msg(simpleError("ukendt")), "Grafgenerering fejlede")
})
