# Tests for config_chart_type_groups.R (grupperet diagramtype-dropdown)

# build_grouped_chart_choices() ------------------------------------------------

test_that("build_grouped_chart_choices returnerer tre grupper", {
  g <- build_grouped_chart_choices()
  expect_named(g, c("Standardvalg", "Udvidede kontrolkortvalg", "Avanceret kontrolkortvalg"))
})

test_that("build_grouped_chart_choices har 16 valg fordelt 2/4/10", {
  g <- build_grouped_chart_choices()
  expect_equal(lengths(g, use.names = FALSE), c(2L, 4L, 10L))
  expect_equal(sum(lengths(g)), 16L)
})

test_that("alle option-values resolver til gyldige qic-koder", {
  g <- build_grouped_chart_choices()
  values <- unlist(g, use.names = FALSE)
  resolved <- vapply(values, get_qic_chart_type, character(1))
  expect_true(all(resolved %in% SUPPORTED_CHART_TYPES_BFH))
})

# Alias-resolution -------------------------------------------------------------

test_that("alias-values stripper korrekt til ren qic-kode", {
  expect_equal(get_qic_chart_type("ip__ctrl"), "ip")
  expect_equal(get_qic_chart_type("ip__dt"), "ip")
  expect_equal(get_qic_chart_type("pp__dt"), "pp")
  expect_equal(get_qic_chart_type("up__dt"), "up")
  expect_equal(get_qic_chart_type("c__dt"), "c")
})

test_that("rene koder uden alias er upaavirkede af strip", {
  for (code in c("run", "i", "ip", "p", "pp", "u", "up", "c", "mr", "g", "t")) {
    expect_equal(get_qic_chart_type(code), code)
  }
})

test_that("requires_denominator er korrekt gennem alias", {
  expect_true(chart_type_requires_denominator("ip__ctrl")) # ip
  expect_true(chart_type_requires_denominator("ip__dt")) # ip
  expect_true(chart_type_requires_denominator("pp__dt")) # pp
  expect_true(chart_type_requires_denominator("up__dt")) # up
  expect_false(chart_type_requires_denominator("c__dt")) # c bruger ingen naevner
})

# Gruppe-indhold ---------------------------------------------------------------

test_that("Standardvalg indeholder run + ip (via alias)", {
  std <- build_grouped_chart_choices()[["Standardvalg"]]
  resolved <- vapply(unlist(std, use.names = FALSE), get_qic_chart_type, character(1))
  expect_setequal(unname(resolved), c("run", "ip"))
})

test_that("Avanceret-gruppen daekker alle eksponerede korttyper inkl. g/t", {
  adv <- build_grouped_chart_choices()[["Avanceret kontrolkortvalg"]]
  expect_setequal(
    unlist(adv, use.names = FALSE),
    c("i", "ip", "p", "pp", "u", "up", "c", "mr", "g", "t")
  )
})
