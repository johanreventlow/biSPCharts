# test-session-timeout.R
# TDD: Tests for setup_session_timeout() helper
# Verificerer: idle > timeout → disconnect; aktivitet inden timeout → reset timer

test_that("setup_session_timeout returnerer en cancel-funktion", {
  # Minimal mock-session der logger kald
  disconnected <- FALSE
  session_mock <- list(
    close = function() {
      disconnected <<- TRUE
    }
  )

  # Injicér synchronous fake-scheduler (kører aldrig automatisk)
  scheduled_callbacks <- list()
  fake_scheduler <- function(callback, delay_secs) {
    scheduled_callbacks[[length(scheduled_callbacks) + 1]] <<- list(
      callback = callback,
      delay    = delay_secs
    )
    invisible(NULL)
  }

  result <- setup_session_timeout(
    session        = session_mock,
    minutes        = 1,
    .scheduler     = fake_scheduler
  )

  expect_type(result, "list")
  expect_true("cancel" %in% names(result))
  expect_true(is.function(result$cancel))
  expect_false(disconnected)
})

test_that("setup_session_timeout returnerer reset-funktion", {
  disconnected <- FALSE
  session_mock <- list(close = function() {
    disconnected <<- TRUE
  })

  calls <- 0L
  fake_scheduler <- function(callback, delay_secs) {
    calls <<- calls + 1L
    invisible(NULL)
  }

  result <- setup_session_timeout(
    session    = session_mock,
    minutes    = 5,
    .scheduler = fake_scheduler
  )

  expect_true("reset" %in% names(result))
  expect_true(is.function(result$reset))
})

test_that("setup_session_timeout disconnecter session ved udløb", {
  disconnected <- FALSE
  session_mock <- list(close = function() {
    disconnected <<- TRUE
  })

  # Synkron fake-scheduler: kald callback øjeblikkeligt
  immediate_scheduler <- function(callback, delay_secs) {
    callback()
    invisible(NULL)
  }

  setup_session_timeout(
    session    = session_mock,
    minutes    = 1,
    .scheduler = immediate_scheduler
  )

  expect_true(disconnected)
})

test_that("setup_session_timeout bruger korrekt forsinkelse i sekunder", {
  delays <- numeric(0)
  session_mock <- list(close = function() invisible(NULL))

  capturing_scheduler <- function(callback, delay_secs) {
    delays <<- c(delays, delay_secs)
    invisible(NULL)
  }

  setup_session_timeout(
    session    = session_mock,
    minutes    = 30,
    .scheduler = capturing_scheduler
  )

  expect_equal(delays, 30 * 60)
})

test_that("reset nulstiller timer (ny callback scheduleres)", {
  callbacks_called <- 0L
  session_mock <- list(close = function() invisible(NULL))

  counting_scheduler <- function(callback, delay_secs) {
    callbacks_called <<- callbacks_called + 1L
    invisible(NULL)
  }

  result <- setup_session_timeout(
    session    = session_mock,
    minutes    = 10,
    .scheduler = counting_scheduler
  )

  initial_count <- callbacks_called
  result$reset()
  expect_gt(callbacks_called, initial_count)
})

test_that("timeout_message er dansk og indeholder korrekte nøgleord", {
  msg <- session_timeout_message()
  expect_type(msg, "character")
  expect_match(msg, "Session", ignore.case = TRUE)
  expect_match(msg, "inaktivitet", ignore.case = TRUE)
  expect_match(msg, "Genindlæs|genindlæs", ignore.case = TRUE)
})
