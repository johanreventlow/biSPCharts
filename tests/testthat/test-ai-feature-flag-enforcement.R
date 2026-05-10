# test-ai-feature-flag-enforcement.R
# Cycle G H_NEW (2026-05-09): regression-tests for explicit ai.enabled-flag
# enforcement i alle AI-egress-paths.
#
# Pre-fix: ai.enabled-flag eksisterede i golem-config.yml men checkes IKKE
# i nogen AI-egress-path (initialize_bfhllm, register_ai_button_state,
# click handler). Disable opnaaedes via fragile combo: hidden CSS + missing
# API key + missing data_consent.
#
# Post-fix: ai.enabled enforcs i:
#   - get_ai_config() defaults til FALSE (fail-closed)
#   - get_rag_config() defaults til FALSE (fail-closed)
#   - register_ai_button_state(): shinyjs::hide() hvis FALSE
#   - register_ai_suggestion_handler(): req() guard hvis FALSE
#   - production-config har enabled=false (eksplicit kill-switch)

test_that("get_ai_config() defaults til enabled=FALSE (fail-closed)", {
  require_internal("get_ai_config", mode = "function")
  body_text <- paste(deparse(body(get_ai_config)), collapse = "\n")
  # Defaults-list skal eksplicit have enabled = FALSE
  expect_true(
    grepl("enabled\\s*=\\s*FALSE", body_text),
    info = "get_ai_config() defaults skal have enabled=FALSE for fail-closed-design"
  )
})

test_that("get_rag_config() defaults til enabled=FALSE (fail-closed)", {
  require_internal("get_rag_config", mode = "function")
  body_text <- paste(deparse(body(get_rag_config)), collapse = "\n")
  expect_true(
    grepl("enabled\\s*=\\s*FALSE", body_text),
    info = "get_rag_config() defaults skal have enabled=FALSE for fail-closed-design"
  )
})

test_that("register_ai_button_state() checker get_ai_config()$enabled", {
  require_internal("register_ai_button_state", mode = "function")
  body_text <- paste(deparse(body(register_ai_button_state)), collapse = "\n")
  expect_true(
    grepl("get_ai_config\\(\\)\\$enabled", body_text),
    info = "register_ai_button_state() skal checke get_ai_config()$enabled flag"
  )
  # Verificér hide-call ved disabled-state
  expect_true(
    grepl("shinyjs::hide\\(.*ai_generate_suggestion", body_text),
    info = "register_ai_button_state() skal kalde shinyjs::hide() naar ai disabled"
  )
})

test_that("register_ai_suggestion_handler() har enabled-guard via req()", {
  require_internal("register_ai_suggestion_handler", mode = "function")
  body_text <- paste(deparse(body(register_ai_suggestion_handler)), collapse = "\n")
  expect_true(
    grepl("req\\(.*get_ai_config\\(\\)\\$enabled", body_text),
    info = paste(
      "register_ai_suggestion_handler() skal bruge req(isTRUE(get_ai_config()$enabled))",
      "som server-side defense-in-depth mod UI-bypass."
    )
  )
})

test_that("production-config har ai.enabled=false (eksplicit kill-switch)", {
  config_path <- testthat::test_path("..", "..", "inst", "golem-config.yml")
  skip_if_not(file.exists(config_path), "golem-config.yml ikke fundet")

  yaml_content <- yaml::read_yaml(config_path)
  expect_false(
    isTRUE(yaml_content$production$ai$enabled),
    info = paste(
      "production-profile skal have ai.enabled=false. AI-feature er bevidst",
      "hidden foreloebig (Cycle G H_NEW). Re-enable kraever H0+H3-fix foerst."
    )
  )
})

test_that("production-config har ai.rag.enabled=false (kobles til ai)", {
  config_path <- testthat::test_path("..", "..", "inst", "golem-config.yml")
  skip_if_not(file.exists(config_path), "golem-config.yml ikke fundet")

  yaml_content <- yaml::read_yaml(config_path)
  expect_false(
    isTRUE(yaml_content$production$ai$rag$enabled),
    info = "RAG uden AI er meningsloest -> RAG skal ogsaa vaere disabled i prod"
  )
})

test_that("UI har ej laengere fragile CSS display:none-hide paa AI-knap", {
  ui_path <- testthat::test_path("..", "..", "R", "mod_export_ui.R")
  skip_if_not(file.exists(ui_path), "mod_export_ui.R ikke fundet")

  # Lokal source-tree-test fordi UI-funktioner producerer tags-objekter
  # der ikke nemt kan introspekteres via body() for CSS-attributter.
  # nolint start: no_test_source_read_linter
  ui_text <- paste(readLines(ui_path, warn = FALSE), collapse = "\n")
  # nolint end

  # Find ai_generate_suggestion-button-blokken; verificer ej omgivet af
  # display:none paa parent-div. Letteste: tjek at strengen
  # "display: none;" ikke staar tæt paa ai_generate_suggestion-referencen.
  ai_block_start <- regexpr("ai_generate_suggestion", ui_text)
  if (ai_block_start[1] > 0) {
    # Tjek 200 tegn FOER ai_generate_suggestion for display:none-attribut
    look_back_start <- max(1, ai_block_start[1] - 200)
    nearby_text <- substring(ui_text, look_back_start, ai_block_start[1])
    expect_false(
      grepl('style\\s*=\\s*"display:\\s*none', nearby_text),
      info = paste(
        "AI-knap har stadig display:none-CSS-hide. Cycle G H_NEW",
        "fjernede dette til fordel for ai.enabled-flag-enforcement."
      )
    )
  }
})
