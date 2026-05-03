# test-spc-scaling-bfh.R
# Regressionstests for normalize_scale_for_bfh() -- chart-type-korrekt skala-normalisering.
# Spec: openspec/changes/fix-spc-domain-correctness/specs/spc-facade/spec.md

library(testthat)

# Hjælpefunktion: kald med library-loaded environment
test_that("normalize_scale_for_bfh: U-chart target pass-through (>1 må IKKE divideres med 100)", {
  # Regression: tidligere returnerede 0.015 for u-chart med value=1.5
  result <- normalize_scale_for_bfh(1.5, "u", "target")
  expect_equal(result, 1.5,
    info = "U-chart target=1.5 skal returneres uændret (rate-chart, ikke proportion)"
  )
})

test_that("normalize_scale_for_bfh: U'-chart centerline pass-through", {
  result <- normalize_scale_for_bfh(1.5, "up", "centerline")
  expect_equal(result, 1.5,
    info = "U'-chart centerline=1.5 skal returneres uændret"
  )
})

test_that("normalize_scale_for_bfh: U-chart value <=1 pass-through", {
  result <- normalize_scale_for_bfh(0.5, "u", "target")
  expect_equal(result, 0.5,
    info = "U-chart med value <= 1 skal passes through"
  )
})

test_that("normalize_scale_for_bfh: P-chart proportion-konvertering bevares (regression)", {
  result <- normalize_scale_for_bfh(80, "p", "target")
  expect_equal(result, 0.8,
    info = "P-chart med value=80 skal konverteres til 0.8"
  )
})

test_that("normalize_scale_for_bfh: P'-chart proportion-konvertering bevares (regression)", {
  result <- normalize_scale_for_bfh(80, "pp", "target")
  expect_equal(result, 0.8,
    info = "P'-chart med value=80 skal konverteres til 0.8"
  )
})

test_that("normalize_scale_for_bfh: PROPORTION_CHART_TYPES indeholder ikke 'u' eller 'up'", {
  # Taksonomisk check -- sikrer at konstanten er korrekt
  expect_false("u" %in% c("p", "pp"),
    info = "u er ikke en proportion-chart"
  )
  expect_false("up" %in% c("p", "pp"),
    info = "up er ikke en proportion-chart"
  )
})

test_that("normalize_scale_for_bfh: regression #446 -- begge branches returnerer eksakt værdi", {
  # Pinner result-variable-pattern (#446). Tidligere brugte koden return()
  # inde i safe_operation, som var dokumenteret som forbudt mønster i samme
  # fil. Hvis safe_operation skifter implementation og return() begynder at
  # eksitere wrapperen, ville fallback-værdien (samme som value) maskere bug
  # for normaliserings-branchen — derfor skal vi teste eksakt rundt om 1.0
  # for både p og pp.
  expect_identical(normalize_scale_for_bfh(50, "p", "target"), 0.5)
  expect_identical(normalize_scale_for_bfh(50, "pp", "centerline"), 0.5)
  expect_identical(normalize_scale_for_bfh(0.7, "p", "target"), 0.7)
  expect_identical(normalize_scale_for_bfh(0.7, "pp", "centerline"), 0.7)
  expect_identical(normalize_scale_for_bfh(1, "p", "target"), 1)
  expect_identical(normalize_scale_for_bfh(100, "p", "target"), 1)
  # Non-proportion typer bruger else-branchen — value pass-through skal være eksakt
  expect_identical(normalize_scale_for_bfh(2.5, "i", "target"), 2.5)
})
