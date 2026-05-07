# test-viewport-ready-signal.R
# Issue #610: Tests for viewport_ready signal that gates SPC analysis
# cold-start render until browser has produced a real layout measurement.

library(shiny)
library(testthat)

vp_module_args <- function(app_state) {
  list(
    column_config_reactive = reactive(list(x_col = "Dato", y_col = "Tæller", n_col = NULL)),
    chart_type_reactive = reactive("i"),
    target_value_reactive = reactive(NULL),
    target_text_reactive = reactive(NULL),
    centerline_value_reactive = reactive(NULL),
    skift_config_reactive = reactive(list(show_phases = FALSE, skift_column = NULL)),
    frys_config_reactive = reactive(NULL),
    app_state = app_state
  )
}

vp_test_data <- function() {
  data.frame(
    Dato = as.Date("2024-01-01") + 0:9,
    Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
  )
}

describe("Issue #610: viewport_ready signal", {
  it("input$viewport_ready event flipper gate + skriver app_state dims", {
    require_internal("visualizationModuleServer", mode = "function")
    skip_if_not_installed("later")

    app_state <- create_app_state()

    testServer(visualizationModuleServer, args = vp_module_args(app_state), {
      session$setInputs(viewport_ready = list(width = 1024, height = 600, ts = 12345))
      session$flushReact()

      dims <- shiny::isolate(app_state$visualization$viewport_dims)
      expect_equal(dims$width, 1024)
      expect_equal(dims$height, 600)
      expect_true(shiny::isolate(app_state$visualization$viewport_ready))
    })
  })

  it("legitim 800x600 viewport accepteres (ingen hardcoded ban)", {
    # Codex review: hardcoded `width != 800 || height != 600` guard er IKKE
    # sikker — reelle browser-viewports kan legitimt vaere 800x600.
    require_internal("visualizationModuleServer", mode = "function")
    skip_if_not_installed("later")

    app_state <- create_app_state()

    testServer(visualizationModuleServer, args = vp_module_args(app_state), {
      session$setInputs(viewport_ready = list(width = 800, height = 600, ts = 99999))
      session$flushReact()

      dims <- shiny::isolate(app_state$visualization$viewport_dims)
      expect_equal(dims$width, 800)
      expect_equal(dims$height, 600)
    })
  })

  it("invalid viewport_ready payload ignoreres", {
    require_internal("visualizationModuleServer", mode = "function")
    skip_if_not_installed("later")

    app_state <- create_app_state()
    app_state$visualization$viewport_dims <- list(
      width = 600, height = 400, last_updated = Sys.time()
    )

    testServer(visualizationModuleServer, args = vp_module_args(app_state), {
      session$setInputs(viewport_ready = NULL)
      session$flushReact()
      session$setInputs(viewport_ready = list(width = 50, height = 400, ts = 1))
      session$flushReact()

      dims <- shiny::isolate(app_state$visualization$viewport_dims)
      expect_true(is.null(dims$width) || dims$width >= 100)
    })
  })

  it("spc_inputs laeser viewport fra app_state (single source)", {
    require_internal("create_spc_inputs_reactive", mode = "function")

    app_state <- create_app_state()
    app_state$visualization$viewport_dims <- list(
      width = 1280, height = 720, last_updated = Sys.time()
    )
    app_state$visualization$viewport_ready <- TRUE

    test_data <- vp_test_data()

    shiny::testServer(
      function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          spc_inputs <- create_spc_inputs_reactive(
            data_ready_reactive = shiny::reactive(test_data),
            chart_config = shiny::reactive(
              list(x_col = "Dato", y_col = "Vaerdi", n_col = NULL, chart_type = "run")
            ),
            session = session,
            ns = session$ns,
            app_state = app_state,
            y_axis_unit_reactive = shiny::reactive("count")
          )

          observe({
            session$userData$captured_inputs <- spc_inputs()
          })
        })
      },
      {
        session$flushReact()
        captured <- session$userData$captured_inputs
        expect_false(is.null(captured))
        expect_equal(captured$viewport_width_px, 1280)
        expect_equal(captured$viewport_height_px, 720)
      }
    )
  })

  it("spc_inputs blokeres indtil viewport_ready flippes TRUE (cold-start gate)", {
    require_internal("create_spc_inputs_reactive", mode = "function")

    app_state <- create_app_state()
    app_state$visualization$viewport_dims <- list(
      width = 1024, height = 600, last_updated = Sys.time()
    )
    # viewport_ready starter FALSE (default fra create_app_state)

    test_data <- vp_test_data()

    shiny::testServer(
      function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          spc_inputs <- create_spc_inputs_reactive(
            data_ready_reactive = shiny::reactive(test_data),
            chart_config = shiny::reactive(
              list(x_col = "Dato", y_col = "Vaerdi", n_col = NULL, chart_type = "run")
            ),
            session = session,
            ns = session$ns,
            app_state = app_state,
            y_axis_unit_reactive = shiny::reactive("count")
          )

          eval_count <- 0
          observe({
            tryCatch(
              {
                spc_inputs()
                eval_count <<- eval_count + 1
              },
              error = function(e) NULL # nolint: swallowed_error_linter
            )
          })

          session$userData$eval_count_fn <- function() eval_count
        })
      },
      {
        session$flushReact()
        expect_equal(session$userData$eval_count_fn(), 0,
          info = "spc_inputs maa IKKE evaluere mens viewport_ready=FALSE"
        )

        app_state$visualization$viewport_ready <- TRUE
        session$flushReact()

        # Acceptkriterium #610: FONT_SCALING log entry appears exactly once
        # per upload. Hver spc_inputs-evaluering trigger en FONT_SCALING-linje.
        expect_equal(session$userData$eval_count_fn(), 1,
          info = "spc_inputs skal evaluere praecis én gang efter gate aabnes"
        )
      }
    )
  })

  it("fallback scheduler flipper gate selv uden JS-event", {
    # Acceptkriterium: "No regression for environments where clientData is
    # unavailable". Tester via injiceret synkron scheduler.
    require_internal("register_viewport_observer", mode = "function")

    app_state <- create_app_state()
    sync_scheduler <- function(callback, delay) callback()

    shiny::testServer(
      function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          register_viewport_observer(
            app_state = app_state,
            session = session,
            input = input,
            ns = session$ns,
            emit = create_emit_api(app_state),
            .scheduler = sync_scheduler
          )
        })
      },
      {
        session$flushReact()

        expect_true(shiny::isolate(app_state$visualization$viewport_ready))
        dims <- shiny::isolate(app_state$visualization$viewport_dims)
        expect_false(is.null(dims$width))
      }
    )
  })
})
