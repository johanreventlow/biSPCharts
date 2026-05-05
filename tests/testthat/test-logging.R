# test-logging.R
# Konsolideret logging-testfil (Phase 3, Issue #322)
# Merget fra:
#   - test-logging-debug-cat.R    (1 test)
#   - test-logging-precedence.R   (9 tests)
#   - test-logging-standardization.R (19 tests)
#   - test-logging-system.R       (9 tests)
#
# test-utils_logging.R er IKKE merget her — den dækker regression-tests
# for specifikke API-signaturer (#291) og bevares som separat fil.

# ===========================================================================
# Fra test-logging-debug-cat.R: Cat-statement audit
# ===========================================================================

test_that("log_debug erstatter alle DEBUG-cat statements", {
  project_root <- normalizePath(file.path(testthat::test_path(".."), ".."), mustWork = TRUE)
  r_files <- list.files(project_root, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  debug_patterns <- c("cat\\s*\\(\\s*\\\"DEBUG", "cat\\s*\\(\\s*'DEBUG")
  offending_lines <- unlist(lapply(r_files, function(file_path) {
    lines <- readLines(file_path, warn = FALSE)
    match_indices <- unique(unlist(lapply(debug_patterns, function(pattern) {
      which(grepl(pattern, lines, perl = TRUE))
    })))
    match_indices <- sort(match_indices)
    if (length(match_indices) == 0L) {
      return(NULL)
    }
    paste0(file_path, ":", match_indices)
  }))
  expect(
    length(offending_lines) == 0,
    failure_message = paste(
      "Følgende cat(\"DEBUG statements skal konverteres til log_debug():",
      paste(offending_lines, collapse = "\n"),
      sep = "\n"
    )
  )
})

# ===========================================================================
# Fra test-logging-precedence.R: Log level precedence
# ===========================================================================

test_that("get_effective_log_level returns valid log level (from YAML or default)", {
  # Clear environment variable - will use YAML config
  Sys.unsetenv("SPC_LOG_LEVEL")

  result <- get_effective_log_level()
  # Should be a valid log level (from YAML or "INFO" fallback)
  expect_true(result %in% c("DEBUG", "INFO", "WARN", "ERROR"),
    info = "Should return valid log level from YAML or default"
  )
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
    info = "Should return valid level when env var is invalid"
  )

  # Clean up
  Sys.unsetenv("SPC_LOG_LEVEL")
})

test_that("Empty environment variable is ignored", {
  # Set to empty string
  Sys.setenv(SPC_LOG_LEVEL = "")

  result <- get_effective_log_level()
  expect_true(result %in% c("INFO", "DEBUG", "WARN", "ERROR"),
    info = "Should ignore empty env var and fallback"
  )

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
    info = "Should return valid log level"
  )
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

# ===========================================================================
# Fra test-logging-standardization.R: API consistency og standardization
# ===========================================================================

# Context-info test er droppet (skip-only, ingen reel assertion)

test_that("all logging functions exist and are callable", {
  logging_functions <- c("log_debug", "log_info", "log_warn", "log_error", "log_msg")

  for (func_name in logging_functions) {
    expect_true(exists(func_name, mode = "function"),
      info = paste("Function", func_name, "should exist")
    )
  }
})

test_that("logging functions support consistent API", {
  require_internal("log_info", mode = "function")
  require_internal("log_debug", mode = "function")
  require_internal("log_warn", mode = "function")
  require_internal("log_error", mode = "function")

  expect_no_error(log_info("Test info message"))
  expect_no_error(log_debug("Test debug message"))
  expect_no_error(log_warn("Test warning message"))
  expect_no_error(log_error("Test error message"))
  # Verificér returnerer usynligt NULL (ikke fejl, ikke output)
  expect_null(invisible(log_info("Test info message")))
})

test_that("logging functions support .context parameter for backward compatibility", {
  require_internal("log_info", mode = "function")
  require_internal("log_debug", mode = "function")
  require_internal("log_warn", mode = "function")
  require_internal("log_error", mode = "function")

  expect_no_error(log_info("Test message", .context = "TEST_CONTEXT"))
  expect_no_error(log_debug("Test message", .context = "TEST_CONTEXT"))
  expect_no_error(log_warn("Test message", .context = "TEST_CONTEXT"))
  expect_no_error(log_error("Test message", .context = "TEST_CONTEXT"))
  # Verificér at alle fire logging-funktioner er tilgængelige med .context
  expect_true(is.function(log_info) && is.function(log_debug) &&
    is.function(log_warn) && is.function(log_error))
})

test_that("logging functions support component parameter for new style", {
  require_internal("log_info", mode = "function")
  require_internal("log_debug", mode = "function")
  require_internal("log_warn", mode = "function")
  require_internal("log_error", mode = "function")

  expect_no_error(log_info("Test message", component = "TEST_COMPONENT"))
  expect_no_error(log_debug("Test message", component = "TEST_COMPONENT"))
  expect_no_error(log_warn("Test message", component = "TEST_COMPONENT"))
  expect_no_error(log_error("Test message", component = "TEST_COMPONENT"))
  # Verificér at component-parameteren er i function-signaturen
  expect_true("component" %in% names(formals(log_info)))
})

test_that("component parameter takes precedence over .context when both provided", {
  require_internal("log_info", mode = "function")

  expect_no_error({
    log_info("Test message", component = "COMPONENT", .context = "CONTEXT")
  })
})

test_that("logging functions support structured details parameter", {
  require_internal("log_debug_kv", mode = "function")

  expect_no_error({
    log_debug_kv(
      message = "Test structured message",
      test_key = "test_value",
      numeric_value = 123,
      .context = "TEST_CONTEXT"
    )
  })
})

test_that("logging respects log level configuration", {
  require_internal("log_debug", mode = "function")
  require_internal("log_info", mode = "function")

  original_level <- Sys.getenv("SPC_LOG_LEVEL", "")

  Sys.setenv(SPC_LOG_LEVEL = "INFO")
  expect_no_error(log_info("Info message at INFO level"))
  expect_no_error(log_debug("Debug message at INFO level"))
  # Verificér at log level kan læses korrekt efter sætning
  expect_equal(get_effective_log_level(), "INFO")

  Sys.setenv(SPC_LOG_LEVEL = "DEBUG")
  expect_no_error(log_info("Info message at DEBUG level"))
  expect_no_error(log_debug("Debug message at DEBUG level"))
  expect_equal(get_effective_log_level(), "DEBUG")

  if (original_level == "") {
    Sys.unsetenv("SPC_LOG_LEVEL")
  } else {
    Sys.setenv(SPC_LOG_LEVEL = original_level)
  }
})

test_that("logging system avoids raw cat() fallbacks in production", {
  require_internal("log_info", mode = "function")

  captured_output <- capture.output(
    {
      log_info("Test message for output verification", component = "TEST")
    },
    type = "message"
  )

  if (length(captured_output) > 0) {
    combined_output <- paste(captured_output, collapse = " ")
    expect_true(grepl("\\[.*\\]", combined_output) ||
      grepl("INFO|ERROR|WARN|DEBUG", combined_output))
  }
})

test_that("logging functions handle errors gracefully", {
  require_internal("log_error", mode = "function")

  expect_no_error(log_error(NULL))
  expect_no_error(log_error(""))
  expect_no_error(log_error(123))
  expect_no_error(log_error(list(key = "value")))

  long_message <- paste(rep("A", 10000), collapse = "")
  expect_no_error(log_error(long_message))

  special_message <- "Message with øæå and 中文 and emojis"
  expect_no_error(log_error(special_message))
})

test_that("logging contexts follow standardized naming convention", {
  standard_contexts <- c(
    "APP_SERVER", "FILE_UPLOAD", "COLUMN_MGMT", "AUTO_DETECT",
    "PLOT_DATA", "SESSION_LIFECYCLE", "STARTUP_CACHE", "LAZY_LOADING",
    "ERROR_HANDLING", "TEST_MODE", "PERFORMANCE_MONITOR"
  )

  require_internal("log_info", mode = "function")

  for (context in standard_contexts) {
    expect_no_error({
      log_info(paste("Test message for", context), .context = context)
    })
  }
})

test_that("logging operations are performant", {
  require_internal("log_info", mode = "function")

  start_time <- Sys.time()
  log_info("Performance test message", component = "PERFORMANCE_TEST")
  single_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  expect_lt(single_time, 0.05)

  start_time <- Sys.time()
  for (i in 1:100) {
    log_info(paste("Batch test message", i), component = "PERFORMANCE_TEST")
  }
  batch_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  expect_lt(batch_time, 2.0)
})

test_that("safe_operation integrates correctly with logging system", {
  require_internal("safe_operation", mode = "function")

  expect_no_error({
    result <- safe_operation(
      operation_name = "Test operation for logging",
      code = {
        "success"
      },
      fallback = "fallback_value",
      error_type = "test"
    )
    expect_equal(result, "success")
  })

  expect_no_error({
    result <- safe_operation(
      operation_name = "Test operation with error",
      code = {
        stop("Intentional test error")
      },
      fallback = "fallback_value",
      error_type = "test"
    )
    expect_equal(result, "fallback_value")
  })
})

test_that("logging system manages memory efficiently", {
  require_internal("log_info", mode = "function")

  memory_used_mb <- function() {
    gc_info <- gc()
    cell_sizes <- c(Ncells = 56, Vcells = 8)
    sum(gc_info[, "used"] * cell_sizes[rownames(gc_info)], na.rm = TRUE) / 1024^2
  }

  mem_before <- memory_used_mb()

  for (i in 1:1000) {
    log_info(paste("Memory test message", i), component = "MEMORY_TEST")
  }

  mem_after <- memory_used_mb()

  mem_increase <- mem_after - mem_before
  expect_lt(mem_increase, 10)
})

test_that("logging output follows consistent format", {
  require_internal("log_info", mode = "function")

  captured_output <- capture.output(
    {
      log_info("Format test message", component = "FORMAT_TEST")
    },
    type = "message"
  )

  if (length(captured_output) > 0) {
    output_line <- captured_output[1]
    expect_true(nchar(output_line) > 0)
    expect_false(grepl("^Format test message$", output_line))
  }
})

test_that("logging API handles edge cases correctly", {
  require_internal("log_info", mode = "function")

  expect_no_error(log_info("Test message", component = ""))
  expect_no_error(log_info("Test message", .context = ""))
  expect_no_error(log_info("Test message", component = NULL))
  expect_no_error(log_info("Test message", .context = NULL))
  expect_no_error(log_info("Test message"))
  expect_no_error(log_info(123))
  expect_no_error(log_info(c("a", "b", "c")))
})

test_that("logging system initializes correctly", {
  require_internal("log_info", mode = "function")

  expect_no_error(log_info("Initialization test message"))

  current_level <- Sys.getenv("SPC_LOG_LEVEL", "")
  expect_true(current_level %in% c("", "DEBUG", "INFO", "WARN", "ERROR"))
})

test_that("structured logging with log_debug_kv works correctly", {
  require_internal("log_debug_kv", mode = "function")

  expect_no_error({
    log_debug_kv(
      message = "Structured test message",
      key1 = "value1",
      key2 = 123,
      key3 = TRUE,
      .context = "STRUCTURED_TEST"
    )
  })

  expect_no_error({
    log_debug_kv(
      key1 = "value1",
      .context = "STRUCTURED_TEST"
    )
  })
})

test_that("logging system works end-to-end", {
  require_internal("log_debug", mode = "function")
  require_internal("log_info", mode = "function")
  require_internal("log_warn", mode = "function")
  require_internal("log_error", mode = "function")

  expect_no_error({
    log_debug("Debug message", component = "INTEGRATION_TEST")
    log_info("Info message", component = "INTEGRATION_TEST")
    log_warn("Warning message", component = "INTEGRATION_TEST")
    log_error("Error message", component = "INTEGRATION_TEST")
    log_info("Backward compatibility test", .context = "INTEGRATION_TEST")

    if (exists("log_debug_kv", mode = "function")) {
      log_debug_kv(
        message = "Structured logging test",
        test_key = "test_value",
        .context = "INTEGRATION_TEST"
      )
    }
  })
})

# ===========================================================================
# Fra test-logging-system.R: Lavniveau logging-system tests
# ===========================================================================

test_that("logging system grundlæggende funktionalitet", {
  expect_true(exists("log_debug"))
  expect_true(exists("log_info"))
  expect_true(exists("log_warn"))
  expect_true(exists("log_error"))
  expect_true(exists("log_msg"))
  expect_true(exists("get_log_level"))

  expect_true(exists("LOG_LEVELS"))
  expect_type(LOG_LEVELS, "list")
  expect_equal(LOG_LEVELS$DEBUG, 1)
  expect_equal(LOG_LEVELS$INFO, 2)
  expect_equal(LOG_LEVELS$WARN, 3)
  expect_equal(LOG_LEVELS$ERROR, 4)
})

test_that("get_log_level håndterer environment variabler korrekt", {
  original_level <- Sys.getenv("SPC_LOG_LEVEL", "")

  Sys.unsetenv("SPC_LOG_LEVEL")
  expect_equal(get_log_level(), LOG_LEVELS$INFO)

  Sys.setenv(SPC_LOG_LEVEL = "DEBUG")
  expect_equal(get_log_level(), LOG_LEVELS$DEBUG)

  Sys.setenv(SPC_LOG_LEVEL = "INFO")
  expect_equal(get_log_level(), LOG_LEVELS$INFO)

  Sys.setenv(SPC_LOG_LEVEL = "WARN")
  expect_equal(get_log_level(), LOG_LEVELS$WARN)

  Sys.setenv(SPC_LOG_LEVEL = "ERROR")
  expect_equal(get_log_level(), LOG_LEVELS$ERROR)

  Sys.setenv(SPC_LOG_LEVEL = "debug")
  expect_equal(get_log_level(), LOG_LEVELS$DEBUG)

  Sys.setenv(SPC_LOG_LEVEL = "Info")
  expect_equal(get_log_level(), LOG_LEVELS$INFO)

  Sys.setenv(SPC_LOG_LEVEL = "INVALID")
  expect_equal(get_log_level(), LOG_LEVELS$INFO)

  Sys.setenv(SPC_LOG_LEVEL = "")
  expect_equal(get_log_level(), LOG_LEVELS$INFO)

  if (original_level == "") {
    Sys.unsetenv("SPC_LOG_LEVEL")
  } else {
    Sys.setenv(SPC_LOG_LEVEL = original_level)
  }
})

test_that("log level filtering virker korrekt", {
  original_level <- Sys.getenv("SPC_LOG_LEVEL", "")

  Sys.setenv(SPC_LOG_LEVEL = "ERROR")
  expect_output(log_error("Error message", "TEST"), "ERROR.*TEST.*Error message")
  expect_silent(log_warn("Warning message", "TEST"))
  expect_silent(log_info("Info message", "TEST"))
  expect_silent(log_debug("Debug message", "TEST"))

  Sys.setenv(SPC_LOG_LEVEL = "WARN")
  expect_output(log_error("Error message", "TEST"), "ERROR.*TEST.*Error message")
  expect_output(log_warn("Warning message", "TEST"), "WARN.*TEST.*Warning message")
  expect_silent(log_info("Info message", "TEST"))
  expect_silent(log_debug("Debug message", "TEST"))

  Sys.setenv(SPC_LOG_LEVEL = "INFO")
  expect_output(log_error("Error message", "TEST"), "ERROR.*TEST.*Error message")
  expect_output(log_warn("Warning message", "TEST"), "WARN.*TEST.*Warning message")
  expect_output(log_info("Info message", "TEST"), "INFO.*TEST.*Info message")
  expect_silent(log_debug("Debug message", "TEST"))

  Sys.setenv(SPC_LOG_LEVEL = "DEBUG")
  expect_output(log_error("Error message", "TEST"), "ERROR.*TEST.*Error message")
  expect_output(log_warn("Warning message", "TEST"), "WARN.*TEST.*Warning message")
  expect_output(log_info("Info message", "TEST"), "INFO.*TEST.*Info message")
  expect_output(log_debug("Debug message", .context = "TEST"), "DEBUG.*\\[TEST\\].*Debug message")

  if (original_level == "") {
    Sys.unsetenv("SPC_LOG_LEVEL")
  } else {
    Sys.setenv(SPC_LOG_LEVEL = original_level)
  }
})

test_that("komponens-baseret tagging fungerer", {
  original_level <- Sys.getenv("SPC_LOG_LEVEL", "")
  Sys.setenv(SPC_LOG_LEVEL = "DEBUG")

  expect_output(log_debug("Test message", .context = "DATA_PROC"), "DEBUG.*\\[DATA_PROC\\].*Test message")
  expect_output(log_info("Test message", "AUTO_DETECT"), "INFO.*\\[AUTO_DETECT\\].*Test message")
  expect_output(log_warn("Test message", "FILE_UPLOAD"), "WARN.*\\[FILE_UPLOAD\\].*Test message")
  expect_output(log_error("Test message", "ERROR_HANDLING"), "ERROR.*\\[ERROR_HANDLING\\].*Test message")

  expect_output(log_info("Test without component"), "INFO:.*Test without component")
  expect_output(log_info("Test message", ""), "INFO:.*Test message")
  expect_output(log_info("Test message", NULL), "INFO:.*Test message")

  if (original_level == "") {
    Sys.unsetenv("SPC_LOG_LEVEL")
  } else {
    Sys.setenv(SPC_LOG_LEVEL = original_level)
  }
})

test_that("log_msg funktionalitet med forskellige levels", {
  original_level <- Sys.getenv("SPC_LOG_LEVEL", "")
  Sys.setenv(SPC_LOG_LEVEL = "DEBUG")

  expect_output(log_msg("Debug message", "DEBUG", "TEST"), "DEBUG.*\\[TEST\\].*Debug message")
  expect_output(log_msg("Info message", "INFO", "TEST"), "INFO.*\\[TEST\\].*Info message")
  expect_output(log_msg("Warn message", "WARN", "TEST"), "WARN.*\\[TEST\\].*Warn message")
  expect_output(log_msg("Error message", "ERROR", "TEST"), "ERROR.*\\[TEST\\].*Error message")

  expect_output(log_msg("Debug message", "debug", "TEST"), "DEBUG.*\\[TEST\\].*Debug message")
  expect_output(log_msg("Info message", "info", "TEST"), "INFO.*\\[TEST\\].*Info message")

  expect_silent(log_msg("Invalid message", "INVALID", "TEST"))

  output <- capture.output(log_msg("Test timestamp", "INFO", "TEST"))
  expect_match(output, "\\[\\d{2}:\\d{2}:\\d{2}\\] INFO: \\[TEST\\] Test timestamp")

  if (original_level == "") {
    Sys.unsetenv("SPC_LOG_LEVEL")
  } else {
    Sys.setenv(SPC_LOG_LEVEL = original_level)
  }
})

test_that("logging system edge cases", {
  original_level <- Sys.getenv("SPC_LOG_LEVEL", "")
  Sys.setenv(SPC_LOG_LEVEL = "DEBUG")

  long_message <- paste(rep("A", 1000), collapse = "")
  expect_output(log_info(long_message, "TEST"), "INFO.*\\[TEST\\].*AAAA")

  special_message <- "Æøå!@#$%^&*()[]{}|\\:;\"'<>,.?/~`"
  expect_output(log_info(special_message, "TEST"), "INFO.*\\[TEST\\].*Æøå")

  newline_message <- "Line 1\nLine 2\nLine 3"
  expect_output(log_info(newline_message, "TEST"), "INFO.*\\[TEST\\].*Line 1")

  expect_output(log_info("", "TEST"), "INFO.*\\[TEST\\].*")
  expect_output(log_info("   ", "TEST"), "INFO.*\\[TEST\\].*   ")

  expect_silent(log_info(NULL, "TEST"))

  if (original_level == "") {
    Sys.unsetenv("SPC_LOG_LEVEL")
  } else {
    Sys.setenv(SPC_LOG_LEVEL = original_level)
  }
})

test_that("log_debug_block funktionalitet", {
  original_level <- Sys.getenv("SPC_LOG_LEVEL", "")
  Sys.setenv(SPC_LOG_LEVEL = "DEBUG")

  expect_output(
    log_debug_block("TEST_CONTEXT", "Starting test operation"),
    "DEBUG.*\\[TEST_CONTEXT\\].*====="
  )
  expect_output(
    log_debug_block("TEST_CONTEXT", "Starting test operation"),
    "DEBUG.*\\[TEST_CONTEXT\\].*Starting test operation"
  )

  expect_output(
    log_debug_block("TEST_CONTEXT", "Test operation", type = "stop"),
    "DEBUG.*\\[TEST_CONTEXT\\].*Test operation - completed"
  )

  output <- capture.output(log_debug_block("TEST_CONTEXT", "Full test operation", type = "both"))
  expect_equal(length(output), 4L)
  expect_match(output[1], "DEBUG.*\\[TEST_CONTEXT\\].*=====")
  expect_match(output[2], "DEBUG.*\\[TEST_CONTEXT\\].*Full test operation$")
  expect_match(output[3], "DEBUG.*\\[TEST_CONTEXT\\].*Full test operation - completed")
  expect_match(output[4], "DEBUG.*\\[TEST_CONTEXT\\].*=====")

  if (original_level == "") {
    Sys.unsetenv("SPC_LOG_LEVEL")
  } else {
    Sys.setenv(SPC_LOG_LEVEL = original_level)
  }
})

test_that("log_debug_kv funktionalitet", {
  original_level <- Sys.getenv("SPC_LOG_LEVEL", "")
  Sys.setenv(SPC_LOG_LEVEL = "DEBUG")

  output <- capture.output(log_debug_kv(trigger_value = 1, status = "active", .context = "TEST"))
  expect_equal(length(output), 2L)
  expect_match(output[1], "DEBUG.*\\[TEST\\].*trigger_value: 1")
  expect_match(output[2], "DEBUG.*\\[TEST\\].*status: active")

  test_list <- list(rows = 100, cols = 5, type = "data.frame")
  expect_output(
    log_debug_kv(.list_data = test_list, .context = "TEST"),
    "DEBUG.*\\[TEST\\].*rows: 100"
  )
  expect_output(
    log_debug_kv(.list_data = test_list, .context = "TEST"),
    "DEBUG.*\\[TEST\\].*cols: 5"
  )

  output <- capture.output(log_debug_kv(direct_arg = "value", .list_data = list(list_arg = "list_value"), .context = "TEST"))
  expect_true(length(output) == 2)
  expect_match(output[1], "DEBUG.*\\[TEST\\].*direct_arg: value")
  expect_match(output[2], "DEBUG.*\\[TEST\\].*list_arg: list_value")

  expect_output(log_debug_kv(test_key = "test_value"), "DEBUG.*test_key: test_value")

  expect_silent(log_debug_kv(.context = "TEST"))

  if (original_level == "") {
    Sys.unsetenv("SPC_LOG_LEVEL")
  } else {
    Sys.setenv(SPC_LOG_LEVEL = original_level)
  }
})

test_that("helper funktioner eksisterer og er tilgængelige", {
  expect_true(exists("log_debug_block"))
  expect_true(exists("log_debug_kv"))

  expect_type(log_debug_block, "closure")
  expect_type(log_debug_kv, "closure")
})
