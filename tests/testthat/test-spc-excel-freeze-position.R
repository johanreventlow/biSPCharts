# test-spc-excel-freeze-position.R
# Cycle C H1 (Codex 2026-05-10): regression-tests for freeze_position
# extraction i SPC-analyse-arket.
#
# Pre-fix: spc_save_content() byggede analysis_options uden freeze_position.
# build_spc_analysis_sheet defaulter til NULL -> Sektion A 'Frozen til
# raekke' altid tomt. Spec-divergens (openspec/specs/excel-spc-analysis-
# sheet/spec.md:51 SHALL angive 'Frozen til raekke').
#
# Post-fix: spc_save_content kalder extract_freeze_position(data,
# metadata\$frys_column) og passerer til analysis_options.

test_that("spc_save_content body kalder extract_freeze_position", {
  # Body-introspection (R CMD check sikker) — verificer at fix-kald
  # eksisterer i save-content-kroppen. spc_save_content er defineret som
  # nested function inde i setup_wizard_gates, saa vi tjekker via
  # deparse paa parent-funktionen.
  require_internal("setup_wizard_gates", mode = "function")
  body_text <- paste(deparse(body(setup_wizard_gates)), collapse = "\n")
  expect_true(
    grepl("extract_freeze_position", body_text),
    info = "setup_wizard_gates skal kalde extract_freeze_position i spc_save_content"
  )
  expect_true(
    grepl("freeze_position\\s*=\\s*freeze_position", body_text),
    info = "analysis_options skal inkludere freeze_position-feltet"
  )
})

test_that("extract_freeze_position returnerer NULL hvis ingen frys_column", {
  require_internal("extract_freeze_position", mode = "function")
  data <- data.frame(date = 1:5, value = 1:5)
  expect_null(extract_freeze_position(data, NULL))
  expect_null(extract_freeze_position(data, ""))
})

test_that("extract_freeze_position returnerer raekke-indeks ved frys-markering", {
  require_internal("extract_freeze_position", mode = "function")
  data <- data.frame(
    date = 1:5,
    value = 1:5,
    Frys = c(FALSE, FALSE, TRUE, FALSE, FALSE)
  )
  result <- extract_freeze_position(data, "Frys")
  expect_equal(result, 3L)
})

test_that("build_spc_analysis_sheet accepterer freeze_position via options", {
  require_internal("build_spc_analysis_sheet", mode = "function")
  formals_list <- formals(build_spc_analysis_sheet)
  expect_true(
    "options" %in% names(formals_list),
    info = "build_spc_analysis_sheet skal acceptere options-parameter"
  )

  # Body-check: options$freeze_position bruges
  body_text <- paste(deparse(body(build_spc_analysis_sheet)), collapse = "\n")
  expect_true(
    grepl("options\\$freeze_position", body_text),
    info = "build_spc_analysis_sheet skal extracte options$freeze_position"
  )
})
