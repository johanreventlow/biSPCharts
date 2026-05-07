# test-viewport-ready-signal.R
# Issue #610: Tests for viewport_ready signal that gates SPC analysis
# cold-start render until browser has produced a real layout measurement.
#
# Key invariants verified:
#   1. spc_inputs_raw is gated on viewport_ready_signal (cold-start blocking)
#   2. JS event input$viewport_ready flips signal + writes app_state dims
#   3. later::later(2s) timeout fallback flips signal even without JS event
#   4. Legitim 800x600 viewport from JS is NOT filtered (no hardcoded ban)
#   5. Single source of truth: spc_inputs reads viewport from app_state,
#      not from session$clientData directly

library(shiny)
library(testthat)

# Helper aligned with test-mod-spc-chart-comprehensive.R
create_mock_app_state <- function() {
  app_state <- new.env(parent = emptyenv())
  app_state$events <- reactiveValues(
    visualization_update_needed = 0L,
    navigation_changed = 0L
  )
  app_state$data <- reactiveValues(current_data = NULL, updating_table = FALSE)
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
    last_centerline_value = NULL,
    viewport_dims = list(width = NULL, height = NULL, last_updated = NULL)
  )
  app_state$columns <- reactiveValues(
    auto_detect = reactiveValues(
      in_progress = FALSE, completed = FALSE,
      results = NULL, frozen_until_next_trigger = FALSE
    ),
    mappings = reactiveValues(x_column = NULL, y_column = NULL, n_column = NULL)
  )
  app_state$ui <- reactiveValues(hide_anhoej_rules = FALSE)
  app_state
}

describe("Issue #610: viewport_ready signal", {
  it("input$viewport_ready event flips signal + writes app_state dims", {
    require_internal("visualizationModuleServer", mode = "function")
    skip_if_not_installed("later")

    app_state <- create_mock_app_state()

    testServer(
      visualizationModuleServer,
      args = list(
        column_config_reactive = reactive(list(x_col = "Dato", y_col = "Tæller", n_col = NULL)),
        chart_type_reactive = reactive("i"),
        target_value_reactive = reactive(NULL),
        target_text_reactive = reactive(NULL),
        centerline_value_reactive = reactive(NULL),
        skift_config_reactive = reactive(list(show_phases = FALSE, skift_column = NULL)),
        frys_config_reactive = reactive(NULL),
        app_state = app_state
      ),
      {
        # Simuler JS-event: ResizeObserver har maalt en reel layout
        session$setInputs(viewport_ready = list(width = 1024, height = 600, ts = 12345))
        session$flushReact()

        dims <- shiny::isolate(app_state$visualization$viewport_dims)
        expect_equal(dims$width, 1024,
          info = "viewport_ready event skal opdatere app_state width"
        )
        expect_equal(dims$height, 600,
          info = "viewport_ready event skal opdatere app_state height"
        )
      }
    )
  })

  it("legitim 800x600 viewport accepteres (ingen hardcoded ban)", {
    # Codex review: hardcoded `width != 800 || height != 600` guard er IKKE
    # sikker — reelle browser-viewports kan legitimt vaere 800x600.
    require_internal("visualizationModuleServer", mode = "function")
    skip_if_not_installed("later")

    app_state <- create_mock_app_state()

    testServer(
      visualizationModuleServer,
      args = list(
        column_config_reactive = reactive(list(x_col = "Dato", y_col = "Tæller", n_col = NULL)),
        chart_type_reactive = reactive("i"),
        target_value_reactive = reactive(NULL),
        target_text_reactive = reactive(NULL),
        centerline_value_reactive = reactive(NULL),
        skift_config_reactive = reactive(list(show_phases = FALSE, skift_column = NULL)),
        frys_config_reactive = reactive(NULL),
        app_state = app_state
      ),
      {
        # Simuler reel 800x600 browser-viewport via JS-event
        session$setInputs(viewport_ready = list(width = 800, height = 600, ts = 99999))
        session$flushReact()

        dims <- shiny::isolate(app_state$visualization$viewport_dims)
        expect_equal(dims$width, 800,
          info = "Reel 800x600 viewport skal accepteres, ikke filtreres"
        )
        expect_equal(dims$height, 600,
          info = "Reel 800x600 viewport skal accepteres, ikke filtreres"
        )
      }
    )
  })

  it("invalid viewport_ready payload ignoreres (defensive)", {
    require_internal("visualizationModuleServer", mode = "function")
    skip_if_not_installed("later")

    app_state <- create_mock_app_state()
    # Pre-set kendt vaerdi for at kunne detektere uoenskede skrivninger
    app_state$visualization$viewport_dims <- list(
      width = 600, height = 400, last_updated = Sys.time()
    )

    testServer(
      visualizationModuleServer,
      args = list(
        column_config_reactive = reactive(list(x_col = "Dato", y_col = "Tæller", n_col = NULL)),
        chart_type_reactive = reactive("i"),
        target_value_reactive = reactive(NULL),
        target_text_reactive = reactive(NULL),
        centerline_value_reactive = reactive(NULL),
        skift_config_reactive = reactive(list(show_phases = FALSE, skift_column = NULL)),
        frys_config_reactive = reactive(NULL),
        app_state = app_state
      ),
      {
        # NULL payload — observer skal ignorere
        session$setInputs(viewport_ready = NULL)
        session$flushReact()

        # Width <= 100 — observer skal ignorere
        session$setInputs(viewport_ready = list(width = 50, height = 400, ts = 1))
        session$flushReact()

        # mockclientdata vil dog skrive 600x400 via Observer 1, saa vi
        # kan ikke direkte teste at viewport_ready-payload blev ignoreret.
        # Indirekte test: signalet flippes IKKE af invalid payload alene.
        # (Vi kan ikke direkte assert paa det interne signal her — men hvis
        # observer-logikken var brudt, ville set_viewport_dims overskrive
        # med invalid vaerdier hvilket vi tjekker for.)
        dims <- shiny::isolate(app_state$visualization$viewport_dims)
        expect_true(is.null(dims$width) || dims$width >= 100,
          info = "Invalid viewport_ready-payload (width<100) maa ikke skrive til app_state"
        )
      }
    )
  })

  it("spc_inputs uses viewport from app_state, not clientData (single source)", {
    # Issue #610 single-source-invariant: efter denne PR laeses viewport
    # i create_spc_inputs_reactive fra get_viewport_dims(app_state), IKKE
    # fra session$clientData direkte. Verificerer ved at saette kendt
    # vaerdi i app_state og bekraefte at compute-pipelinen bruger den.
    require_internal("create_spc_inputs_reactive", mode = "function")

    app_state <- create_mock_app_state()
    # Saet kendte dims i app_state
    app_state$visualization$viewport_dims <- list(
      width = 1280, height = 720, last_updated = Sys.time()
    )

    # Reactive-baseret unit-test: byg reactive-graf direkte
    test_data <- data.frame(
      Dato = as.Date("2024-01-01") + 0:9,
      Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
    )

    shiny::testServer(
      function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          # Simuler at viewport_ready_signal allerede er flippet
          viewport_ready_signal <- shiny::reactiveVal(TRUE)

          data_ready_reactive <- shiny::reactive(test_data)
          chart_config_reactive <- shiny::reactive(
            list(x_col = "Dato", y_col = "Vaerdi", n_col = NULL, chart_type = "run")
          )

          spc_inputs <- create_spc_inputs_reactive(
            data_ready_reactive = data_ready_reactive,
            chart_config = chart_config_reactive,
            session = session,
            ns = session$ns,
            app_state = app_state,
            viewport_ready_signal = viewport_ready_signal,
            y_axis_unit_reactive = shiny::reactive("count")
          )

          observe({
            inputs <- spc_inputs()
            session$userData$captured_inputs <- inputs
          })
        })
      },
      {
        session$flushReact()
        captured <- session$userData$captured_inputs
        expect_false(is.null(captured),
          info = "spc_inputs skal evaluere efter signal flippes TRUE"
        )
        expect_equal(captured$viewport_width_px, 1280,
          info = "spc_inputs skal laese width fra app_state, ikke clientData"
        )
        expect_equal(captured$viewport_height_px, 720,
          info = "spc_inputs skal laese height fra app_state, ikke clientData"
        )
      }
    )
  })

  it("spc_inputs blocks until viewport_ready_signal flips TRUE (cold-start gate)", {
    require_internal("create_spc_inputs_reactive", mode = "function")

    app_state <- create_mock_app_state()
    app_state$visualization$viewport_dims <- list(
      width = 1024, height = 600, last_updated = Sys.time()
    )

    test_data <- data.frame(
      Dato = as.Date("2024-01-01") + 0:9,
      Vaerdi = c(10, 12, 11, 14, 13, 15, 11, 12, 14, 13)
    )

    shiny::testServer(
      function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          # Signal starter FALSE — som i prod cold-start
          viewport_ready_signal <- shiny::reactiveVal(FALSE)

          data_ready_reactive <- shiny::reactive(test_data)
          chart_config_reactive <- shiny::reactive(
            list(x_col = "Dato", y_col = "Vaerdi", n_col = NULL, chart_type = "run")
          )

          spc_inputs <- create_spc_inputs_reactive(
            data_ready_reactive = data_ready_reactive,
            chart_config = chart_config_reactive,
            session = session,
            ns = session$ns,
            app_state = app_state,
            viewport_ready_signal = viewport_ready_signal,
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

          # Eksponer eval_count + signal til outer test
          session$userData$eval_count_fn <- function() eval_count
          session$userData$flip_signal <- function() viewport_ready_signal(TRUE)
        })
      },
      {
        session$flushReact()
        # Signal er FALSE — req() blokker, ingen full evaluation
        count_before <- session$userData$eval_count_fn()
        expect_equal(count_before, 0,
          info = "spc_inputs maa IKKE evaluere foer viewport_ready_signal er TRUE"
        )

        # Flip signal — spc_inputs skal nu evaluere
        session$userData$flip_signal()
        session$flushReact()

        count_after <- session$userData$eval_count_fn()
        # Acceptkriterium #610: "FONT_SCALING log entry appears exactly once
        # per upload (not twice)". Hver spc_inputs-evaluering trigger en
        # FONT_SCALING log-linje, saa eval_count == 1 svarer til log == 1.
        expect_equal(count_after, 1,
          info = paste0(
            "spc_inputs skal evaluere PRAECIS ÉN gang efter signal flippes TRUE ",
            "(forhindrer dobbelt-render fra Issue #610). Faktisk: ",
            count_after
          )
        )
      }
    )
  })

  it("fallback scheduler flipper signal selv uden JS-event", {
    # Acceptkriterium: "No regression for environments where clientData is
    # unavailable". Headless/JS-disabled miljoer — fallback-timeren skal
    # flippe signalet alligevel. Tester via injiceret synkron scheduler
    # for deterministisk eksekvering uden afhaengighed af later::later
    # globale koe (state-pollution mellem tests).
    require_internal("register_viewport_observer", mode = "function")

    app_state <- create_mock_app_state()
    viewport_ready_signal <- shiny::reactiveVal(FALSE)

    # Synkron scheduler — kalder callback straks
    sync_scheduler <- function(callback, delay) {
      callback()
    }

    shiny::testServer(
      function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          emit <- create_emit_api(app_state)
          register_viewport_observer(
            app_state = app_state,
            session = session,
            input = input,
            ns = session$ns,
            emit = emit,
            viewport_ready_signal = viewport_ready_signal,
            fallback_delay_secs = 0,
            .scheduler = sync_scheduler
          )
        })
      },
      {
        session$flushReact()

        expect_true(shiny::isolate(viewport_ready_signal()),
          info = "Fallback-scheduler skal flippe signal TRUE selv uden JS-event"
        )
        # Fallback skal saette VIEWPORT_DEFAULTS i app_state naar clientData/
        # eksisterende dims er tomme.
        dims <- shiny::isolate(app_state$visualization$viewport_dims)
        expect_false(is.null(dims$width),
          info = "Fallback skal skrive width til app_state"
        )
      }
    )
  })
})
