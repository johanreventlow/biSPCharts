# test-run-chart-taxonomy.R
# Tests for run-chart y-aksel taksonomi.
# Spec: openspec/changes/fix-spc-domain-correctness/specs/domain-core/spec.md

library(testthat)

test_that("PROPORTION_CHART_TYPES indeholder ikke 'run'", {
  expect_false("run" %in% PROPORTION_CHART_TYPES,
    info = "Run-chart er ikke en proportion-chart -- fjernet fra PROPORTION_CHART_TYPES"
  )
})

test_that("PROPORTION_CHART_TYPES indeholder p og pp", {
  expect_true("p" %in% PROPORTION_CHART_TYPES)
  expect_true("pp" %in% PROPORTION_CHART_TYPES)
})

test_that("determine_internal_unit_by_chart_type('run') er ikke 'proportion'", {
  result <- determine_internal_unit_by_chart_type("run")
  expect_false(identical(result, "proportion"),
    info = "run-chart må ikke hardcodes til proportion-enhed"
  )
})
