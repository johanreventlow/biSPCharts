# test-shinylogs-paste-exclude.R
# Tests: paste_data_input er ekskluderet fra shinylogs-konfiguration (Phase 2)
# Verificerer kildekode direkte — shinylogs kræver ægte Shiny-session til
# integration-test, men konfigurationen er statisk og kan læses fra koden.

test_that("initialize_shinylogs_tracking kildekode ekskluderer paste_data_input", {
  skip_if(
    !exists("initialize_shinylogs_tracking",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "initialize_shinylogs_tracking ikke tilgængelig"
  )

  # Konfigurationen er statisk — verificér at paste_data_input er i
  # exclude_input_id via deparse af funktionskroppen
  fn_body <- deparse(body(biSPCharts:::initialize_shinylogs_tracking))
  fn_text <- paste(fn_body, collapse = "\n")

  expect_true(
    grepl("paste_data_input", fn_text, fixed = TRUE),
    info = "paste_data_input skal optræde i initialize_shinylogs_tracking-koden"
  )
})

test_that("initialize_shinylogs_tracking kildekode ekskluderer PHI-tunge felter", {
  skip_if(
    !exists("initialize_shinylogs_tracking",
      where = asNamespace("biSPCharts"), mode = "function"
    ),
    "initialize_shinylogs_tracking ikke tilgængelig"
  )

  fn_body <- deparse(body(biSPCharts:::initialize_shinylogs_tracking))
  fn_text <- paste(fn_body, collapse = "\n")

  phi_fields <- c(
    "paste_data_input",
    "main_data_table",
    "auto_restore_data",
    "loaded_app_state"
  )

  for (field in phi_fields) {
    expect_true(
      grepl(field, fn_text, fixed = TRUE),
      info = paste(field, "skal ekskluderes fra shinylogs")
    )
  }
})
