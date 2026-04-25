# test-try-with-diagnostics.R
# Tests for try_with_diagnostics() helper

test_that("try_with_diagnostics returnerer første succesfulde attempt", {
  result <- try_with_diagnostics(
    attempts = list(
      "første" = function() "succes"
    ),
    on_all_fail = function(errors) stop("Alle fejlede")
  )
  expect_equal(result, "succes")
})

test_that("try_with_diagnostics springer fejlende attempts over og returnerer tredje", {
  kald_order <- character(0)
  result <- try_with_diagnostics(
    attempts = list(
      "første" = function() stop("Fejl 1"),
      "anden" = function() stop("Fejl 2"),
      "tredje" = function() {
        kald_order <<- c(kald_order, "tredje")
        42L
      }
    ),
    on_all_fail = function(errors) stop("Alle fejlede")
  )
  expect_equal(result, 42L)
  expect_equal(kald_order, "tredje")
})

test_that("try_with_diagnostics kalder on_all_fail med alle fejlbeskeder ved total-fail", {
  captured_errors <- NULL
  try_with_diagnostics(
    attempts = list(
      "semikolon" = function() stop("Fejl semikolon"),
      "auto"      = function() stop("Fejl auto"),
      "komma"     = function() stop("Fejl komma")
    ),
    on_all_fail = function(errors) {
      captured_errors <<- errors
      invisible(NULL)
    }
  )
  expect_equal(length(captured_errors), 3)
  expect_equal(names(captured_errors), c("semikolon", "auto", "komma"))
  expect_equal(captured_errors[["semikolon"]], "Fejl semikolon")
  expect_equal(captured_errors[["komma"]], "Fejl komma")
})

test_that("try_with_diagnostics stopper på første succes og kører ikke resterende attempts", {
  calls <- character(0)
  try_with_diagnostics(
    attempts = list(
      "a" = function() {
        calls <<- c(calls, "a")
        "OK"
      },
      "b" = function() {
        calls <<- c(calls, "b")
        "OK"
      }
    ),
    on_all_fail = function(errors) stop("Alle fejlede")
  )
  expect_equal(calls, "a")
})
