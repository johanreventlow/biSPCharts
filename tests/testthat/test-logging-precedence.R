# Tests for Unified Logging Configuration Precedence
# Verify that log level is resolved correctly with precedence rules:
# 1. Environment variable (SPC_LOG_LEVEL) - highest priority
# 2. Golem config YAML (logging.level)
# 3. Default "INFO"

library(testthat)

test_that("get_effective_log_level returns valid log level (from YAML or default)", {
  # Clear environment variable - will use YAML config
  Sys.unsetenv("SPC_LOG_LEVEL")

  result <- get_effective_log_level()
  # Should be a valid log level (from YAML or "INFO" fallback)
  expect_true(result %in% c("DEBUG", "INFO", "WARN", "ERROR"),
              info = "Should return valid log level from YAML or default")
})

test_that("Environment variable SPC_LOG_LEVEL has highest priority", {
  # Set environment variable to DEBUG
  Sys.setenv(SPC_LOG_LEVEL = "DEBUG")

  result <- get_effective_log_level()
  expect_equal(result, "DEBUG", info = "Should return DEBUG from env var")

  # Set to ERROR
  Sys.setenv(SPC_LOG_LEVEL = "ERROR")
  result <- get_effective_log_level()
  expect_equal(result, "ERROR", info = "Should return ERROR from env var")

  # Set to INFO
  Sys.setenv(SPC_LOG_LEVEL = "INFO")
  result <- get_effective_log_level()
  expect_equal(result, "INFO", info = "Should return INFO from env var")

  # Clean up
  Sys.unsetenv("SPC_LOG_LEVEL")
})

test_that("Environment variable is case-insensitive", {
  # Set lowercase
  Sys.setenv(SPC_LOG_LEVEL = "debug")
  result <- get_effective_log_level()
  expect_equal(result, "DEBUG", info = "Should handle lowercase 'debug'")

  # Set mixed case
  Sys.setenv(SPC_LOG_LEVEL = "WaRn")
  result <- get_effective_log_level()
  expect_equal(result, "WARN", info = "Should handle mixed case 'WaRn'")

  # Clean up
  Sys.unsetenv("SPC_LOG_LEVEL")
})

test_that("Invalid environment variable is ignored, falls back to YAML/default", {
  # Set invalid log level
  Sys.setenv(SPC_LOG_LEVEL = "INVALID_LEVEL")

  result <- get_effective_log_level()
  # Should fallback to default since invalid
  expect_true(result %in% c("INFO", "DEBUG", "WARN", "ERROR"),
              info = "Should return valid level when env var is invalid")

  # Clean up
  Sys.unsetenv("SPC_LOG_LEVEL")
})

test_that("Empty environment variable is ignored", {
  # Set to empty string
  Sys.setenv(SPC_LOG_LEVEL = "")

  result <- get_effective_log_level()
  expect_true(result %in% c("INFO", "DEBUG", "WARN", "ERROR"),
              info = "Should ignore empty env var and fallback")

  # Clean up
  Sys.unsetenv("SPC_LOG_LEVEL")
})

test_that("Whitespace in environment variable is trimmed", {
  # Set with whitespace
  Sys.setenv(SPC_LOG_LEVEL = "  DEBUG  ")

  result <- get_effective_log_level()
  expect_equal(result, "DEBUG", info = "Should trim whitespace from env var")

  # Clean up
  Sys.unsetenv("SPC_LOG_LEVEL")
})

test_that("get_effective_log_level() is used by .should_log() helper", {
  # Set environment variable to DEBUG
  Sys.setenv(SPC_LOG_LEVEL = "DEBUG")

  # Should log DEBUG messages
  expect_true(.should_log("DEBUG"), info = "Should log DEBUG when level is DEBUG")
  expect_true(.should_log("INFO"), info = "Should log INFO when level is DEBUG")

  # Set to ERROR (only ERROR messages)
  Sys.setenv(SPC_LOG_LEVEL = "ERROR")
  expect_false(.should_log("DEBUG"), info = "Should not log DEBUG when level is ERROR")
  expect_false(.should_log("INFO"), info = "Should not log INFO when level is ERROR")
  expect_true(.should_log("ERROR"), info = "Should log ERROR when level is ERROR")

  # Clean up
  Sys.unsetenv("SPC_LOG_LEVEL")
})

test_that("get_log_level_name() uses unified precedence", {
  # Set environment variable
  Sys.setenv(SPC_LOG_LEVEL = "WARN")

  result <- get_log_level_name()
  expect_equal(result, "WARN", info = "Should return WARN from env var")

  # Unset environment variable
  Sys.unsetenv("SPC_LOG_LEVEL")

  result <- get_log_level_name()
  # Should be valid log level name
  expect_true(result %in% c("DEBUG", "INFO", "WARN", "ERROR"),
              info = "Should return valid log level")
})

test_that("Multiple calls to get_effective_log_level return consistent results", {
  # Set environment variable
  Sys.setenv(SPC_LOG_LEVEL = "INFO")

  result1 <- get_effective_log_level()
  result2 <- get_effective_log_level()

  expect_identical(result1, result2, info = "Should return consistent results")

  # Clean up
  Sys.unsetenv("SPC_LOG_LEVEL")
})
