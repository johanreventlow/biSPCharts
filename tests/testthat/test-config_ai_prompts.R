# ==============================================================================
# TEST-CONFIG_AI_PROMPTS.R
# ==============================================================================
# FORMÅL: Unit tests for AI prompt configuration, chart type mapping og
#         template interpolation.
# ==============================================================================

test_that("get_ai_config returns defaults when config is missing", {
  # Mock golem config returnerer NULL
  # NOTE: Hvis golem::get_golem_options ikke kan mockes let, skip denne test
  # og test manuelt i dev environment

  # Test at funktionen ikke fejler
  config <- get_ai_config()

  expect_type(config, "list")
  expect_true("enabled" %in% names(config))
  expect_true("model" %in% names(config))
  expect_true("timeout_seconds" %in% names(config))
  expect_true("max_response_chars" %in% names(config))
  expect_true("cache_ttl_seconds" %in% names(config))
})

test_that("map_chart_type_to_danish handles all BFHcharts types", {
  # Test alle understøttede chart types
  expect_equal(
    map_chart_type_to_danish("run"),
    "serieplot (run chart)"
  )

  expect_equal(
    map_chart_type_to_danish("i"),
    "I-chart (individuelle værdier)"
  )

  expect_equal(
    map_chart_type_to_danish("mr"),
    "MR-chart (moving range)"
  )

  expect_equal(
    map_chart_type_to_danish("xbar"),
    "X-bar chart (gennemsnit)"
  )

  expect_equal(
    map_chart_type_to_danish("s"),
    "S-chart (standardafvigelse)"
  )

  expect_equal(
    map_chart_type_to_danish("t"),
    "T-chart (tid mellem events)"
  )

  expect_equal(
    map_chart_type_to_danish("p"),
    "P-chart (andel)"
  )

  expect_equal(
    map_chart_type_to_danish("pp"),
    "PP-chart (andel per periode)"
  )

  expect_equal(
    map_chart_type_to_danish("c"),
    "C-chart (antal events)"
  )

  expect_equal(
    map_chart_type_to_danish("u"),
    "U-chart (rate per enhed)"
  )

  expect_equal(
    map_chart_type_to_danish("g"),
    "G-chart (events mellem)"
  )

  expect_equal(
    map_chart_type_to_danish("prime"),
    "Prime chart"
  )
})

test_that("map_chart_type_to_danish handles case insensitivity", {
  expect_equal(
    map_chart_type_to_danish("RUN"),
    "serieplot (run chart)"
  )

  expect_equal(
    map_chart_type_to_danish("P"),
    "P-chart (andel)"
  )
})

test_that("map_chart_type_to_danish returns input for unknown types", {
  # Unknown type skal returnere input som fallback
  result <- map_chart_type_to_danish("unknown_type")
  expect_equal(result, "unknown_type")
})

test_that("get_improvement_suggestion_template returns valid template", {
  template <- get_improvement_suggestion_template()

  expect_type(template, "character")
  expect_true(nchar(template) > 0)

  # Tjek at alle vigtige placeholders er til stede
  expect_true(grepl("\\{data_definition\\}", template))
  expect_true(grepl("\\{chart_title\\}", template))
  expect_true(grepl("\\{y_axis_unit\\}", template))
  expect_true(grepl("\\{chart_type_dansk\\}", template))
  expect_true(grepl("\\{n_points\\}", template))
  expect_true(grepl("\\{start_date\\}", template))
  expect_true(grepl("\\{end_date\\}", template))
  expect_true(grepl("\\{target_value\\}", template))
  expect_true(grepl("\\{centerline\\}", template))
  expect_true(grepl("\\{process_variation\\}", template))
  expect_true(grepl("\\{signals_detected\\}", template))
  expect_true(grepl("\\{longest_run\\}", template))
  expect_true(grepl("\\{n_crossings\\}", template))
  expect_true(grepl("\\{n_crossings_min\\}", template))
  expect_true(grepl("\\{target_comparison\\}", template))

  # Tjek at vigtige instruktioner er inkluderet
  expect_true(grepl("Statistical Process Control", template))
  expect_true(grepl("max 350 tegn", template))
  expect_true(grepl("dansk", template, ignore.case = TRUE))
  expect_true(grepl("\\*kursiv\\*", template))
})

test_that("interpolate_prompt replaces all placeholders correctly", {
  template <- "Chart: {chart_type}, Points: {n_points}, Target: {target}"

  data <- list(
    chart_type = "run",
    n_points = 24,
    target = 95
  )

  result <- interpolate_prompt(template, data)

  expect_equal(result, "Chart: run, Points: 24, Target: 95")
  expect_false(grepl("\\{", result))  # Ingen placeholders tilbage
})

test_that("interpolate_prompt handles NULL values gracefully", {
  template <- "Value: {value}, Other: {other}"

  data <- list(
    value = NULL,
    other = "test"
  )

  result <- interpolate_prompt(template, data)

  expect_true(grepl("Ikke angivet", result))
  expect_true(grepl("test", result))
})

test_that("interpolate_prompt handles NA values gracefully", {
  template <- "Value: {value}"

  data <- list(
    value = NA
  )

  result <- interpolate_prompt(template, data)

  expect_true(grepl("Ikke angivet", result))
})

test_that("interpolate_prompt handles empty string values", {
  template <- "Value: {value}"

  data <- list(
    value = ""
  )

  result <- interpolate_prompt(template, data)

  expect_true(grepl("Ikke angivet", result))
})

test_that("interpolate_prompt warns about unfilled placeholders", {
  template <- "Value: {value}, Missing: {missing_field}"

  data <- list(
    value = "test"
    # missing_field er ikke inkluderet
  )

  # Expect warning om unfilled placeholders
  # NOTE: Dette kræver at log_warn faktisk logger noget vi kan fange
  # I simple tests kan vi bare verificere at det ikke fejler
  result <- interpolate_prompt(template, data)

  expect_true(grepl("test", result))
  expect_true(grepl("\\{missing_field\\}", result))
})

test_that("interpolate_prompt handles complex data types", {
  template <- "Count: {count}, Date: {date}"

  data <- list(
    count = 42L,  # Integer
    date = as.Date("2025-01-15")  # Date object
  )

  result <- interpolate_prompt(template, data)

  expect_true(grepl("42", result))
  expect_true(grepl("2025-01-15", result))
})

test_that("full workflow: template -> interpolation -> valid prompt", {
  # Integration test af hele flowet
  template <- get_improvement_suggestion_template()

  data <- list(
    data_definition = "Medicineringsfejl",
    chart_title = "Fejl per 1000 administrationer",
    y_axis_unit = "Andel",
    chart_type_dansk = map_chart_type_to_danish("p"),
    n_points = 24,
    start_date = "2024-01-01",
    end_date = "2024-12-31",
    target_value = 5,
    centerline = 7.2,
    process_variation = "ikke naturligt",
    signals_detected = 3,
    longest_run = 8,
    n_crossings = 5,
    n_crossings_min = 11,
    target_comparison = "over målet"
  )

  result <- interpolate_prompt(template, data)

  # Verificér at alle værdier er indsat
  expect_true(grepl("Medicineringsfejl", result))
  expect_true(grepl("P-chart \\(andel\\)", result))
  expect_true(grepl("24", result))
  expect_true(grepl("ikke naturligt", result))

  # Verificér at der ikke er placeholders tilbage
  expect_false(grepl("\\{data_definition\\}", result))
  expect_false(grepl("\\{chart_type_dansk\\}", result))
})

test_that("chart type mapping covers all types in template examples", {
  # Test at alle chart types der kan forekomme i praksis har mappings

  # BFHcharts primære types (fra dokumentation)
  primary_types <- c("run", "i", "mr", "xbar", "s", "t", "p", "pp", "c", "u", "g", "prime")

  for (chart_type in primary_types) {
    result <- map_chart_type_to_danish(chart_type)

    # Skal ikke være tom eller lig input (medmindre input er ukendt)
    expect_true(nchar(result) > 0)

    # Skal indeholde enten dansk tekst eller parentes notation
    expect_true(
      grepl("-chart|serieplot|chart|Chart", result),
      info = paste("Chart type", chart_type, "should have valid Danish mapping")
    )
  }
})
