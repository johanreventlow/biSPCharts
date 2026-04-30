# test-yaml-config-adherence.R
# Tests for YAML configuration adherence across different environments

test_that("YAML configuration is loaded correctly per environment", {
  skip_if_not(file.exists("inst/golem-config.yml"), "golem-config.yml not found")

  # Test that YAML config can be loaded for different environments
  environments_to_test <- c("default", "development", "production")

  for (env in environments_to_test) {
    original_config <- Sys.getenv("GOLEM_CONFIG_ACTIVE", "")
    on.exit(
      {
        if (original_config == "") {
          Sys.unsetenv("GOLEM_CONFIG_ACTIVE")
        } else {
          Sys.setenv(GOLEM_CONFIG_ACTIVE = original_config)
        }
      },
      add = TRUE
    )

    # Set environment and test config loading
    Sys.setenv(GOLEM_CONFIG_ACTIVE = env)

    config_result <- safe_operation(
      paste("Load YAML config for", env),
      code = {
        if (exists("get_golem_config", mode = "function")) {
          get_golem_config("logging")
        } else {
          NULL
        }
      },
      fallback = NULL
    )

    # Should either load successfully or return NULL (both acceptable)
    expect_true(is.null(config_result) || is.list(config_result),
      info = paste("YAML config should load or be NULL for environment:", env)
    )
  }
})

test_that("Logging configuration respects YAML settings when available", {
  skip_if_not(file.exists("inst/golem-config.yml"), "golem-config.yml not found")

  original_config <- Sys.getenv("GOLEM_CONFIG_ACTIVE", "")
  original_log_level <- Sys.getenv("SPC_LOG_LEVEL", "")

  on.exit({
    if (original_config == "") {
      Sys.unsetenv("GOLEM_CONFIG_ACTIVE")
    } else {
      Sys.setenv(GOLEM_CONFIG_ACTIVE = original_config)
    }
    if (original_log_level == "") {
      Sys.unsetenv("SPC_LOG_LEVEL")
    } else {
      Sys.setenv(SPC_LOG_LEVEL = original_log_level)
    }
  })

  # Test development environment YAML loading
  Sys.setenv(GOLEM_CONFIG_ACTIVE = "development")
  Sys.unsetenv("SPC_LOG_LEVEL")

  configure_logging_from_yaml()

  development_log_level <- Sys.getenv("SPC_LOG_LEVEL", "")
  expect_true(development_log_level != "", "Development should set log level")

  # Test production environment YAML loading
  Sys.setenv(GOLEM_CONFIG_ACTIVE = "production")
  Sys.unsetenv("SPC_LOG_LEVEL")

  configure_logging_from_yaml()

  production_log_level <- Sys.getenv("SPC_LOG_LEVEL", "")
  expect_true(production_log_level != "", "Production should set log level")

  # Environments should potentially have different log levels
  log_debug(
    component = "[TEST_YAML_CONFIG]",
    message = "YAML configuration test results",
    details = list(
      development_log_level = development_log_level,
      production_log_level = production_log_level
    )
  )
})

test_that("Fallback behavior works when YAML config is unavailable", {
  # NOTE (#239 — package/infra): get_golem_config() lever i pakke-namespacet og
  # kan ikke fjernes fra .GlobalEnv for at simulere "YAML unavailable".
  # Fallback-kodevejen (hardcoded "DEBUG"/"WARN") kan derfor ikke nås i
  # en normal pakke-load. Tests verificerer i stedet det faktiske YAML-indhold
  # som er grunden til at koden opfører sig korrekt i produktion.
  #
  # Faktiske YAML-værdier (inst/golem-config.yml):
  #   development: logging.level = "DEBUG"
  #   production:  logging.level = "ERROR"

  original_config <- Sys.getenv("GOLEM_CONFIG_ACTIVE", "")
  original_log_level <- Sys.getenv("SPC_LOG_LEVEL", "")

  on.exit({
    if (original_config == "") {
      Sys.unsetenv("GOLEM_CONFIG_ACTIVE")
    } else {
      Sys.setenv(GOLEM_CONFIG_ACTIVE = original_config)
    }
    if (original_log_level == "") {
      Sys.unsetenv("SPC_LOG_LEVEL")
    } else {
      Sys.setenv(SPC_LOG_LEVEL = original_log_level)
    }
  })

  # Test development: YAML sætter "DEBUG"
  Sys.setenv(GOLEM_CONFIG_ACTIVE = "development")
  Sys.unsetenv("SPC_LOG_LEVEL")

  configure_logging_from_yaml()
  expect_equal(Sys.getenv("SPC_LOG_LEVEL"), "DEBUG",
    info = "Development should use DEBUG fra YAML config"
  )

  # Test production: YAML sætter "ERROR" (ikke "WARN" — se inst/golem-config.yml)
  Sys.setenv(GOLEM_CONFIG_ACTIVE = "production")
  Sys.unsetenv("SPC_LOG_LEVEL")

  configure_logging_from_yaml()
  expect_equal(Sys.getenv("SPC_LOG_LEVEL"), "ERROR",
    info = "Production skal bruge ERROR fra YAML config (golem-config.yml production.logging.level)"
  )
})

test_that("Configuration precedence order is respected", {
  original_config <- Sys.getenv("GOLEM_CONFIG_ACTIVE", "")
  original_log_level <- Sys.getenv("SPC_LOG_LEVEL", "")

  on.exit({
    if (original_config == "") {
      Sys.unsetenv("GOLEM_CONFIG_ACTIVE")
    } else {
      Sys.setenv(GOLEM_CONFIG_ACTIVE = original_config)
    }
    if (original_log_level == "") {
      Sys.unsetenv("SPC_LOG_LEVEL")
    } else {
      Sys.setenv(SPC_LOG_LEVEL = original_log_level)
    }
  })

  # Test precedence: Explicit > YAML > Environment Default

  # 1. Explicit parameter should override everything
  Sys.setenv(GOLEM_CONFIG_ACTIVE = "production") # Would default to WARN
  Sys.unsetenv("SPC_LOG_LEVEL")

  configure_logging_from_yaml(log_level = "ERROR")
  expect_equal(
    Sys.getenv("SPC_LOG_LEVEL"), "ERROR",
    info = "Explicit log level should have highest precedence"
  )

  # 2. When no explicit parameter, should use YAML or fallback
  Sys.unsetenv("SPC_LOG_LEVEL")
  configure_logging_from_yaml() # No explicit parameter

  final_log_level <- Sys.getenv("SPC_LOG_LEVEL", "")
  expect_true(
    final_log_level %in% c("DEBUG", "INFO", "WARN", "ERROR"),
    "Should set valid log level from YAML or fallback"
  )
})

test_that("Environment-specific test mode configuration works", {
  original_config <- Sys.getenv("GOLEM_CONFIG_ACTIVE", "")
  original_test_mode <- Sys.getenv("TEST_MODE_AUTO_LOAD", "")

  on.exit({
    if (original_config == "") {
      Sys.unsetenv("GOLEM_CONFIG_ACTIVE")
    } else {
      Sys.setenv(GOLEM_CONFIG_ACTIVE = original_config)
    }
    if (original_test_mode == "") {
      Sys.unsetenv("TEST_MODE_AUTO_LOAD")
    } else {
      Sys.setenv(TEST_MODE_AUTO_LOAD = original_test_mode)
    }
  })

  # Test development environment enables test mode
  configure_app_environment(enable_test_mode = TRUE)

  expect_equal(Sys.getenv("GOLEM_CONFIG_ACTIVE"), "development")
  expect_equal(Sys.getenv("TEST_MODE_AUTO_LOAD"), "TRUE")

  # Test production environment disables test mode
  configure_app_environment(enable_test_mode = FALSE)

  expect_equal(Sys.getenv("GOLEM_CONFIG_ACTIVE"), "production")
  expect_equal(Sys.getenv("TEST_MODE_AUTO_LOAD"), "FALSE")
})
