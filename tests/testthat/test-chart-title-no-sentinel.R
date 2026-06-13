# test-chart-title-no-sentinel.R
# Regression: chart_title() maa IKKE emitte "SPC Analyse"-sentinel ved tom
# indikatortitel. Sentinel'en blev renderet verbatim som ggplot-titel paa
# trin-2-previewet (resolve_bfh_chart_title suppimerer kun "", ikke sentinel).
# Korrekt adfaerd: tom indikatortitel -> "" -> resolve -> NULL -> ingen titel.

# Mock input: chart_title() laeser $indicator_title + (via current_unit)
# $unit_type/$unit_select/$unit_custom gennem input_scalar.
mk_input <- function(indicator = "", unit_type = "custom", unit_custom = "", unit_select = "") {
  list(
    indicator_title = indicator,
    unit_type = unit_type,
    unit_custom = unit_custom,
    unit_select = unit_select
  )
}

eval_title <- function(input) {
  shiny::isolate(chart_title(input)())
}

test_that("tom indikatortitel giver tom streng (ingen sentinel)", {
  skip_if_not_installed("shiny")
  expect_identical(eval_title(mk_input(indicator = "")), "")
})

test_that("tom indikatortitel + valgt enhed giver stadig tom streng", {
  skip_if_not_installed("shiny")
  expect_identical(
    eval_title(mk_input(indicator = "", unit_type = "custom", unit_custom = "Andel")),
    ""
  )
})

test_that("'SPC Analyse'-sentinel emittes aldrig", {
  skip_if_not_installed("shiny")
  expect_false(grepl("SPC Analyse", eval_title(mk_input(indicator = ""))))
  expect_false(grepl(
    "SPC Analyse",
    eval_title(mk_input(indicator = "", unit_type = "custom", unit_custom = "Andel"))
  ))
})

test_that("rigtig indikatortitel bevares (uden enhed)", {
  skip_if_not_installed("shiny")
  expect_identical(eval_title(mk_input(indicator = "Min indikator")), "Min indikator")
})

test_that("rigtig indikatortitel komponeres med enhed", {
  skip_if_not_installed("shiny")
  expect_identical(
    eval_title(mk_input(indicator = "Min indikator", unit_type = "custom", unit_custom = "Andel")),
    "Min indikator - Andel"
  )
})
