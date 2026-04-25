# test-debug-context-filtering.R
# Tests for debug context filtering feature in utils_logging.R

test_that("Default behavior: no filtering (spc.debug.context not set)", {
  # Reset option
  options(spc.debug.context = NULL)
  expect_null(get_debug_context())

  # All contexts should be allowed
  expect_true(.should_log_context("state"))
  expect_true(.should_log_context("data"))
  expect_true(.should_log_context("performance"))
  expect_true(.should_log_context("ANYTHING"))
  expect_true(.should_log_context(NULL))
})

test_that("Context filtering works with character vector", {
  # Set specific contexts to log
  set_debug_context(c("state", "data"))

  # Check what's set
  current <- get_debug_context()
  expect_equal(current, c("state", "data"))

  # Matching contexts should pass
  expect_true(.should_log_context("state"))
  expect_true(.should_log_context("data"))

  # Non-matching contexts should fail
  expect_false(.should_log_context("performance"))
  expect_false(.should_log_context("debug"))
  expect_false(.should_log_context(NULL))

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("Context filtering is case-sensitive", {
  set_debug_context(c("STATE", "data"))

  # Exact match works
  expect_true(.should_log_context("STATE"))
  expect_true(.should_log_context("data"))

  # Case variations don't match
  expect_false(.should_log_context("state")) # lowercase
  expect_false(.should_log_context("Data")) # mixed case
  expect_false(.should_log_context("DATA")) # uppercase

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("Empty context list filters everything", {
  # Suppress message output for this test
  suppressMessages(set_debug_context(character(0)))

  # Nothing should pass
  expect_false(.should_log_context("state"))
  expect_false(.should_log_context("data"))
  expect_false(.should_log_context(NULL))

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("NULL context handling", {
  set_debug_context(c("state", "UNSPECIFIED"))

  # NULL context should only pass if UNSPECIFIED is in the list
  expect_true(.should_log_context(NULL))
  expect_true(.should_log_context("UNSPECIFIED"))

  # Remove UNSPECIFIED
  set_debug_context(c("state", "data"))
  expect_false(.should_log_context(NULL))

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("set_debug_context validates input", {
  # Non-character input should raise error
  expect_error(set_debug_context(123), "contexts must be a character vector or NULL")
  expect_error(set_debug_context(list("a", "b")), "contexts must be a character vector or NULL")

  # NULL should work
  expect_no_error(set_debug_context(NULL))

  # Character vector should work
  expect_no_error(set_debug_context(c("a", "b")))

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("set_debug_context produces messages", {
  # Setting to NULL
  expect_message(set_debug_context(NULL), "Debug context filtering disabled")

  # Setting to empty vector - message contains "empty"
  # character(0) is equivalent to c() but more explicit
  expect_message(set_debug_context(character(0)), "empty")

  # Setting to specific contexts
  expect_message(set_debug_context(c("state", "data")), "state")

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("get_debug_context returns current setting", {
  # Default: NULL
  options(spc.debug.context = NULL)
  expect_null(get_debug_context())

  # After setting
  set_debug_context(c("a", "b"))
  result <- get_debug_context()
  expect_equal(result, c("a", "b"))

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("list_available_log_contexts returns all contexts", {
  all_contexts <- list_available_log_contexts()

  # Should be a character vector
  expect_type(all_contexts, "character")

  # Should have many contexts
  expect_gt(length(all_contexts), 10)

  # Should include known contexts from LOG_CONTEXTS
  expect_true("DATA_PROCESS" %in% all_contexts)
  expect_true("RENDER_PLOT" %in% all_contexts)
  expect_true("QIC" %in% all_contexts)
  expect_true("AUTO_DETECT_CACHE" %in% all_contexts)

  # No duplicates
  expect_equal(length(all_contexts), length(unique(all_contexts)))
})

test_that("log_debug respects context filtering", {
  set_debug_context(c("state"))

  # Matching context should not error
  expect_no_error(log_debug("Test message 1", .context = "state"))

  # Non-matching context should silently skip (not error)
  expect_no_error(log_debug("Test message 2", .context = "performance"))

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("log_info respects context filtering", {
  set_debug_context(c("data"))

  # Both log_info and other functions should respect filtering
  # (Just verify they don't error when context filtering is set)
  expect_no_error(log_info("test", .context = "data"))
  expect_no_error(log_info("test", .context = "other")) # Should skip silently

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("log_warn respects context filtering", {
  set_debug_context(c("performance"))

  expect_no_error(log_warn("test", .context = "performance"))
  expect_no_error(log_warn("test", .context = "other")) # Should skip silently

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("log_error respects context filtering", {
  set_debug_context(c("debug"))

  expect_no_error(log_error("test", .context = "debug"))
  expect_no_error(log_error("test", .context = "other")) # Should skip silently

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("Context filtering works with legacy component parameter", {
  set_debug_context(c("state"))

  # log_info, log_warn, log_error support both .context and component
  # The .context takes precedence
  expect_no_error(log_info("test", component = "state"))
  expect_no_error(log_warn("test", .context = "state"))

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("Filtering multiple contexts at once", {
  contexts <- c("state", "data", "performance", "qic")
  set_debug_context(contexts)

  current <- get_debug_context()
  expect_equal(current, contexts)

  # All should pass
  for (ctx in contexts) {
    expect_true(.should_log_context(ctx))
  }

  # Others should fail
  expect_false(.should_log_context("other"))

  # Cleanup
  options(spc.debug.context = NULL)
})

test_that("Resetting filtering to NULL re-enables all", {
  # Set filtering
  set_debug_context(c("state"))
  expect_false(.should_log_context("data"))

  # Reset
  set_debug_context(NULL)

  # Now all should pass again
  expect_true(.should_log_context("state"))
  expect_true(.should_log_context("data"))
  expect_true(.should_log_context("anything"))
})
