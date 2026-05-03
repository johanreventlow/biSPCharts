# Unit tests for validate_configuration() — boot-time config-validering
# (M5 / #459).

test_that("validate_configuration: passerer med default GOLEM_CONFIG_ACTIVE", {
  withr::with_envvar(c(GOLEM_CONFIG_ACTIVE = "default"), {
    expect_silent(validate_configuration())
    expect_true(validate_configuration())
  })
})

test_that("validate_configuration: passerer med production environment", {
  withr::with_envvar(c(GOLEM_CONFIG_ACTIVE = "production"), {
    expect_true(validate_configuration())
  })
})

test_that("validate_configuration: fail-fast på ukendt GOLEM_CONFIG_ACTIVE", {
  withr::with_envvar(c(GOLEM_CONFIG_ACTIVE = "garbage"), {
    expect_error(
      validate_configuration(),
      "GOLEM_CONFIG_ACTIVE='garbage' er ikke en af",
      class = "bisp_config_error"
    )
  })
})

test_that("validate_configuration: signalerer typed bisp_config_error", {
  withr::with_envvar(c(GOLEM_CONFIG_ACTIVE = "ugyldig"), {
    err <- tryCatch(validate_configuration(),
      bisp_config_error = function(e) e
    )
    expect_s3_class(err, "bisp_config_error")
    expect_s3_class(err, "error")
  })
})
