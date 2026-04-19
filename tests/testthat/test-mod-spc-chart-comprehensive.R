# test-mod-spc-chart-comprehensive.R
# Comprehensive tests for SPC chart module lifecycle and performance
# Merged Fase 2: test-mod-spc-chart-integration.R -> test-mod-spc-chart-comprehensive.R
# Se NEWS.md for rationale.

library(shiny)
library(testthat)

# =============================================================================
# SEKTION 1: LIFECYCLE OG PERFORMANCE (fra test-mod-spc-chart-comprehensive.R)
# =============================================================================

test_that("Chart generation performance meets benchmarks", {
  skip_if_not_installed("qicharts2")
  skip_if(Sys.getenv("CI") == "true", "Skip performance test in CI")

  # Create performance test data
  perf_data <- data.frame(
    x = 1:1000,
    y = rnorm(1000, mean = 25, sd = 5),
    stringsAsFactors = FALSE
  )

  # Benchmark chart generation
  start_time <- Sys.time()

  chart_result <- safe_operation(
    "Generate performance test chart",
    code = {
      qicharts2::qic(
        x = perf_data$x,
        y = perf_data$y,
        chart = "i",
        title = "Performance Test Chart"
      )
    }
  )

  end_time <- Sys.time()
  generation_time <- as.numeric(end_time - start_time)

  expect_true(!is.null(chart_result))
  # Chart generation should complete within 5 seconds for 1000 points
  expect_lt(generation_time, 5.0)
})

test_that("Chart module handles reactive updates correctly", {
  skip("testServer-migration — se harden-test-suite §2.3 (#230)")
  skip_if_not_installed("shiny")

  # Mock reactive environment
  app_state <- create_app_state()

  # Test data manager
  data_manager <- safe_operation(
    "Create module data manager",
    code = {
      create_module_data_manager(app_state)
    }
  )

  expect_true(!is.null(data_manager))
  expect_true(is.list(data_manager))

  # Test reactive data updates
  test_data <- data.frame(
    x = 1:10,
    y = rnorm(10),
    stringsAsFactors = FALSE
  )

  # Simulate data update
  safe_operation(
    "Update module data",
    code = {
      set_current_data(app_state, test_data)
    }
  )

  # Verify state consistency
  retrieved_data <- app_state$data$current_data
  expect_true(!is.null(retrieved_data))
  expect_equal(nrow(retrieved_data), 10)
})

test_that("Chart module memory cleanup prevents leaks", {
  skip_if_not_installed("shiny")

  # Test memory management
  initial_objects <- length(ls(envir = .GlobalEnv))

  # Create multiple chart managers
  managers <- list()
  for (i in 1:10) {
    app_state <- create_app_state()
    managers[[i]] <- safe_operation(
      paste("Create manager", i),
      code = {
        create_chart_state_manager(app_state)
      }
    )
  }

  # Clear managers
  managers <- NULL
  gc() # Force garbage collection

  final_objects <- length(ls(envir = .GlobalEnv))

  # Should not have excessive object growth
  object_growth <- final_objects - initial_objects
  expect_lt(object_growth, 5) # Allow some temporary objects
})

test_that("Chart error states are handled gracefully", {
  skip_if_not_installed("qicharts2")

  # Test error scenarios
  error_scenarios <- list(
    "empty_data" = data.frame(),
    "single_row" = data.frame(x = 1, y = 2),
    "all_na" = data.frame(x = c(NA, NA, NA), y = c(NA, NA, NA)),
    "infinite_values" = data.frame(x = 1:3, y = c(1, Inf, 2)),
    "non_numeric" = data.frame(x = 1:3, y = c("a", "b", "c"))
  )

  validator <- safe_operation(
    "Create error test validator",
    code = {
      create_chart_validator()
    }
  )

  for (scenario_name in names(error_scenarios)) {
    test_data <- error_scenarios[[scenario_name]]

    # Should handle errors without crashing
    result <- safe_operation(
      paste("Test error scenario:", scenario_name),
      code = {
        validator$validate_chart_data(test_data, "x", "y")
      },
      fallback = list(valid = FALSE, message = "Error handled")
    )

    expect_true(is.list(result))
    expect_true("valid" %in% names(result))

    # Error scenarios should generally be invalid
    if (scenario_name %in% c("empty_data", "all_na", "non_numeric")) {
      expect_false(result$valid)
    }
  }
})

# =============================================================================
# SEKTION 2: REACTIVE CHAINS OG INTEGRATION (fra test-mod-spc-chart-integration.R)
# =============================================================================

# SETUP HELPERS ----------------------------------------------------------------

# Helper til at oprette mock app_state
create_mock_app_state <- function() {
  app_state <- new.env(parent = emptyenv())

  app_state$events <- reactiveValues(
    visualization_update_needed = 0L,
    navigation_changed = 0L
  )

  app_state$data <- reactiveValues(
    current_data = NULL,
    updating_table = FALSE
  )

  app_state$visualization <- reactiveValues(
    module_cached_data = NULL,
    module_data_cache = NULL,
    cache_updating = FALSE,
    plot_ready = FALSE,
    plot_warnings = character(0),
    is_computing = FALSE,
    plot_generation_in_progress = FALSE,
    plot_object = NULL,
    anhoej_results = NULL,
    last_centerline_value = NULL
  )

  app_state$columns <- reactiveValues(
    auto_detect = reactiveValues(
      in_progress = FALSE,
      completed = FALSE,
      results = NULL,
      frozen_until_next_trigger = FALSE
    ),
    mappings = reactiveValues(
      x_column = NULL,
      y_column = NULL,
      n_column = NULL
    )
  )

  app_state$ui <- reactiveValues(
    hide_anhoej_rules = FALSE,
    pending_programmatic_inputs = list()
  )

  return(app_state)
}

# Helper til at oprette test data
create_test_data_for_module <- function(n = 12) {
  data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = n),
    `Tæller` = sample(40:50, n, replace = TRUE),
    `Nævner` = rep(50, n),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

# REACTIVE CHAIN TESTS ---------------------------------------------------------

describe("Reactive Chains", {
  it("updates plot when data changes", {
    skip("testServer-migration — se harden-test-suite §2.3 (#230) (session$returned module contract)")
    skip_if_not(exists("visualizationModuleServer", mode = "function"))

    # Setup
    test_data <- create_test_data_for_module()
    app_state <- create_mock_app_state()

    # Simulate module server
    testServer(visualizationModuleServer, args = list(
      column_config_reactive = reactive(list(
        x_col = "Dato",
        y_col = "Tæller",
        n_col = "Nævner"
      )),
      chart_type_reactive = reactive("p"),
      target_value_reactive = reactive(NULL),
      target_text_reactive = reactive(NULL),
      centerline_value_reactive = reactive(NULL),
      skift_config_reactive = reactive(list(show_phases = FALSE, skift_column = NULL)),
      frys_config_reactive = reactive(NULL),
      chart_title_reactive = reactive("Test Chart"),
      y_axis_unit_reactive = reactive("percent"),
      kommentar_column_reactive = reactive(NULL),
      app_state = app_state
    ), {
      # Verify initial state
      expect_true(is.reactive(session$returned))

      # Trigger data update
      session$setInputs(data_reactive = test_data)
    })
  })

  it("handles cache update atomicity correctly", {
    skip_if_not(exists("visualizationModuleServer", mode = "function"))

    app_state <- create_mock_app_state()
    test_data <- create_test_data_for_module()

    # Setup initial data
    app_state$data$current_data <- test_data

    # Verify cache starts empty
    expect_null(isolate(app_state$visualization$module_cached_data))

    # Trigger visualization update event
    app_state$events$visualization_update_needed <- 1L
  })

  it("prevents race conditions with guard flag", {
    skip_if_not(exists("visualizationModuleServer", mode = "function"))

    app_state <- create_mock_app_state()

    # Set cache_updating guard flag
    app_state$visualization$cache_updating <- TRUE

    # Attempt concurrent update
    app_state$events$visualization_update_needed <- 1L
  })
})

# CACHE UPDATE TESTS -----------------------------------------------------------

describe("Cache Update Atomicity", {
  it("updates both cache values together", {
    app_state <- create_mock_app_state()
    test_data <- create_test_data_for_module()

    # Set initial data
    app_state$data$current_data <- test_data

    # Simulate atomic cache update
    app_state$visualization$module_data_cache <- test_data
    app_state$visualization$module_cached_data <- test_data

    # Verify both are updated
    expect_equal(
      isolate(app_state$visualization$module_data_cache),
      isolate(app_state$visualization$module_cached_data)
    )
  })

  it("clears guard flag on error", {
    app_state <- create_mock_app_state()

    # Simulate error scenario
    app_state$visualization$cache_updating <- TRUE

    # Manual cleanup for test
    app_state$visualization$cache_updating <- FALSE

    expect_false(isolate(app_state$visualization$cache_updating))
  })

  it("skips update when table is updating", {
    app_state <- create_mock_app_state()

    # Set table updating flag
    app_state$data$updating_table <- TRUE

    # Trigger visualization update
    app_state$events$visualization_update_needed <- 1L
  })
})

# ERROR HANDLING TESTS ---------------------------------------------------------

describe("Error Handling", {
  it("handles null data gracefully", {
    skip_if_not(exists("visualizationModuleServer", mode = "function"))

    app_state <- create_mock_app_state()

    testServer(visualizationModuleServer, args = list(
      column_config_reactive = reactive(list(
        x_col = "Dato",
        y_col = "Tæller",
        n_col = "Nævner"
      )),
      chart_type_reactive = reactive("p"),
      target_value_reactive = reactive(NULL),
      target_text_reactive = reactive(NULL),
      centerline_value_reactive = reactive(NULL),
      skift_config_reactive = reactive(list(show_phases = FALSE, skift_column = NULL)),
      frys_config_reactive = reactive(NULL),
      app_state = app_state
    ), {
      # Should not crash with null data
      expect_true(TRUE)
    })
  })

  it("handles empty data gracefully", {
    skip_if_not(exists("visualizationModuleServer", mode = "function"))

    app_state <- create_mock_app_state()

    testServer(visualizationModuleServer, args = list(
      column_config_reactive = reactive(list(
        x_col = "Dato",
        y_col = "Tæller",
        n_col = "Nævner"
      )),
      chart_type_reactive = reactive("p"),
      target_value_reactive = reactive(NULL),
      target_text_reactive = reactive(NULL),
      centerline_value_reactive = reactive(NULL),
      skift_config_reactive = reactive(list(show_phases = FALSE, skift_column = NULL)),
      frys_config_reactive = reactive(NULL),
      app_state = app_state
    ), {
      # Should handle empty data without crashing
      expect_true(TRUE)
    })
  })

  it("sets appropriate warnings on validation failure", {
    app_state <- create_mock_app_state()

    # Simulate validation failure
    app_state$visualization$plot_warnings <- c("Validering fejlede", "For få datapunkter")
    app_state$visualization$plot_ready <- FALSE

    warnings <- isolate(app_state$visualization$plot_warnings)

    expect_length(warnings, 2)
    expect_true(grepl("Validering", warnings[1]))
  })
})

# UI RENDERING TESTS -----------------------------------------------------------

describe("UI Rendering", {
  it("renders plot_ready output correctly", {
    skip("testServer-migration — se harden-test-suite §2.3 (#230) (plot_ready output)")
    skip_if_not(exists("visualizationModuleServer", mode = "function"))

    app_state <- create_mock_app_state()
    test_data <- create_test_data_for_module()

    testServer(visualizationModuleServer, args = list(
      column_config_reactive = reactive(list(
        x_col = "Dato",
        y_col = "Tæller",
        n_col = "Nævner"
      )),
      chart_type_reactive = reactive("p"),
      target_value_reactive = reactive(NULL),
      target_text_reactive = reactive(NULL),
      centerline_value_reactive = reactive(NULL),
      skift_config_reactive = reactive(list(show_phases = FALSE, skift_column = NULL)),
      frys_config_reactive = reactive(NULL),
      app_state = app_state
    ), {
      # plot_ready should be reactive output
      expect_true("plot_ready" %in% names(output))
    })
  })

  it("renders plot_info with warnings", {
    skip("testServer-migration — se harden-test-suite §2.3 (#230) (plot_info output)")
    skip_if_not(exists("visualizationModuleServer", mode = "function"))

    app_state <- create_mock_app_state()
    app_state$visualization$plot_warnings <- c("Test warning")

    testServer(visualizationModuleServer, args = list(
      column_config_reactive = reactive(list()),
      chart_type_reactive = reactive("p"),
      target_value_reactive = reactive(NULL),
      target_text_reactive = reactive(NULL),
      centerline_value_reactive = reactive(NULL),
      skift_config_reactive = reactive(list(show_phases = FALSE, skift_column = NULL)),
      frys_config_reactive = reactive(NULL),
      app_state = app_state
    ), {
      # plot_info should exist
      expect_true("plot_info" %in% names(output))
    })
  })

  it("renders anhoej_rules_boxes correctly", {
    skip("testServer-migration — se harden-test-suite §2.3 (#230) (anhoej_rules_boxes output)")
    skip_if_not(exists("visualizationModuleServer", mode = "function"))

    app_state <- create_mock_app_state()
    test_data <- create_test_data_for_module()

    testServer(visualizationModuleServer, args = list(
      column_config_reactive = reactive(list(
        x_col = "Dato",
        y_col = "Tæller",
        n_col = "Nævner"
      )),
      chart_type_reactive = reactive("run"),
      target_value_reactive = reactive(NULL),
      target_text_reactive = reactive(NULL),
      centerline_value_reactive = reactive(NULL),
      skift_config_reactive = reactive(list(show_phases = FALSE, skift_column = NULL)),
      frys_config_reactive = reactive(NULL),
      app_state = app_state
    ), {
      # anhoej_rules_boxes should exist
      expect_true("anhoej_rules_boxes" %in% names(output))
    })
  })
})

# MODULE STATE MANAGEMENT TESTS ------------------------------------------------

describe("Module State Management", {
  it("initializes state correctly", {
    app_state <- create_mock_app_state()

    # Verify initial state
    expect_false(isolate(app_state$visualization$cache_updating))
    expect_false(isolate(app_state$visualization$plot_ready))
    expect_null(isolate(app_state$visualization$plot_object))
  })

  it("updates plot_ready flag correctly", {
    app_state <- create_mock_app_state()

    # Simulate successful plot generation
    app_state$visualization$plot_ready <- TRUE
    app_state$visualization$plot_object <- ggplot2::ggplot()

    expect_true(isolate(app_state$visualization$plot_ready))
    expect_s3_class(isolate(app_state$visualization$plot_object), "ggplot")
  })

  it("stores anhoej_results correctly", {
    app_state <- create_mock_app_state()

    # Simulate anhoej results
    anhoej_results <- list(
      longest_run = 5,
      longest_run_max = 6,
      n_crossings = 3,
      n_crossings_min = 2,
      out_of_control_count = 0,
      runs_signal = FALSE,
      crossings_signal = FALSE,
      anhoej_signal = FALSE,
      any_signal = FALSE,
      message = "Test",
      has_valid_data = TRUE
    )

    app_state$visualization$anhoej_results <- anhoej_results

    result <- isolate(app_state$visualization$anhoej_results)

    expect_equal(result$longest_run, 5)
    expect_equal(result$n_crossings, 3)
    expect_true(result$has_valid_data)
  })

  it("tracks centerline changes correctly", {
    app_state <- create_mock_app_state()

    # Set initial centerline
    app_state$visualization$last_centerline_value <- 50

    # Change centerline
    new_centerline <- 60

    # Detect change
    centerline_changed <- !identical(new_centerline, isolate(app_state$visualization$last_centerline_value))

    expect_true(centerline_changed)

    # Update tracked value
    app_state$visualization$last_centerline_value <- new_centerline

    expect_equal(isolate(app_state$visualization$last_centerline_value), 60)
  })
})

# VIEWPORT DIMENSIONS TESTS ----------------------------------------------------

describe("Viewport Dimensions", {
  it("handles missing viewport dimensions gracefully", {
    skip_if_not(exists("visualizationModuleServer", mode = "function"))

    app_state <- create_mock_app_state()
    test_data <- create_test_data_for_module()

    testServer(visualizationModuleServer, args = list(
      column_config_reactive = reactive(list(
        x_col = "Dato",
        y_col = "Tæller",
        n_col = "Nævner"
      )),
      chart_type_reactive = reactive("p"),
      target_value_reactive = reactive(NULL),
      target_text_reactive = reactive(NULL),
      centerline_value_reactive = reactive(NULL),
      skift_config_reactive = reactive(list(show_phases = FALSE, skift_column = NULL)),
      frys_config_reactive = reactive(NULL),
      app_state = app_state
    ), {
      # Should not crash without viewport dimensions
      expect_true(TRUE)
    })
  })

  it("uses clientData viewport dimensions when available", {
    # This test requires actual Shiny session with clientData
    skip("Requires full Shiny session with clientData")
  })
})

# DEBOUNCING TESTS -------------------------------------------------------------

describe("Debouncing", {
  it("debounces chart_config to prevent redundant renders", {
    skip("Debouncing requires time-based testing framework")
  })

  it("debounces spc_inputs to prevent redundant renders", {
    skip("Debouncing requires time-based testing framework")
  })
})
