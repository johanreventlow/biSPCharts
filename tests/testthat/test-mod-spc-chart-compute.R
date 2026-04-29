# test-mod-spc-chart-compute.R
# Tests for SPC computation module: create_spc_results_reactive og
# create_spc_plot_reactive. Bruger shiny::testServer() og reactive mocks.
#
# Scope: Smoke-tests (funktion eksisterer, korrekt signatur, NULL-propagation,
# cache-invalidation ved chart-type-skift). Full BFHcharts-pipeline testes
# ikke her — se test-plot-generation.R og test-spc-plot-generation-comprehensive.R.

test_that("create_spc_results_reactive eksisterer og har korrekt signatur", {
  expect_true(exists("create_spc_results_reactive", mode = "function"))

  args <- names(formals(create_spc_results_reactive))
  expect_true("spc_inputs_reactive" %in% args)
  expect_true("app_state" %in% args)
  expect_true("set_plot_state" %in% args)
  expect_true("get_plot_state" %in% args)
})

test_that("create_spc_plot_reactive eksisterer og har korrekt signatur", {
  expect_true(exists("create_spc_plot_reactive", mode = "function"))

  args <- names(formals(create_spc_plot_reactive))
  expect_true("spc_results_reactive" %in% args)
  expect_true("spc_inputs_reactive" %in% args)
  expect_true("app_state" %in% args)
})

test_that("create_spc_plot_reactive propagerer NULL naar spc_results returnerer NULL plot", {
  # Verify NULL-propagation: Hvis computation fejler (spc_results$plot = NULL),
  # skal create_spc_plot_reactive returnere NULL (ingen crash, ingen tom ggplot).
  shiny::testServer(
    function(input, output, session) {
      mock_results <- shiny::reactive({
        list(plot = NULL, qic_data = NULL, cache_key = "test_key")
      })
      mock_inputs <- shiny::reactive({
        list(base_size = 12)
      })

      # Opret en minimal app_state
      app_state <- shiny::reactiveValues(
        visualization = shiny::reactiveValues(
          viewport_width = 800,
          viewport_height = 600
        )
      )

      plot_reactive <- create_spc_plot_reactive(mock_results, mock_inputs, app_state)
      result <- plot_reactive()
      expect_null(result)
    },
    expr = {}
  )
})

test_that("create_spc_results_reactive returnerer NULL-plot ved ugyldig data (for faa raekker)", {
  # Verify at validation-fejl giver NULL plot (ikke crash).
  # Bruger data med 0 raekker som fejler validateDataForChart().
  skip_if_not(
    exists("validateDataForChart", mode = "function"),
    "validateDataForChart ikke tilgaengelig"
  )

  shiny::testServer(
    function(input, output, session) {
      empty_data <- data.frame(
        Dato = as.Date(character(0)),
        Vaerdi = numeric(0),
        Skift = logical(0),
        Frys = logical(0)
      )

      app_state <- shiny::reactiveValues(
        visualization = shiny::reactiveValues(
          viewport_width = 800,
          viewport_height = 600,
          last_centerline_value = NULL
        ),
        cache = NULL
      )

      plot_state <- list()
      set_plot_state_fn <- function(key, value) {
        plot_state[[key]] <<- value
      }
      get_plot_state_fn <- function(key) {
        plot_state[[key]]
      }

      mock_inputs <- shiny::reactive({
        list(
          data = empty_data,
          data_hash = "empty",
          chart_type = "p",
          config = list(x_col = "Dato", y_col = "Vaerdi", n_col = NULL),
          target_value = NULL,
          target_text = NULL,
          centerline_value = NULL,
          skift_config = list(show_phases = FALSE, skift_column = "Skift"),
          frys_column = "Frys",
          y_axis_unit = "percent",
          kommentar_column = NULL,
          base_size = 12,
          title = NULL,
          skift_hash = "empty",
          frys_hash = "empty"
        )
      })

      results_reactive <- create_spc_results_reactive(
        mock_inputs,
        app_state,
        set_plot_state_fn,
        get_plot_state_fn
      )

      result <- results_reactive()
      expect_null(result$plot)
      expect_false(is.null(result$cache_key))
    },
    expr = {}
  )
})

test_that("cache_key aendres naar chart_type aendres", {
  # Verify cache-invalidation: Forskellig chart_type → forskellig cache_key.
  # Forhindrer #62 (dimension bleeding på tværs af kontekster).
  shiny::testServer(
    function(input, output, session) {
      chart_type_val <- shiny::reactiveVal("p")

      app_state <- shiny::reactiveValues(
        visualization = shiny::reactiveValues(
          viewport_width = 800,
          viewport_height = 600,
          last_centerline_value = NULL
        ),
        cache = NULL
      )

      test_data <- data.frame(
        Dato = seq.Date(as.Date("2023-01-01"), by = "month", length.out = 3),
        Vaerdi = c(0.1, 0.2, 0.3),
        N = c(10L, 10L, 10L),
        Skift = c(FALSE, FALSE, FALSE),
        Frys = c(FALSE, FALSE, FALSE)
      )

      plot_state <- list()
      set_plot_state_fn <- function(key, value) {
        plot_state[[key]] <<- value
      }
      get_plot_state_fn <- function(key) {
        plot_state[[key]]
      }

      mock_inputs <- shiny::reactive({
        list(
          data = test_data,
          data_hash = "hash1",
          chart_type = chart_type_val(),
          config = list(x_col = "Dato", y_col = "Vaerdi", n_col = "N"),
          target_value = NULL,
          target_text = NULL,
          centerline_value = NULL,
          skift_config = list(show_phases = FALSE, skift_column = "Skift"),
          frys_column = "Frys",
          y_axis_unit = "percent",
          kommentar_column = NULL,
          base_size = 12,
          title = NULL,
          skift_hash = "empty",
          frys_hash = "empty"
        )
      })

      results_reactive <- create_spc_results_reactive(
        mock_inputs,
        app_state,
        set_plot_state_fn,
        get_plot_state_fn
      )

      result_p <- results_reactive()
      cache_key_p <- result_p$cache_key

      chart_type_val("c")
      result_c <- results_reactive()
      cache_key_c <- result_c$cache_key

      expect_false(
        identical(cache_key_p, cache_key_c),
        info = "Cache-key skal aendre sig naar chart_type aendres (forebygger cache bleeding)"
      )
    },
    expr = {}
  )
})

test_that("register_cache_aware_observer eksisterer og har korrekt signatur", {
  expect_true(exists("register_cache_aware_observer", mode = "function"))

  args <- names(formals(register_cache_aware_observer))
  expect_true("spc_results_reactive" %in% args)
  expect_true("app_state" %in% args)
  expect_true("set_plot_state" %in% args)
  expect_true("get_plot_state" %in% args)
})
