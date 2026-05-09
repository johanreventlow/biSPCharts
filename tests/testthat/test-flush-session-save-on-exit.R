# test-flush-session-save-on-exit.R
# Cycle B M7 (Codex 2026-05-09): regression-test for save_session_on_exit
# config-flag respekteres ved session-end.

test_that("flush_session_save_on_exit eksisterer som funktion", {
  expect_true(exists("flush_session_save_on_exit", mode = "function"))
})

test_that("flush_session_save_on_exit kaldes fra app_server_main session-end", {
  # Funktionel introspection: tjek at session-end handler kalder funktionen
  app_server_main_source <- readLines(
    testthat::test_path("..", "..", "R", "app_server_main.R")
  )
  flush_call_present <- any(grepl(
    "flush_session_save_on_exit\\(session, input, app_state\\)",
    app_server_main_source
  ))
  expect_true(
    flush_call_present,
    info = paste(
      "app_server_main.R skal kalde flush_session_save_on_exit() i",
      "session$onSessionEnded() handler. Hvis denne test fejler er",
      "Cycle B M7-fix blevet fjernet og persistence-contract brudt igen."
    )
  )
})

test_that("flush_session_save_on_exit respekterer save_session_on_exit-flag", {
  require_internal("flush_session_save_on_exit", mode = "function")

  # Verificer body indeholder config-gate
  body_text <- paste(deparse(body(flush_session_save_on_exit)), collapse = "\n")
  expect_true(
    grepl("save_session_on_exit", body_text),
    info = "flush_session_save_on_exit skal gate paa save_session_on_exit-config"
  )
  expect_true(
    grepl("get_session_config", body_text),
    info = "flush skal bruge get_session_config() til config-lookup (matcher session-helpers-mønster)"
  )
})

test_that("flush_session_save_on_exit har auto_save_enabled + restoring_session guards", {
  require_internal("flush_session_save_on_exit", mode = "function")
  body_text <- paste(deparse(body(flush_session_save_on_exit)), collapse = "\n")

  expect_true(
    grepl("auto_save_enabled", body_text),
    info = "flush skal respektere auto_save_enabled-flag som debounced auto-save"
  )
  expect_true(
    grepl("restoring_session", body_text),
    info = "flush skal skip naar restore stadig koerer (forhindrer overskriv af restored state)"
  )
})

test_that("production-config har save_session_on_exit: true (regression-guard)", {
  config_path <- testthat::test_path("..", "..", "inst", "golem-config.yml")
  skip_if_not(file.exists(config_path), "golem-config.yml ikke fundet")

  yaml_content <- yaml::read_yaml(config_path)
  expect_true(
    isTRUE(yaml_content$production$session$save_session_on_exit),
    info = paste(
      "production-profile skal have session.save_session_on_exit: true.",
      "Cycle B M7: persistence-contract kraever final-flush ved session-end."
    )
  )
})
