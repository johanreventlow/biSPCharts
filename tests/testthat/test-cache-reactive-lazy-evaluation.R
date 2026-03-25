# Tests for Bug #3: create_cached_reactive Eager Evaluation
# Problem: reactive_expr is evaluated immediately when function is called,
# not when the returned reactive invalidates
#
# VIGTIGT: Brug IKKE testServer(expr = {...}) uden module server —
# det starter hele app_server og hænger. Brug i stedet en minimal
# module server function eller shiny::testServer() med mock module.

library(testthat)
library(shiny)

# Minimal module server til at teste reactive caching
mock_cache_server <- function(id = "test") {
  moduleServer(id, function(input, output, session) {
    # Returnerer session environment for test-adgang
    session$userData$test_env <- environment()
  })
}

# Bug #3: Eager evaluation prevents reactive invalidation ----

test_that("create_cached_reactive evaluates lazily, not eagerly", {
  skip_if_not(
    exists("create_cached_reactive"),
    "create_cached_reactive not available"
  )

  testServer(mock_cache_server, {
    counter <- reactiveVal(0)
    evaluation_count <- 0

    cached <- create_cached_reactive(
      reactive_expr = {
        evaluation_count <<- evaluation_count + 1
        counter() * 2
      },
      cache_key = "test_lazy",
      cache_timeout = 1
    )

    # Før adgang bør expression ikke være evalueret
    expect_equal(evaluation_count, 0,
      info = "Expression should not evaluate until reactive is accessed"
    )

    result1 <- cached()
    expect_equal(evaluation_count, 1,
      info = "Should evaluate when accessed"
    )
    expect_equal(result1, 0, info = "counter() is 0, so result is 0")

    counter(5)
    session$flushReact()

    result2 <- cached()
    expect_equal(evaluation_count, 2,
      info = "Should re-evaluate when dependency changes"
    )
    expect_equal(result2, 10, info = "counter() is 5, so result is 10")
  })
})

test_that("create_cached_reactive responds to reactive dependencies", {
  skip_if_not(
    exists("create_cached_reactive"),
    "create_cached_reactive not available"
  )

  testServer(mock_cache_server, {
    val1 <- reactiveVal(1)
    val2 <- reactiveVal(10)

    cached <- create_cached_reactive(
      reactive_expr = {
        val1() + val2()
      },
      cache_key = "test_deps",
      cache_timeout = 5
    )

    result1 <- cached()
    expect_equal(result1, 11)

    val1(5)
    session$flushReact()

    result2 <- cached()
    expect_equal(result2, 15, info = "Should reflect val1 change")

    val2(20)
    session$flushReact()

    result3 <- cached()
    expect_equal(result3, 25, info = "Should reflect val2 change")
  })
})

test_that("create_cached_reactive caches within timeout period", {
  skip_if_not(
    exists("create_cached_reactive"),
    "create_cached_reactive not available"
  )

  testServer(mock_cache_server, {
    counter <- reactiveVal(0)
    eval_count <- 0

    cached <- create_cached_reactive(
      reactive_expr = {
        eval_count <<- eval_count + 1
        counter() * 3
      },
      cache_key = "test_caching",
      cache_timeout = 10
    )

    result1 <- cached()
    expect_equal(eval_count, 1)
    expect_equal(result1, 0)

    # Cached adgang (ingen ændring)
    result2 <- cached()
    expect_equal(eval_count, 1, info = "Should use cached value")
    expect_equal(result2, 0)

    counter(7)
    session$flushReact()

    result3 <- cached()
    expect_equal(eval_count, 2, info = "Should recompute after invalidation")
    expect_equal(result3, 21)
  })
})

test_that("create_cached_reactive handles cache expiration", {
  skip_if_not(
    exists("create_cached_reactive"),
    "create_cached_reactive not available"
  )

  testServer(mock_cache_server, {
    counter <- reactiveVal(1)
    eval_count <- 0

    cached <- create_cached_reactive(
      reactive_expr = {
        eval_count <<- eval_count + 1
        counter() + 100
      },
      cache_key = "test_expiry",
      cache_timeout = 0.1
    )

    result1 <- cached()
    expect_equal(eval_count, 1)
    expect_equal(result1, 101)

    Sys.sleep(0.2)

    result2 <- cached()
    expect_equal(eval_count, 2, info = "Should recompute after cache expiry")
    expect_equal(result2, 101)
  })
})

test_that("create_cached_reactive works with complex reactive expressions", {
  skip_if_not(
    exists("create_cached_reactive"),
    "create_cached_reactive not available"
  )

  testServer(mock_cache_server, {
    data_val <- reactiveVal(data.frame(x = 1:5, y = 6:10))

    cached_processing <- create_cached_reactive(
      reactive_expr = {
        df <- data_val()
        df$z <- df$x + df$y
        sum(df$z)
      },
      cache_key = "complex_expr",
      cache_timeout = 5
    )

    result1 <- cached_processing()
    expect_equal(result1, sum(c(7, 9, 11, 13, 15)))

    data_val(data.frame(x = 1:3, y = 10:12))
    session$flushReact()

    result2 <- cached_processing()
    expect_equal(result2, sum(c(11, 13, 15)))
  })
})

test_that("create_cached_reactive handles both functions and expressions", {
  skip_if_not(
    exists("create_cached_reactive"),
    "create_cached_reactive not available"
  )

  testServer(mock_cache_server, {
    val <- reactiveVal(5)

    cached_fn <- create_cached_reactive(
      reactive_expr = function() val() * 2,
      cache_key = "test_function",
      cache_timeout = 5
    )
    result_fn <- cached_fn()
    expect_equal(result_fn, 10)

    cached_expr <- create_cached_reactive(
      reactive_expr = {
        val() * 3
      },
      cache_key = "test_expression",
      cache_timeout = 5
    )
    result_expr <- cached_expr()
    expect_equal(result_expr, 15)
  })
})

test_that("create_cached_reactive provides performance benefit", {
  skip_if_not(
    exists("create_cached_reactive"),
    "create_cached_reactive not available"
  )
  skip_on_ci()

  testServer(mock_cache_server, {
    compute_count <- 0

    expensive_cached <- create_cached_reactive(
      reactive_expr = {
        compute_count <<- compute_count + 1
        Sys.sleep(0.01)
        runif(100)
      },
      cache_key = "expensive",
      cache_timeout = 10
    )

    start1 <- Sys.time()
    result1 <- expensive_cached()
    time1 <- as.numeric(Sys.time() - start1)
    expect_equal(compute_count, 1)
    expect_gte(time1, 0.01, info = "First call should take time")

    start2 <- Sys.time()
    result2 <- expensive_cached()
    time2 <- as.numeric(Sys.time() - start2)
    expect_equal(compute_count, 1, info = "Should not recompute")

    expect_identical(result1, result2)
  })
})
