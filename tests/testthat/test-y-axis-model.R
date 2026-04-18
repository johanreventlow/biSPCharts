test_that("UI-typer mapper korrekt til interne klasser", {
  # TAL → COUNT hvis heltal ≥ 0, ellers MEASUREMENT
  y_int <- c(0, 1, 2, 10)
  y_dec <- c(1.2, 2.5, 3.0)
  expect_equal(determine_internal_class("count", y_int, n_present = FALSE), "COUNT")
  expect_equal(determine_internal_class("count", y_dec, n_present = FALSE), "MEASUREMENT")

  # PROCENT → PROPORTION (kræver n)
  expect_equal(determine_internal_class("percent", c(80, 90), n_present = TRUE), "PROPORTION")
  expect_equal(determine_internal_class("percent", c(0.8, 0.9), n_present = TRUE), "PROPORTION")

  # RATE → RATE_INTERNAL (kræver n som exposure)
  expect_equal(determine_internal_class("rate", c(1, 3), n_present = TRUE), "RATE_INTERNAL")

  # TID → TIME_BETWEEN
  expect_equal(determine_internal_class("time", c(1, 5, 3), n_present = FALSE), "TIME_BETWEEN")
})

test_that("Kortvalg mapper korrekt fra intern klasse", {
  expect_equal(suggest_chart_type("MEASUREMENT", n_present = FALSE, n_points = 20), "i")
  expect_equal(suggest_chart_type("COUNT", n_present = FALSE, n_points = 20), "c")
  expect_equal(suggest_chart_type("PROPORTION", n_present = TRUE, n_points = 20), "p")
  expect_equal(suggest_chart_type("RATE_INTERNAL", n_present = TRUE, n_points = 20), "u")
  expect_equal(suggest_chart_type("TIME_BETWEEN", n_present = FALSE, n_points = 20), "t")
  expect_equal(suggest_chart_type("COUNT_BETWEEN", n_present = FALSE, n_points = 20), "g")

  # Run chart for små serier
  expect_equal(suggest_chart_type("MEASUREMENT", n_present = FALSE, n_points = 8), "run")
})

test_that("Default Y-akse UI-type for run chart", {
  expect_equal(decide_default_y_axis_ui_type("run", n_present = TRUE), "percent")
  expect_equal(decide_default_y_axis_ui_type("run", n_present = FALSE), "count")
  expect_equal(decide_default_y_axis_ui_type("p", n_present = TRUE), "count")
})

test_that("is_time_unit identificerer alle tids-enheder (inkl. legacy)", {
  # Legacy
  expect_true(is_time_unit("time"))
  # Nye enheder
  expect_true(is_time_unit("time_minutes"))
  expect_true(is_time_unit("time_hours"))
  expect_true(is_time_unit("time_days"))
  # Ikke-tids-enheder
  expect_false(is_time_unit("count"))
  expect_false(is_time_unit("percent"))
  expect_false(is_time_unit("rate"))
  # Edge cases
  expect_equal(is_time_unit(NULL), logical(0))
  expect_false(is_time_unit(NA_character_))
  expect_false(is_time_unit(""))
})

test_that("determine_internal_class bruger is_time_unit for alle tids-enheder", {
  expect_equal(determine_internal_class("time", y = c(1, 2, 3)), "TIME_BETWEEN")
  expect_equal(determine_internal_class("time_minutes", y = c(30, 60)), "TIME_BETWEEN")
  expect_equal(determine_internal_class("time_hours", y = c(1.5, 2)), "TIME_BETWEEN")
  expect_equal(determine_internal_class("time_days", y = c(1, 2)), "TIME_BETWEEN")
})

test_that("chart_type_to_ui_type returnerer time_days for t-kort", {
  expect_equal(chart_type_to_ui_type("t"), "time_days")
})
