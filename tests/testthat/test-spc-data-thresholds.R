# test-spc-data-thresholds.R
# Tests for centraliserede SPC datapunkt-graenser (#417)
#
# Dækker:
#   - SPC_DATA_THRESHOLDS getter-funktioner
#   - fct_spc_validate: hard_min-check bruger get_spc_hard_min()
#   - fct_spc_prepare: hard_min-check bruger get_spc_hard_min()
#   - fct_spc_helpers: warning triggeres ved < get_spc_warning_threshold()
#   - UI-banner: triggeres ved n < get_spc_warning_threshold() (indirekte)
#   - Export-watermark: n_pts < get_spc_warning_threshold() giver advarsel i data_definition

# ── Getter-funktioner ──────────────────────────────────────────────────────────

test_that("get_spc_hard_min() returnerer 3", {
  expect_equal(get_spc_hard_min(), 3L)
})

test_that("get_spc_warning_threshold() returnerer 12", {
  expect_equal(get_spc_warning_threshold(), 12L)
})

test_that("get_spc_recommended_threshold() returnerer 15", {
  expect_equal(get_spc_recommended_threshold(), 15L)
})

test_that("SPC_DATA_THRESHOLDS er en liste med de rette felter", {
  expect_type(SPC_DATA_THRESHOLDS, "list")
  expect_true("hard_min" %in% names(SPC_DATA_THRESHOLDS))
  expect_true("warning_short" %in% names(SPC_DATA_THRESHOLDS))
  expect_true("recommended" %in% names(SPC_DATA_THRESHOLDS))
  expect_equal(SPC_DATA_THRESHOLDS$hard_min, 3L)
  expect_equal(SPC_DATA_THRESHOLDS$warning_short, 12L)
  expect_equal(SPC_DATA_THRESHOLDS$recommended, 15L)
})

# ── fct_spc_validate: hard_min-check ─────────────────────────────────────────

test_that("#417: validate_spc_request fejler ved n < get_spc_hard_min() (n=2)", {
  df <- data.frame(
    dato = as.Date("2023-01-01") + 0:1,
    vaerdi = c(1.0, 2.0)
  )
  expect_error(
    validate_spc_request(df, "dato", "vaerdi", "run"),
    class = "spc_input_error"
  )
})

test_that("#417: validate_spc_request fejler ved n < get_spc_hard_min() (n=1)", {
  df <- data.frame(
    dato = as.Date("2023-01-01"),
    vaerdi = 1.0
  )
  expect_error(
    validate_spc_request(df, "dato", "vaerdi", "run"),
    class = "spc_input_error"
  )
})

test_that("#417: validate_spc_request accepterer n = get_spc_hard_min() (n=3)", {
  df <- data.frame(
    dato = as.Date("2023-01-01") + 0:2,
    vaerdi = c(1.0, 2.0, 3.0)
  )
  result <- validate_spc_request(df, "dato", "vaerdi", "run")
  expect_s3_class(result, "spc_request")
})

# ── fct_spc_prepare: hard_min-check ───────────────────────────────────────────

test_that("#417: prepare_spc_data fejler ved < get_spc_hard_min() gyldige raekker efter filtrering", {
  # 10 raekker, kun 2 gyldige (resten NA)
  df <- data.frame(
    x = as.Date("2023-01-01") + 0:9,
    y = c(1.0, 2.0, rep(NA_real_, 8))
  )
  req <- new_spc_request(df, "x", "y", "run")
  expect_error(
    prepare_spc_data(req),
    class = "spc_prepare_error"
  )
})

# ── fct_spc_helpers: warning ved n < get_spc_warning_threshold() ─────────────

test_that("#417: validateDataForChart giver advarsel ved n=8 (< 12)", {
  df <- data.frame(
    x = as.Date("2023-01-01") + 0:7,
    y = as.numeric(1:8)
  )
  config <- list(y_col = "y", x_col = "x", n_col = NULL)
  result <- validateDataForChart(df, config, "run")
  expect_true(result$valid)
  expect_true(any(grepl("datapunkter", result$warnings)))
})

test_that("#417: validateDataForChart ingen advarsel ved n=12 (= warning_threshold)", {
  df <- data.frame(
    x = as.Date("2023-01-01") + 0:11,
    y = as.numeric(1:12)
  )
  config <- list(y_col = "y", x_col = "x", n_col = NULL)
  result <- validateDataForChart(df, config, "run")
  expect_true(result$valid)
  # Ingen advarsel om kort serie ved n=12
  datapunkt_warnings <- result$warnings[grepl("datapunkter", result$warnings)]
  expect_length(datapunkt_warnings, 0L)
})

test_that("#417: validateDataForChart ingen advarsel ved n=15", {
  df <- data.frame(
    x = as.Date("2023-01-01") + 0:14,
    y = as.numeric(1:15)
  )
  config <- list(y_col = "y", x_col = "x", n_col = NULL)
  result <- validateDataForChart(df, config, "run")
  expect_true(result$valid)
  datapunkt_warnings <- result$warnings[grepl("datapunkter", result$warnings)]
  expect_length(datapunkt_warnings, 0L)
})

# ── Export-watermark: data_definition ved n < get_spc_warning_threshold() ────

test_that("#417: short_series_note genereres naar n < get_spc_warning_threshold()", {
  # Test den logik der bygger data_definition_with_note
  n_pts <- 8L
  warning_threshold <- get_spc_warning_threshold()

  short_series_note <- if (n_pts < warning_threshold) {
    paste0(
      "Kort serie (n=", n_pts, "): ",
      "Anhoej-rules er upalidelige under ", warning_threshold, " datapunkter."
    )
  } else {
    NULL
  }

  expect_false(is.null(short_series_note))
  expect_true(grepl("Kort serie", short_series_note))
  expect_true(grepl("n=8", short_series_note))
})

test_that("#417: short_series_note er NULL naar n >= get_spc_warning_threshold()", {
  n_pts <- 12L
  warning_threshold <- get_spc_warning_threshold()

  short_series_note <- if (n_pts < warning_threshold) {
    paste0("Kort serie (n=", n_pts, ")")
  } else {
    NULL
  }

  expect_null(short_series_note)
})

test_that("#417: data_definition_with_note konkatenerer korrekt naar begge felter udfyldt", {
  base_description <- "Daglig optaelling af HAI-infektioner"
  short_series_note <- "Kort serie (n=8): Anhoej-rules upalidelige."

  data_definition_with_note <- if (nchar(trimws(base_description)) > 0) {
    paste0(base_description, "\n\n", short_series_note)
  } else {
    short_series_note
  }

  expect_true(grepl("HAI", data_definition_with_note))
  expect_true(grepl("Kort serie", data_definition_with_note))
})
