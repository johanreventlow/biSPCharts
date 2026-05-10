# Shinytest2 integration tests for BFHchart-modulet.
#
# Tests at appen renderer SPC-charts efter et komplet upload + chart-config
# user-flow. Visuelle screenshot-snapshots er BEVIDST udeladt: de kræver
# CI-genereret baseline (Linux fonts ≠ Mac fonts), markeres som "first-time"
# failure ved fresh kørsel, og er per CLAUDE.md "miljøfølsomme — opt-in".
# I stedet asserter testene state-output (plot_ready, anhoej_results,
# spc_plot_actual non-NULL) som er deterministiske på tværs af miljøer.

library(testthat)

bfh_shinytest2_enabled <- identical(Sys.getenv("RUN_SHINYTEST2"), "1")

if (bfh_shinytest2_enabled && requireNamespace("shinytest2", quietly = TRUE)) {
  library(shinytest2)
}

skip_bfh_shinytest2 <- function() {
  skip_if(
    !bfh_shinytest2_enabled,
    "BFH shinytest2 visual tests are opt-in; set RUN_SHINYTEST2=1"
  )
  skip_if_not_installed("shinytest2")
}

bfh_plot_output <- "visualization-spc_plot_actual"
bfh_plot_ready_output <- "visualization-plot_ready"
bfh_anhoej_output <- "visualization-anhoej_results"

is_shiny_true <- function(value) {
  isTRUE(value) || identical(value, "true") || identical(value, "TRUE")
}

wait_for_bfh_plot_ready <- function(app, timeout = 20000) {
  deadline <- Sys.time() + timeout / 1000
  repeat {
    app$wait_for_idle(timeout = 1000)
    ready <- tryCatch(
      app$get_value(output = bfh_plot_ready_output),
      error = function(e) NULL
    )
    if (is_shiny_true(ready)) {
      return(TRUE)
    }
    if (Sys.time() > deadline) {
      return(FALSE)
    }
    Sys.sleep(0.25)
  }
}

expect_bfh_plot_ready <- function(app) {
  ready <- wait_for_bfh_plot_ready(app)
  if (!ready) {
    fail(paste0(
      bfh_plot_ready_output,
      " blev ikke TRUE inden timeout — BFHchart-modulet renderede ikke chart"
    ))
  }
  expect_true(ready)
}

# Test fixture: byg test-CSV med kolonner appen genkender via auto-detekt.
create_test_csv <- function(chart_type, n_rows = 50, seed = 20251015) {
  set.seed(seed)

  base_data <- data.frame(
    Dato = seq.Date(Sys.Date() - n_rows + 1, Sys.Date(), by = "day"),
    Vaerdi = rnorm(n_rows, mean = 100, sd = 15)
  )

  if (chart_type %in% c("p", "c", "u")) {
    base_data$Naevner <- sample(50:200, n_rows, replace = TRUE)
  }

  base_data
}

get_app_driver <- function(name) {
  shinytest2::AppDriver$new(
    app_dir = test_path("../.."),
    name = name,
    variant = shinytest2::platform_variant(),
    height = 800,
    width = 1200
  )
}

# Upload CSV via det skjulte direct_file_upload-fileInput.
# wizard_gates.R navigerer automatisk til "analyser"-tab når data_updated
# fyrer, så vi behøver ikke selv kalde nav_select. load_paste_data-knappen
# er IRRELEVANT her — den hører til paste-tekst-flowet.
upload_test_data <- function(app, csv_path) {
  app$wait_for_idle(timeout = 5000)
  app$upload_file(direct_file_upload = csv_path)
  app$wait_for_idle(timeout = 8000)
}

# Åbn kolonne-mapping-modal og sæt kolonne-inputs. Inputs lever KUN i
# DOM mens modal er åben (show_column_mapping_modal i utils_server_column_management.R),
# men reaktive værdier persisterer på server-side efter modal lukkes.
# Vi lader modal stå åben — testene asserter server-state via get_value(),
# ej screenshots, så modal-overlay er irrelevant.
configure_columns <- function(app, ...) {
  inputs <- list(...)
  app$click("open_column_mapping_modal")
  app$wait_for_idle(timeout = 3000)
  do.call(app$set_inputs, inputs)
  app$wait_for_idle(timeout = 3000)
}

# ==============================================================================
# Test: Run Chart
# ==============================================================================

test_that("BFHchart module: Run chart renderer korrekt", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("run")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-run-chart")
  upload_test_data(app, temp_csv)

  configure_columns(app, x_column = "Dato", y_column = "Vaerdi")
  app$set_inputs(chart_type = "run")
  app$wait_for_idle(timeout = 5000)
  expect_bfh_plot_ready(app)

  expect_true(is_shiny_true(app$get_value(output = bfh_plot_ready_output)))
  expect_true(!is.null(app$get_value(output = bfh_anhoej_output)))

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: I Chart
# ==============================================================================

test_that("BFHchart module: I chart renderer korrekt", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("i")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-i-chart")
  upload_test_data(app, temp_csv)

  configure_columns(app, x_column = "Dato", y_column = "Vaerdi")
  app$set_inputs(chart_type = "i")
  app$wait_for_idle(timeout = 5000)
  expect_bfh_plot_ready(app)

  expect_true(is_shiny_true(app$get_value(output = bfh_plot_ready_output)))
  expect_true(!is.null(app$get_value(output = bfh_anhoej_output)))

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: P Chart (ratio chart med nævner)
# ==============================================================================

test_that("BFHchart module: P chart renderer korrekt med nævner", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("p")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-p-chart")
  upload_test_data(app, temp_csv)

  configure_columns(
    app,
    x_column = "Dato",
    y_column = "Vaerdi",
    n_column = "Naevner"
  )
  app$set_inputs(chart_type = "p", y_axis_unit = "percent")
  app$wait_for_idle(timeout = 5000)
  expect_bfh_plot_ready(app)

  expect_true(is_shiny_true(app$get_value(output = bfh_plot_ready_output)))
  expect_true(!is.null(app$get_value(output = bfh_anhoej_output)))

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: C Chart (count data)
# ==============================================================================

test_that("BFHchart module: C chart renderer korrekt med tællingsdata", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("c")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-c-chart")
  upload_test_data(app, temp_csv)

  configure_columns(app, x_column = "Dato", y_column = "Vaerdi")
  app$set_inputs(chart_type = "c")
  app$wait_for_idle(timeout = 5000)
  expect_bfh_plot_ready(app)

  expect_true(is_shiny_true(app$get_value(output = bfh_plot_ready_output)))
  expect_true(!is.null(app$get_value(output = bfh_anhoej_output)))

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: U Chart (rate data med variabel nævner)
# ==============================================================================

test_that("BFHchart module: U chart renderer korrekt med variabel nævner", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("u")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-u-chart")
  upload_test_data(app, temp_csv)

  configure_columns(
    app,
    x_column = "Dato",
    y_column = "Vaerdi",
    n_column = "Naevner"
  )
  app$set_inputs(chart_type = "u", y_axis_unit = "rate")
  app$wait_for_idle(timeout = 5000)
  expect_bfh_plot_ready(app)

  expect_true(is_shiny_true(app$get_value(output = bfh_plot_ready_output)))
  expect_true(!is.null(app$get_value(output = bfh_anhoej_output)))

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: Freeze period
# ==============================================================================

test_that("BFHchart module: Freeze period renderer korrekt", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("run")
  test_data$Fryz <- c(rep(0, 30), rep(1, 20))

  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-freeze-test")
  upload_test_data(app, temp_csv)

  configure_columns(
    app,
    x_column = "Dato",
    y_column = "Vaerdi",
    frys_column = "Fryz"
  )
  app$set_inputs(chart_type = "run")
  app$wait_for_idle(timeout = 5000)
  expect_bfh_plot_ready(app)

  expect_true(is_shiny_true(app$get_value(output = bfh_plot_ready_output)))

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: Kommentarer
# ==============================================================================

test_that("BFHchart module: Kommentarer renderer korrekt", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("run")
  test_data$Kommentar <- c(
    rep("", 45),
    "Intervention", "Intervention", "Intervention", "Intervention", "Intervention"
  )

  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-comments-test")
  upload_test_data(app, temp_csv)

  configure_columns(
    app,
    x_column = "Dato",
    y_column = "Vaerdi",
    kommentar_column = "Kommentar"
  )
  app$set_inputs(chart_type = "run")
  app$wait_for_idle(timeout = 5000)
  expect_bfh_plot_ready(app)

  expect_true(is_shiny_true(app$get_value(output = bfh_plot_ready_output)))

  app$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: Konsistent state-output på tværs af gentagne kørsler
# ==============================================================================

test_that("BFHchart module: Output konsistent på tværs af gentagne kørsler", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("run")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  # Første kørsel
  app1 <- get_app_driver("bfh-regression-1")
  upload_test_data(app1, temp_csv)
  configure_columns(app1, x_column = "Dato", y_column = "Vaerdi")
  app1$set_inputs(chart_type = "run")
  app1$wait_for_idle(timeout = 5000)
  expect_bfh_plot_ready(app1)

  anhoej1 <- app1$get_value(output = bfh_anhoej_output)
  expect_true(!is.null(anhoej1))
  app1$stop()

  # Anden kørsel skal give identisk Anhøj-resultat (deterministisk seed)
  app2 <- get_app_driver("bfh-regression-2")
  upload_test_data(app2, temp_csv)
  configure_columns(app2, x_column = "Dato", y_column = "Vaerdi")
  app2$set_inputs(chart_type = "run")
  app2$wait_for_idle(timeout = 5000)
  expect_bfh_plot_ready(app2)

  anhoej2 <- app2$get_value(output = bfh_anhoej_output)
  expect_true(!is.null(anhoej2))
  expect_equal(anhoej1, anhoej2)

  app2$stop()
  unlink(temp_csv)
})

# ==============================================================================
# Test: Output struktur
# ==============================================================================

test_that("BFHchart module: Output struktur er korrekt", {
  skip_bfh_shinytest2()

  test_data <- create_test_csv("run")
  temp_csv <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_csv, row.names = FALSE, quote = FALSE)

  app <- get_app_driver("bfh-output-structure")
  upload_test_data(app, temp_csv)

  configure_columns(app, x_column = "Dato", y_column = "Vaerdi")
  app$set_inputs(chart_type = "run")
  app$wait_for_idle(timeout = 5000)
  expect_bfh_plot_ready(app)

  expect_true(is_shiny_true(app$get_value(output = bfh_plot_ready_output)))
  expect_true(!is.null(app$get_value(output = bfh_plot_output)))

  anhoej <- app$get_value(output = bfh_anhoej_output)
  expect_true(!is.null(anhoej))

  app$stop()
  unlink(temp_csv)
})
