# test-y-axis-scaling-overhaul.R
# Comprehensive test suite for the Y-axis API
# Merged Fase 2: test-y-axis-mapping.R + test-y-axis-model.R +
#               test-y-axis-formatting.R -> test-y-axis-scaling-overhaul.R
# Se NEWS.md for rationale.

library(testthat)
library(ggplot2)

# =============================================================================
# SEKTION 1: SCALING API (fra test-y-axis-scaling-overhaul.R originalt)
# Tests the 3-layer architecture: Parsing → Unit Clarification → Conversion
# =============================================================================

# LAYER 1: PARSING TESTS -------------------------------------------------------

test_that("parse_number_da correctly parses Danish numbers with symbols", {

  # Basic symbol detection
  expect_equal(parse_number_da("80%"), list(value = 80, symbol = "percent"))
  expect_equal(parse_number_da("8\u2030"), list(value = 8, symbol = "permille"))
  expect_equal(parse_number_da("80"), list(value = 80, symbol = "none"))

  # Danish comma decimals
  expect_equal(parse_number_da("68,5%"), list(value = 68.5, symbol = "percent"))
  expect_equal(parse_number_da("3,14"), list(value = 3.14, symbol = "none"))
  expect_equal(parse_number_da("0,85"), list(value = 0.85, symbol = "none"))

  # Whitespace handling
  expect_equal(parse_number_da(" 80% "), list(value = 80, symbol = "percent"))
  expect_equal(parse_number_da("80 %"), list(value = 80, symbol = "percent"))

  # Edge cases
  expect_equal(parse_number_da(""), list(value = NA_real_, symbol = "none"))
  expect_equal(parse_number_da(NULL), list(value = numeric(0), symbol = character(0)))
  expect_equal(parse_number_da("80%\u2030"), list(value = NA_real_, symbol = "invalid"))  # Begge symboler

})

test_that("parse_number_da is idempotent", {

  # Same input should give same output on repeated calls
  input1 <- "68,5%"
  result1a <- parse_number_da(input1)
  result1b <- parse_number_da(input1)
  expect_identical(result1a, result1b)

  input2 <- "0,85"
  result2a <- parse_number_da(input2)
  result2b <- parse_number_da(input2)
  expect_identical(result2a, result2b)

})

test_that("parse_number_da handles vectors correctly", {

  # Vector input should return vector output
  inputs <- c("80%", "8\u2030", "75")
  result <- parse_number_da(inputs)

  expect_equal(result$value, c(80, 8, 75))
  expect_equal(result$symbol, c("percent", "permille", "none"))

})

# LAYER 2: UNIT CLARIFICATION TESTS --------------------------------------------

test_that("resolve_y_unit follows correct priority order", {
  skip("Afventer y-axis unit-detection fix — se #243 (resolve_y_unit percent)")

  # Priority 1: User explicit choice overrides everything
  expect_equal(resolve_y_unit(user_unit = "percent", col_unit = "proportion", y_sample = c(0.1, 0.2)), "percent")

  # Priority 2: Column metadata when no user choice
  expect_equal(resolve_y_unit(user_unit = NULL, col_unit = "permille", y_sample = c(0.1, 0.2)), "permille")

  # Priority 3: Data heuristics when no explicit choices
  decimal_data <- c(0.1, 0.2, 0.3, 0.8)
  expect_equal(resolve_y_unit(user_unit = NULL, col_unit = NULL, y_sample = decimal_data), "proportion")

  percent_data <- c(10, 20, 30, 80)
  expect_equal(resolve_y_unit(user_unit = NULL, col_unit = NULL, y_sample = percent_data), "percent")

  # Priority 4: Fallback to absolute
  expect_equal(resolve_y_unit(user_unit = NULL, col_unit = NULL, y_sample = NULL), "absolute")

})

test_that("detect_unit_from_data uses clear heuristics", {
  skip("Afventer y-axis unit-detection fix — se #243 (detect_unit_from_data percent)")

  # Decimal detection [0,1] with decimals
  decimal_data1 <- c(0.1, 0.3, 0.6, 0.8)
  expect_equal(detect_unit_from_data(decimal_data1), "proportion")

  # Decimal detection [0,1] even with integers (80% in range)
  decimal_data2 <- c(0, 0, 1, 1)
  expect_equal(detect_unit_from_data(decimal_data2), "proportion")

  # Percent detection [0-100] with whole numbers
  percent_data <- c(10, 25, 50, 85)
  expect_equal(detect_unit_from_data(percent_data), "percent")

  # Should NOT detect percent when too many decimals
  mixed_percent <- c(10.5, 25.3, 45.7, 60.2, 85.9)
  expect_equal(detect_unit_from_data(mixed_percent), "absolute")

  # Large numbers → absolute
  large_data <- c(150, 250, 450, 800)
  expect_equal(detect_unit_from_data(large_data), "absolute")

  # Empty/NA data → absolute
  expect_equal(detect_unit_from_data(c()), "absolute")
  expect_equal(detect_unit_from_data(c(NA, NA)), "absolute")

})

# LAYER 3A: HARMONIZATION TESTS ------------------------------------------------

test_that("coerce_to_target_unit uses deterministic conversion matrix", {

  # TO PROPORTION
  expect_equal(coerce_to_target_unit(list(value = 80, symbol = "percent"), "proportion"), 0.8)
  expect_equal(coerce_to_target_unit(list(value = 8, symbol = "permille"), "proportion"), 0.008)
  expect_equal(coerce_to_target_unit(list(value = 0.8, symbol = "none"), "proportion"), 0.8)  # No implicit scaling

  # TO PERCENT
  expect_equal(coerce_to_target_unit(list(value = 80, symbol = "percent"), "percent"), 80)
  expect_equal(coerce_to_target_unit(list(value = 80, symbol = "permille"), "percent"), 8)
  expect_equal(coerce_to_target_unit(list(value = 80, symbol = "none"), "percent"), 80)  # No implicit scaling

  # TO PERMILLE
  expect_equal(coerce_to_target_unit(list(value = 8, symbol = "percent"), "permille"), 80)
  expect_equal(coerce_to_target_unit(list(value = 80, symbol = "permille"), "permille"), 80)
  expect_equal(coerce_to_target_unit(list(value = 80, symbol = "none"), "permille"), 80)  # No implicit scaling

  # TO ABSOLUTE
  expect_equal(coerce_to_target_unit(list(value = 80, symbol = "percent"), "absolute"), 80)
  expect_equal(coerce_to_target_unit(list(value = 8, symbol = "permille"), "absolute"), 8)
  expect_equal(coerce_to_target_unit(list(value = 50, symbol = "none"), "absolute"), 50)

})

test_that("coerce_to_target_unit handles edge cases", {

  # Invalid input
  expect_true(is.na(coerce_to_target_unit(list(value = NA, symbol = "percent"), "proportion")))
  expect_true(is.na(coerce_to_target_unit(list(value = 80, symbol = "invalid"), "proportion")))

  # Unknown target unit
  expect_true(is.na(coerce_to_target_unit(list(value = 80, symbol = "percent"), "unknown")))

})

# LAYER 3B: INTERNAL CONVERSION TESTS ------------------------------------------

test_that("to_internal_scale converts deterministically", {

  # TO PROPORTION (internal canonical for proportional plots)
  expect_equal(to_internal_scale(80, "percent", "proportion"), 0.8)
  expect_equal(to_internal_scale(80, "permille", "proportion"), 0.08)
  expect_equal(to_internal_scale(0.8, "proportion", "proportion"), 0.8)  # Identity

  # TO ABSOLUTE (internal canonical for count plots)
  expect_equal(to_internal_scale(80, "absolute", "absolute"), 80)  # Identity
  expect_equal(to_internal_scale(80, "percent", "absolute"), 80)

  # Error cases
  expect_true(is.na(to_internal_scale(80, "absolute", "proportion")))

})

# MAIN API TESTS ---------------------------------------------------------------

test_that("normalize_axis_value integrates all layers correctly", {

  # SCENARIO A: Input with % symbol, proportion internal unit
  result1 <- normalize_axis_value("80%", user_unit = "proportion", internal_unit = "proportion")
  expect_equal(result1, 0.8)

  # SCENARIO B: Input without symbol, percent target unit
  result2 <- normalize_axis_value("80", user_unit = "percent", internal_unit = "percent")
  expect_equal(result2, 80)

  # SCENARIO C: Data-driven unit resolution
  decimal_y_data <- c(0.1, 0.2, 0.3, 0.8)
  result3 <- normalize_axis_value("80%", y_sample = decimal_y_data, internal_unit = "proportion")
  expect_equal(result3, 0.8)  # 80% → proportion 0.8

  # SCENARIO D: Data-driven unit resolution suggests percent
  percent_y_data <- c(10, 20, 30, 80)
  result4 <- normalize_axis_value("80%", y_sample = percent_y_data, internal_unit = "percent")
  expect_equal(result4, 80)  # Data suggests percent: 80% → 80 percent

})

test_that("normalize_axis_value handles edge cases gracefully", {

  # Invalid input
  expect_null(normalize_axis_value(""))
  expect_null(normalize_axis_value("invalid"))
  expect_null(normalize_axis_value("80%\u2030"))  # Begge symboler

  # Valid input but incompatible units
  result <- normalize_axis_value("150", user_unit = "absolute", internal_unit = "proportion")
  expect_true(is.null(result) || !is.na(result))  # Should handle gracefully

})

test_that("normalize_axis_value is idempotent", {

  # Same input should give same output
  input_str <- "68,5%"
  user_unit <- "proportion"
  internal_unit <- "proportion"

  result_a <- normalize_axis_value(input_str, user_unit = user_unit, internal_unit = internal_unit)
  result_b <- normalize_axis_value(input_str, user_unit = user_unit, internal_unit = internal_unit)

  expect_identical(result_a, result_b)

})

# VALIDATION TESTS -------------------------------------------------------------

test_that("validate_axis_value enforces range constraints", {

  # Proportion should be [0,1]
  valid_prop <- validate_axis_value(0.8, "proportion")
  expect_true(valid_prop$valid)

  invalid_prop_high <- validate_axis_value(1.5, "proportion")
  expect_false(invalid_prop_high$valid)

  invalid_prop_low <- validate_axis_value(-0.1, "proportion")
  expect_false(invalid_prop_low$valid)

  # Absolute has no constraints (for now)
  absolute_val <- validate_axis_value(150, "absolute")
  expect_true(absolute_val$valid)

})

# BACKWARDS COMPATIBILITY TESTS ------------------------------------------------

test_that("parse_danish_target maintains backwards compatibility", {
  skip("Afventer parse_danish_target unit-awareness refactor — se #213 (backwards-compat)")

  # Decimal Y-data context
  decimal_y_data <- c(0.1, 0.3, 0.6, 0.8)
  expect_equal(parse_danish_target("80%", decimal_y_data, "percent"), 0.8)
  expect_equal(parse_danish_target("0.8", decimal_y_data, "percent"), 0.8)

  # Percent Y-data context
  percent_y_data <- c(10, 25, 60, 85)
  expect_equal(parse_danish_target("80%", percent_y_data, "count"), 80)
  expect_equal(parse_danish_target("0.8", percent_y_data, "count"), 80)

  # No Y-data, explicit unit
  expect_equal(parse_danish_target("80%", NULL, "percent"), 80)
  expect_equal(parse_danish_target("0.8", NULL, "percent"), 80)

})

# INTEGRATION AND CONSISTENCY TESTS --------------------------------------------

test_that("Key examples from design specification work correctly", {

  # "80%" + target_unit=proportion → 0.8
  result1 <- normalize_axis_value("80%", user_unit = "proportion", internal_unit = "proportion")
  expect_equal(result1, 0.8)

  # "80" (no symbol) + target_unit=percent → 80 (NOT 0.8)
  result2 <- normalize_axis_value("80", user_unit = "percent", internal_unit = "percent")
  expect_equal(result2, 80)

  # "0,8" (no symbol) + target_unit=percent → 0.8 (i.e., 0.8%)
  result3 <- normalize_axis_value("0,8", user_unit = "percent", internal_unit = "percent")
  expect_equal(result3, 0.8)

  # "0,8" + target_unit=proportion → 0.8
  result4 <- normalize_axis_value("0,8", user_unit = "proportion", internal_unit = "proportion")
  expect_equal(result4, 0.8)

  # "8\u2030" + target_unit=proportion → 0.008
  result5 <- normalize_axis_value("8\u2030", user_unit = "proportion", internal_unit = "proportion")
  expect_equal(result5, 0.008)

  # "8\u2030" + target_unit=percent → 0.8
  result6 <- normalize_axis_value("8\u2030", user_unit = "percent", internal_unit = "percent")
  expect_equal(result6, 0.8)

})

test_that("No double-scaling occurs in typical qicharts2 workflows", {

  proportion_y_data <- c(0.1, 0.2, 0.3, 0.8)  # Typical p-chart data
  target_normalized <- normalize_axis_value("80%", y_sample = proportion_y_data, internal_unit = "proportion")

  expect_equal(target_normalized, 0.8)

})

test_that("Priority system works as designed", {

  # User explicit choice should override data heuristics
  percent_looking_data <- c(10, 20, 30, 80)  # Would normally suggest "percent"

  # But user explicitly chooses "proportion"
  result <- normalize_axis_value("80%", user_unit = "proportion", y_sample = percent_looking_data, internal_unit = "proportion")
  expect_equal(result, 0.8)  # Should honor user choice: 80% → 0.8 proportion

  # Whereas without user choice, data heuristics would suggest percent
  result_heuristic <- normalize_axis_value("80%", y_sample = percent_looking_data, internal_unit = "percent")
  expect_equal(result_heuristic, 80)  # Data suggests percent: 80% → 80 percent

})

# =============================================================================
# SEKTION 2: Y-AXIS MAPPING (fra test-y-axis-mapping.R)
# Tests for chart_type_to_ui_type() og decide_default_y_axis_ui_type()
# =============================================================================

test_that("chart_type_to_ui_type mapping is correct", {
  # Proportion charts → percent
  expect_equal(chart_type_to_ui_type("p"), "percent")
  expect_equal(chart_type_to_ui_type("pp"), "percent")

  # Rate charts → rate
  expect_equal(chart_type_to_ui_type("u"), "rate")
  expect_equal(chart_type_to_ui_type("up"), "rate")

  # Time between → time_days (Fase 2a: t-kort bruger dage som default tids-enhed)
  expect_equal(chart_type_to_ui_type("t"), "time_days")

  # Count/measurement/others → count
  expect_equal(chart_type_to_ui_type("i"), "count")
  expect_equal(chart_type_to_ui_type("mr"), "count")
  expect_equal(chart_type_to_ui_type("c"), "count")
  expect_equal(chart_type_to_ui_type("g"), "count")
  expect_equal(chart_type_to_ui_type("unknown_type"), "count")
})

test_that("run chart default y-axis with denominator presence", {
  # RUN + with N → percent
  expect_equal(decide_default_y_axis_ui_type("run", n_present = TRUE), "percent")

  # RUN + without N → count
  expect_equal(decide_default_y_axis_ui_type("run", n_present = FALSE), "count")
})

test_that("run chart denominator toggle semantics (unit-only)", {
  # Conceptual toggle: blank → selected N should imply percent
  expect_equal(decide_default_y_axis_ui_type("run", n_present = TRUE), "percent")

  # Conceptual toggle: selected N → blank should imply count
  expect_equal(decide_default_y_axis_ui_type("run", n_present = FALSE), "count")
})

# =============================================================================
# SEKTION 3: Y-AXIS MODEL (fra test-y-axis-model.R)
# Tests for determine_internal_class() og suggest_chart_type()
# =============================================================================

test_that("UI-typer mapper korrekt til interne klasser", {
  # TAL → COUNT hvis heltal >= 0, ellers MEASUREMENT
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

# ===== TIDSAKSE-TESTS (#204-#207 — fra master's tidsakse-PRs) =====

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

test_that("default_time_unit_for_chart returnerer passende enhed pr. korttype", {
  expect_equal(default_time_unit_for_chart("t"), "time_days")
  # For ikke-tids-specifikke korttyper returneres NULL
  expect_null(default_time_unit_for_chart("i"))
  expect_null(default_time_unit_for_chart("p"))
  expect_null(default_time_unit_for_chart("c"))
  expect_null(default_time_unit_for_chart("u"))
  # NA / NULL input
  expect_null(default_time_unit_for_chart(NULL))
  expect_null(default_time_unit_for_chart(NA_character_))
})

test_that("t-kort: korttype-skift foerer til time_days som default y-enhed", {
  # Integration: UI's chart_type-observer kalder chart_type_to_ui_type()
  # for at finde default y-enhed. "t" skal mappes til "time_days".
  expect_equal(chart_type_to_ui_type("t"), "time_days")
  expect_equal(default_time_unit_for_chart("t"), "time_days")
})

# =============================================================================
# SEKTION 4: Y-AXIS FORMATTING (fra test-y-axis-formatting.R)
# Tests for apply_y_axis_formatting(), format_scaled_number() m.fl.
# =============================================================================

# TEST: apply_y_axis_formatting() ----------------------------------------------

test_that("apply_y_axis_formatting handles all unit types", {
  # Setup: Create base plot
  test_data <- data.frame(x = 1:10, y = seq(0, 100, length.out = 10))
  base_plot <- ggplot(test_data, aes(x = x, y = y)) + geom_point()

  # Test percent formatting
  plot_percent <- apply_y_axis_formatting(base_plot, "percent", test_data)
  expect_s3_class(plot_percent, "ggplot")
  expect_true(length(plot_percent$layers) > 0)

  # Test count formatting
  plot_count <- apply_y_axis_formatting(base_plot, "count", test_data)
  expect_s3_class(plot_count, "ggplot")

  # Test rate formatting
  plot_rate <- apply_y_axis_formatting(base_plot, "rate", test_data)
  expect_s3_class(plot_rate, "ggplot")

  # Test time formatting (requires qic_data structure)
  qic_data <- data.frame(x = 1:10, y = seq(0, 120, length.out = 10))
  plot_time <- apply_y_axis_formatting(base_plot, "time", qic_data)
  expect_s3_class(plot_time, "ggplot")
})

test_that("apply_y_axis_formatting handles invalid inputs gracefully", {
  test_data <- data.frame(x = 1:10, y = 1:10)
  base_plot <- ggplot(test_data, aes(x = x, y = y)) + geom_point()

  # Test NULL y_axis_unit (should default to "count")
  plot_null <- apply_y_axis_formatting(base_plot, NULL, test_data)
  expect_s3_class(plot_null, "ggplot")

  # Test invalid y_axis_unit (should default to "count")
  plot_invalid <- apply_y_axis_formatting(base_plot, "invalid_unit", test_data)
  expect_s3_class(plot_invalid, "ggplot")

  # Test non-ggplot object (should return input unchanged)
  not_a_plot <- list(data = test_data)
  result <- apply_y_axis_formatting(not_a_plot, "percent", test_data)
  expect_equal(result, not_a_plot)
})

# TEST: format_scaled_number() -------------------------------------------------

test_that("format_scaled_number formats correctly with Danish notation", {
  skip("Afventer format-funktion edge case fix — se #242 (format_scaled_number afrunding)")
  # Integer values (no decimals)
  expect_equal(format_scaled_number(1000, 1e3, "K"), "1K")
  expect_equal(format_scaled_number(5000, 1e3, "K"), "5K")
  expect_equal(format_scaled_number(1000000, 1e6, "M"), "1M")
  expect_equal(format_scaled_number(1000000000, 1e9, " mia."), "1 mia.")

  # Decimal values (Danish decimal mark ",")
  expect_equal(format_scaled_number(1500, 1e3, "K"), "1,5K")
  expect_equal(format_scaled_number(2750, 1e3, "K"), "2,8K")
  expect_equal(format_scaled_number(1250000, 1e6, "M"), "1,2M")
  expect_equal(format_scaled_number(1500000000, 1e9, " mia."), "1,5 mia.")
})

# TEST: format_unscaled_number() -----------------------------------------------

test_that("format_unscaled_number uses Danish notation", {
  skip("Afventer format-funktion edge case fix — se #242 (format_unscaled_number scientific)")
  # Integer values (with thousand separator ".")
  expect_equal(format_unscaled_number(100), "100")
  expect_equal(format_unscaled_number(1000), "1.000")
  expect_equal(format_unscaled_number(10000), "10.000")
  expect_equal(format_unscaled_number(100000), "100.000")

  # Decimal values (decimal mark "," and thousand separator ".")
  expect_equal(format_unscaled_number(100.5), "100,5")
  expect_equal(format_unscaled_number(1000.75), "1.000,8")
})

# TEST: format_time_with_unit() ------------------------------------------------

test_that("format_time_with_unit consolidates duplication correctly", {
  skip("Funktionen er fjernet. Se format_time_composite i utils_time_formatting.R")
})

test_that("format_time_with_unit handles edge cases", {
  skip("Afventer format-funktion edge case fix — se #242 (format_time_with_unit 10000 days)")
  # Zero values
  expect_equal(format_time_with_unit(0, "minutes"), "0 min")
  expect_equal(format_time_with_unit(0, "hours"), "0 timer")
  expect_equal(format_time_with_unit(0, "days"), "0 dage")

  # Very small decimals
  expect_match(format_time_with_unit(0.1, "minutes"), "^0,1 min$")

  # Large values
  expect_equal(format_time_with_unit(10000, "days"), "6,9 dage")
})

# TEST: format_y_axis_time() ---------------------------------------------------

test_that("format_y_axis_time selects correct unit based on data range", {
  # Minutes range (< 60)
  qic_data_minutes <- data.frame(x = 1:10, y = seq(1, 50, length.out = 10))
  scale_minutes <- format_y_axis_time(qic_data_minutes)
  expect_s3_class(scale_minutes, "ScaleContinuous")

  # Hours range (60-1439)
  qic_data_hours <- data.frame(x = 1:10, y = seq(60, 600, length.out = 10))
  scale_hours <- format_y_axis_time(qic_data_hours)
  expect_s3_class(scale_hours, "ScaleContinuous")

  # Days range (>= 1440)
  qic_data_days <- data.frame(x = 1:10, y = seq(1440, 5000, length.out = 10))
  scale_days <- format_y_axis_time(qic_data_days)
  expect_s3_class(scale_days, "ScaleContinuous")
})

test_that("format_y_axis_time handles missing or invalid data", {
  # NULL qic_data
  scale_null <- format_y_axis_time(NULL)
  expect_s3_class(scale_null, "ScaleContinuous")

  # Missing y column
  qic_data_no_y <- data.frame(x = 1:10, z = 1:10)
  scale_no_y <- format_y_axis_time(qic_data_no_y)
  expect_s3_class(scale_no_y, "ScaleContinuous")
})

# TEST: Integration with ggplot2 -----------------------------------------------

test_that("Y-axis formatting integrates correctly with ggplot2", {
  # Create test data
  test_data <- data.frame(
    x = 1:20,
    y = c(50, 75, 100, 125, 150, 175, 200, 225, 250, 275,
          300, 325, 350, 375, 400, 425, 450, 475, 500, 525)
  )

  # Create base plot
  base_plot <- ggplot(test_data, aes(x = x, y = y)) +
    geom_line() +
    geom_point()

  # Apply formatting
  formatted_plot <- apply_y_axis_formatting(base_plot, "count", test_data)

  # Verify plot builds without errors
  expect_s3_class(formatted_plot, "ggplot")
  expect_error(ggplot_build(formatted_plot), NA)

  # Verify y-axis scale was added
  scales <- formatted_plot$scales$scales
  has_y_scale <- any(sapply(scales, function(s) "y" %in% s$aesthetics))
  expect_true(has_y_scale)
})

test_that("Extracted formatting produces identical output to original", {
  # Test count formatting with K notation
  test_val_k <- 5000
  expect_equal(format_scaled_number(test_val_k, 1e3, "K"), "5K")

  # Test count formatting with M notation
  test_val_m <- 2500000
  expect_equal(format_scaled_number(test_val_m, 1e6, "M"), "2,5M")

  # Time formatting backward-compatibility cases flyttet til
  # test-time-formatting.R (format_time_composite)
})

test_that("format_time_with_unit eliminates duplication effectively", {
  skip("Funktionen er fjernet. Se format_time_composite i utils_time_formatting.R")
})

# TEST: Komposit-format integration ==========================================

test_that("apply_y_axis_formatting med time-enhed bruger komposit-format", {
  qic_data <- data.frame(x = 1:5, y = c(30, 60, 90, 120, 150))
  plot <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point()

  result <- apply_y_axis_formatting(plot, "time", qic_data)
  expect_s3_class(result, "ggplot")

  built <- ggplot2::ggplot_build(result)
  y_labels <- built$layout$panel_params[[1]]$y$get_labels()

  # Labels skal matche komposit-patterns: "30m", "1t", "1t 30m", "1d", "1d 4t"
  y_labels_clean <- y_labels[!is.na(y_labels)]
  expect_true(all(grepl("^-?(\\d+d( \\d+t)?|\\d+t( \\d+m)?|\\d+m)$", y_labels_clean)))
})
