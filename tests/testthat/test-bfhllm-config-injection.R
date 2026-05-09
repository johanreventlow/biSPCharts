# test-bfhllm-config-injection.R
# Cycle A reconciled (Codex 2026-05-09): regression-tests for #H1 + #H1-NEW
#
# Hindrer at:
# 1. get_ai_config() / get_rag_config() reverter til golem::get_golem_options()
#    pattern som ignorerer YAML-profile-overrides
# 2. initialize_bfhllm() bliver fjernet fra app_run.R startup-flow

# Helper: gem + restore golem-config-state mellem tests
with_golem_config_active <- function(profile, code) {
  old <- Sys.getenv("GOLEM_CONFIG_ACTIVE", unset = NA)
  on.exit({
    if (is.na(old)) {
      Sys.unsetenv("GOLEM_CONFIG_ACTIVE")
    } else {
      Sys.setenv(GOLEM_CONFIG_ACTIVE = old)
    }
  })
  Sys.setenv(GOLEM_CONFIG_ACTIVE = profile)
  force(code)
}

test_that("get_ai_config() respekterer development-profile timeout-override", {
  # Forventer at golem-config.yml dev-profile har timeout_seconds = 15
  with_golem_config_active("development", {
    config <- get_ai_config()
    expect_equal(config$timeout_seconds, 15,
      info = "dev-profile burde override default timeout_seconds=10 til 15"
    )
  })
})

test_that("get_ai_config() respekterer production-profile timeout-override", {
  with_golem_config_active("production", {
    config <- get_ai_config()
    expect_equal(config$timeout_seconds, 10,
      info = "prod-profile timeout_seconds = 10"
    )
  })
})

test_that("get_ai_config() falder tilbage til defaults uden golem-context", {
  # Simulér test-context hvor get_golem_config ej er tilgængelig
  with_golem_config_active("nonexistent_profile", {
    config <- get_ai_config()
    expect_true(!is.null(config$timeout_seconds),
      info = "skal returnere defaults, ej crash"
    )
    # NB (Cycle A 2026-05-09): model er bevidst NULL i defaults — biSPCharts
    # foelger BFHllm's default. Verificer at provider-key er sat (fallback-marker).
    expect_equal(config$provider, "gemini",
      info = "provider-key skal eksistere i defaults som fallback-marker"
    )
  })
})

test_that("get_rag_config() respekterer YAML-profile via get_golem_config", {
  with_golem_config_active("development", {
    rag_config <- get_rag_config()
    # Default: enabled=TRUE, n_results=3, method="hybrid"
    # YAML kan overrider; verificer kun at vi returnerer en valid struct
    expect_true(is.list(rag_config))
    expect_true(!is.null(rag_config$n_results))
    expect_true(!is.null(rag_config$method))
  })
})

test_that("initialize_bfhllm() degraderer graciously uden BFHllm", {
  # Hvis BFHllm utilgængelig: returnerer invisible(NULL), ej crash
  if (requireNamespace("BFHllm", quietly = TRUE)) {
    skip("BFHllm installed - cannot test missing-dependency path")
  }
  expect_no_error(initialize_bfhllm())
  expect_null(initialize_bfhllm())
})

test_that("initialize_bfhllm() applier config til BFHllm når tilgængelig", {
  skip_if_not_installed("BFHllm")

  with_golem_config_active("development", {
    config <- get_ai_config()
    # Apply config
    initialize_bfhllm(config)

    # Verificer at BFHllm modtog timeout (model droppes som default-override)
    bfhllm_config <- BFHllm::bfhllm_get_config()
    expect_equal(bfhllm_config$timeout_seconds, config$timeout_seconds,
      info = "BFHllm timeout skal matche biSPCharts config"
    )
    # NB (Cycle A 2026-05-09): model droppes som default-override i biSPCharts.
    # BFHllm bruger sin egen default (Gemini 3.1 Flash-Lite). Hvis golem-config
    # IKKE har eksplicit `model:`, forventer vi at BFHllm-default bruges.
    if (is.null(config$model)) {
      expect_true(!is.null(bfhllm_config$model),
        info = "BFHllm skal bruge sin egen default-model naar biSPCharts ej override'er"
      )
    } else {
      expect_equal(bfhllm_config$model, config$model,
        info = "Eksplicit model i config skal override BFHllm-default"
      )
    }
  })
})

test_that("initialize_bfhllm() respekterer model-override hvis sat eksplicit", {
  skip_if_not_installed("BFHllm")
  custom_config <- list(
    model = "gemini-2.0-flash",
    timeout_seconds = 30,
    max_response_chars = 500
  )
  initialize_bfhllm(custom_config)
  bfhllm_config <- BFHllm::bfhllm_get_config()
  expect_equal(bfhllm_config$model, "gemini-2.0-flash",
    info = "Eksplicit model SHALL override BFHllm-default"
  )
})

test_that("run_app() kalder initialize_bfhllm() i startup-flow", {
  # Statisk verifikation af source-kode (vi vil ikke køre run_app() i test)
  app_run_source <- readLines(testthat::test_path("..", "..", "R", "app_run.R"))
  init_call_present <- any(grepl(
    "initialize_bfhllm\\(get_ai_config\\(\\)\\)",
    app_run_source
  ))
  expect_true(init_call_present,
    info = paste(
      "run_app() skal kalde initialize_bfhllm(get_ai_config()) i startup.",
      "Hvis denne test fejler er Cycle A H1-fix blevet fjernet."
    )
  )
})

test_that("get_ai_config() bruger get_golem_config (ej get_golem_options)", {
  # Statisk verifikation: source skal indeholde get_golem_config-kald
  source_lines <- readLines(testthat::test_path("..", "..", "R", "utils_bfhllm_integration.R"))

  in_get_ai_config <- FALSE
  uses_golem_config <- FALSE
  uses_get_golem_options <- FALSE

  for (line in source_lines) {
    if (grepl("^get_ai_config <- function", line)) {
      in_get_ai_config <- TRUE
      next
    }
    if (in_get_ai_config) {
      if (grepl("^get_rag_config <- function", line)) {
        in_get_ai_config <- FALSE
      }
      # Strip comments foer match-check (kommentarer maa naevne legacy-pattern)
      code_only <- sub("\\s*#.*$", "", line)
      if (grepl("get_golem_config\\(", code_only)) uses_golem_config <- TRUE
      if (grepl("golem::get_golem_options\\(", code_only)) uses_get_golem_options <- TRUE
    }
  }

  expect_true(uses_golem_config,
    info = "get_ai_config skal bruge get_golem_config (YAML-baseret)"
  )
  expect_false(uses_get_golem_options,
    info = paste(
      "get_ai_config maa IKKE bruge golem::get_golem_options.",
      "Cycle A H1-NEW: kun get_golem_config respekterer YAML-profile-overrides."
    )
  )
})
