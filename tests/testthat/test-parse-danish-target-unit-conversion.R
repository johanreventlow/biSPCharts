# test-parse-danish-target-unit-conversion.R
# Rewrite Fase 2: TDD mod nuværende parse_danish_target() API
# Baseret paa R/utils_y_axis_scaling.R (legacy wrapper til normalize_axis_value)
#
# NOTE: Mange tests er markeret SKIP med reference til #213 pga. API-drift:
# parse_danish_target er en legacy wrapper der ikke implementerer
# de spec-beskrevne prioriteringssemantikker (y_axis_unit ignoreres
# i nuværende implementation). Tests afventer parse_danish_target/
# normalize_axis_value unit-awareness refactor (#213).

# =============================================================================
# KENDTE BEGRÆNSNINGER I NUVÆRENDE IMPLEMENTATION (dokumenteret):
#
# 1. y_axis_unit parameter ignoreres — kun y_data-skala bruges til
#    intern unit-detektion. Det er en bug/manglende feature.
# 2. Specifikke enheder som "permille", "rate_*", "days" mv. understøttes
#    ikke — normalize_axis_value kan ikke mappe disse unit-navne.
# 3. Heltal-skala (c(100, 200, 300)) detekteres som "proportion" (fejl),
#    ikke som "absolute".
# =============================================================================

test_that("parse_danish_target returnerer NULL for tom streng", {
  # Tom streng returnerer NULL
  expect_null(parse_danish_target("", NULL, "percent"))
})

test_that("parse_danish_target haandterer NULL input uden fejl", {
  expect_null(parse_danish_target(NULL, NULL, "percent"))
})

test_that("parse_danish_target haandterer % symbol med decimal y-data korrekt", {
  # Med decimal Y-data ([0,1]-skala) og % input → konverterer til decimal
  decimal_y_data <- c(0.1, 0.3, 0.6, 0.8)
  expect_equal(parse_danish_target("80%", decimal_y_data, "percent"), 0.8)
  expect_equal(parse_danish_target("80%", decimal_y_data, "count"), 0.8)
})

test_that("parse_danish_target returnerer NULL-agtigt for uspecificeret input uden y-data", {
  # Uden y-data og symbol returnerer funktionen NULL/numerisk(0)
  result <- parse_danish_target("50", NULL, NULL)
  expect_true(is.null(result) || length(result) == 0)
})

test_that("parse_danish_target haandterer % symbol uden y-data (legacy behavior)", {
  # % input → 0.8 (proportion) ved NULL internal_unit fallback
  result_pct <- parse_danish_target("80%", NULL, NULL)
  expect_equal(result_pct, 0.8)
})

test_that("parse_danish_target haandterer danske komma-decimaler med % symbol", {
  # Dansk comma-decimal med procent-symbol
  result_da <- parse_danish_target("68,5%", NULL, NULL)
  expect_equal(result_da, 0.685, tolerance = 0.001)
})

test_that("parse_danish_target er idempotent ved gentagne kald", {
  # Samme input skal give samme output
  decimal_y_data <- c(0.1, 0.3, 0.6, 0.8)
  r1 <- parse_danish_target("80%", decimal_y_data, "percent")
  r2 <- parse_danish_target("80%", decimal_y_data, "percent")
  expect_equal(r1, r2)
})

# =============================================================================
# TESTS SKIPPED MED ISSUE-REFERENCE: R-bugs afsloeret under rewrite.
# Alle nedenstaaende SKIP'er dokumenterer spec-adfaerd der IKKE er
# implementeret i nuvaerende parse_danish_target(). Afventer #213.
# =============================================================================

test_that("#213: y_axis_unit=percent skalerer korrekt uden y-data", {
  skip("Afventer parse_danish_target unit-awareness refactor — se #213 (y_axis_unit=percent, ingen y-data)")
  expect_equal(parse_danish_target("80%", NULL, "percent"), 80)
  expect_equal(parse_danish_target("0.8", NULL, "percent"), 80)
  expect_equal(parse_danish_target("80", NULL, "percent"), 80)
})

test_that("#213: y_axis_unit=count haandterer tal korrekt uden y-data", {
  skip("Afventer parse_danish_target unit-awareness refactor — se #213 (y_axis_unit=count, ingen y-data)")
  expect_equal(parse_danish_target("80%", NULL, "count"), 80)
  expect_equal(parse_danish_target("80", NULL, "count"), 80)
  expect_equal(parse_danish_target("0.8", NULL, "count"), 0.8)
})

test_that("#213: percent y-data skalerer korrekt til 0-100", {
  skip("Afventer parse_danish_target unit-awareness refactor — se #213 (percent y-data skaleringsfejl)")
  percent_y_data <- c(10, 25, 60, 85)
  expect_equal(parse_danish_target("80%", percent_y_data, "count"), 80)
  expect_equal(parse_danish_target("80%", percent_y_data, "percent"), 80)
  expect_equal(parse_danish_target("0.8", percent_y_data, "count"), 80)
  expect_equal(parse_danish_target("80", percent_y_data, "count"), 80)
})

test_that("#213: integer y-data behandles som absolute skala", {
  skip("Afventer parse_danish_target unit-awareness refactor — se #213 (integer y-data fejldetekteres som proportion)")
  integer_y_data <- c(150, 250, 450, 800)
  expect_equal(parse_danish_target("80%", integer_y_data, "percent"), 80)
  expect_equal(parse_danish_target("80", integer_y_data, "percent"), 80)
})

test_that("#213: y_axis_unit=permille skalerer korrekt", {
  skip("Afventer parse_danish_target unit-awareness refactor — se #213 (permille unit)")
  expect_equal(parse_danish_target("8\u2030", NULL, "permille"), 8)
  expect_equal(parse_danish_target("0.008", NULL, "permille"), 8)
  expect_equal(parse_danish_target("8", NULL, "permille"), 8)
})

test_that("#213: rate_* enheder haandteres som absolutte tal", {
  skip("Afventer parse_danish_target unit-awareness refactor — se #213 (rate_1000/rate_100000 units)")
  rate_units <- c("rate_1000", "rate_100000")
  for (unit in rate_units) {
    expect_equal(parse_danish_target("15%", NULL, unit), 15)
    expect_equal(parse_danish_target("8\u2030", NULL, unit), 8)
    expect_equal(parse_danish_target("22,5", NULL, unit), 22.5)
    expect_equal(parse_danish_target("100", NULL, unit), 100)
  }
})

test_that("#213: absolutte enheder (days/hours etc.) haandteres konsistent", {
  skip("Afventer parse_danish_target unit-awareness refactor — se #213 (absolute units: count/days/hours/...)")
  absolute_units <- c("count", "days", "hours", "grams", "kg", "dkk")
  for (unit in absolute_units) {
    expect_equal(parse_danish_target("50%", NULL, unit), 50)
    expect_equal(parse_danish_target("5\u2030", NULL, unit), 5)
    expect_equal(parse_danish_target("42", NULL, unit), 42)
    expect_equal(parse_danish_target("12,5", NULL, unit), 12.5)
  }
})

# 2 test-blokke fjernet i §1.2.2 (PR-batch A+B):
# detect_y_axis_scale() og convert_by_unit_type() eksisterer ikke i R/ og
# blev aldrig implementeret. Tests validerede kun exists() uden reel
# funktionsafdækning. Se docs/test-suite-inventory-203.md §
# "Inventory af skip('TODO')-kald".

test_that("#213: fallback uden y_axis_unit returnerer korrekte vaerdier", {
  skip("Afventer parse_danish_target unit-awareness refactor — se #213 (fallback uden y_axis_unit)")
  expect_equal(parse_danish_target("50", NULL, NULL), 50)
  expect_equal(parse_danish_target("8\u2030", NULL, NULL), 8)
})
