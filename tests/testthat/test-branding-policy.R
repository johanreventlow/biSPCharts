# test-branding-policy.R
# Cycle A H2 reconciled (2026-05-09): regression-tests for branding-policy
# boot-validation.

with_golem_config_active <- function(profile, code) {
  old <- Sys.getenv("GOLEM_CONFIG_ACTIVE", unset = NA)
  on.exit({
    if (is.na(old)) Sys.unsetenv("GOLEM_CONFIG_ACTIVE") else Sys.setenv(GOLEM_CONFIG_ACTIVE = old)
  })
  Sys.setenv(GOLEM_CONFIG_ACTIVE = profile)
  force(code)
}

test_that("validate_branding_policy() passer i default-profile (no flag)", {
  with_golem_config_active("default", {
    expect_true(validate_branding_policy())
  })
})

test_that("validate_branding_policy() passer i development-profile (flag=FALSE)", {
  with_golem_config_active("development", {
    expect_true(validate_branding_policy())
  })
})

test_that("validate_branding_policy() passer i production naar BFHchartsAssets findes", {
  skip_if_not_installed("BFHchartsAssets")
  with_golem_config_active("production", {
    expect_true(validate_branding_policy())
  })
})

test_that("validate_branding_policy() fejler hard hvis flag=TRUE og BFHchartsAssets mangler", {
  if (requireNamespace("BFHchartsAssets", quietly = TRUE)) {
    skip("BFHchartsAssets installed - cannot test missing-pkg path without unmocking")
  }
  with_golem_config_active("production", {
    expect_error(
      validate_branding_policy(),
      class = "bisp_config_error",
      regexp = "BFHchartsAssets-pakken mangler"
    )
  })
})

test_that("production-profile har require_branded_assets: true (regression-guard)", {
  config_path <- testthat::test_path("..", "..", "inst", "golem-config.yml")
  skip_if_not(file.exists(config_path), "golem-config.yml ikke fundet")

  yaml_content <- yaml::read_yaml(config_path)
  expect_true(
    isTRUE(yaml_content$production$branding$require_branded_assets),
    info = paste(
      "production-profile skal have branding.require_branded_assets: true",
      "for at hard-fail boot uden BFHchartsAssets (Cycle A H2 policy)."
    )
  )
})
