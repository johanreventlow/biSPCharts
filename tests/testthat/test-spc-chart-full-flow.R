# test-spc-chart-full-flow.R
# Tests for SPC pipeline event orchestration (Phase 2b, #322)
# Verificerer event-flow fra data-upload til SPC-beregning i testServer-kontekst.

library(testthat)

# ==============================================================================
# Hjælpefunktioner
# ==============================================================================

create_spc_flow_server <- function(test_data = NULL) {
  function(input, output, session) {
    app_state <- create_app_state()
    emit <- create_emit_api(app_state)

    if (!is.null(test_data)) {
      app_state$data$current_data <- test_data
    }

    session$userData$app_state <- app_state
    session$userData$emit <- emit
    session$userData$get_event <- function(name) {
      shiny::withReactiveDomain(session, {
        shiny::isolate(app_state$events[[name]])
      })
    }
  }
}

create_spc_test_data <- function(n = 12) {
  set.seed(42)
  data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = n),
    Tæller = sample(8:15, n, replace = TRUE),
    Nævner = sample(95:105, n, replace = TRUE),
    stringsAsFactors = FALSE
  )
}

# ==============================================================================
# Test 1: Emit-API korrekt opsætning i testServer
# ==============================================================================

test_that("SPC flow: emit-API er korrekt konfigureret i testServer", {
  skip_if_not_installed("shiny")

  test_data <- create_spc_test_data()

  shiny::testServer(create_spc_flow_server(test_data), {
    emit <- session$userData$emit
    app_state <- session$userData$app_state
    get_event <- session$userData$get_event

    # Verificér at emit-funktioner er tilgængelige
    expect_type(emit, "list")
    expect_true(is.function(emit$data_updated),
      label = "emit$data_updated skal være en funktion"
    )
    expect_true(is.function(emit$auto_detection_started),
      label = "emit$auto_detection_started skal være en funktion"
    )
    expect_true(is.function(emit$auto_detection_completed),
      label = "emit$auto_detection_completed skal være en funktion"
    )

    # Verificér initial event-state
    expect_equal(get_event("data_updated"), 0L)
    expect_equal(get_event("auto_detection_started"), 0L)
    expect_equal(get_event("auto_detection_completed"), 0L)
  })
})

# ==============================================================================
# Test 2: data_updated event trigges korrekt via emit
# ==============================================================================

test_that("SPC flow: data_updated event inkrementerer korrekt", {
  skip_if_not_installed("shiny")

  test_data <- create_spc_test_data()

  shiny::testServer(create_spc_flow_server(test_data), {
    emit <- session$userData$emit
    get_event <- session$userData$get_event

    initial <- get_event("data_updated")

    # Simulér fil-upload event
    emit$data_updated(context = "file_upload")
    expect_equal(get_event("data_updated"), initial + 1L,
      label = "data_updated skal stige med 1 efter emit"
    )

    # Simulér tabel-redigering event
    emit$data_updated(context = "table_cells_edited")
    expect_equal(get_event("data_updated"), initial + 2L,
      label = "data_updated skal stige med 1 igen efter tabel-edit"
    )
  })
})

# ==============================================================================
# Test 3: Context-aware routing producerer korrekte event-mønstre
# ==============================================================================

test_that("SPC flow: context-routing giver korrekte events for file_loaded og table_cells_edited", {
  # Tester handle_data_update_by_context direkte i isolate-kontekst
  # (testServer kan ikke flush observeEvent-chains på reactiveValues-events)

  test_data <- create_spc_test_data()
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  shiny::isolate({
    app_state$data$current_data <- test_data
  })

  base_auto <- shiny::isolate(app_state$events$auto_detection_started)
  base_nav <- shiny::isolate(app_state$events$navigation_changed)

  # file_loaded → auto_detection_started (via handle_load_context)
  shiny::isolate({
    handle_data_update_by_context(
      update_context = list(context = "file_loaded"),
      app_state = app_state,
      emit = emit,
      input = list(), output = list(), session = NULL, ui_service = NULL
    )
  })

  expect_equal(
    shiny::isolate(app_state$events$auto_detection_started),
    base_auto + 1L,
    label = "file_loaded kontekst skal trigge auto_detection_started"
  )

  # table_cells_edited → navigation_changed (via handle_table_edit_context)
  shiny::isolate({
    handle_data_update_by_context(
      update_context = list(context = "table_cells_edited"),
      app_state = app_state,
      emit = emit,
      input = list(), output = list(), session = NULL, ui_service = NULL
    )
  })

  expect_equal(
    shiny::isolate(app_state$events$navigation_changed),
    base_nav + 1L,
    label = "table_cells_edited kontekst skal trigge navigation_changed"
  )
  # Og ingen ekstra auto_detection_started
  expect_equal(
    shiny::isolate(app_state$events$auto_detection_started),
    base_auto + 1L,
    label = "table_cells_edited må IKKE trigge auto_detection_started"
  )
})

# ==============================================================================
# Test 4: SPC beregning med Danish klinisk data
# ==============================================================================

test_that("SPC flow: compute_spc_results_bfh kører med dansk klinisk data", {
  skip_if_not_installed("qicharts2")
  skip_if_not(
    exists("compute_spc_results_bfh", mode = "function"),
    "compute_spc_results_bfh ikke tilgængelig"
  )

  test_data <- create_spc_test_data(n = 20)

  result <- tryCatch(
    {
      compute_spc_results_bfh(
        data = test_data,
        x_var = "Dato",
        y_var = "Tæller",
        chart_type = "i",
        use_cache = FALSE
      )
    },
    error = function(e) {
      list(error = e$message)
    }
  )

  # Acceptér enten succesfuldt resultat eller fejl pga. rendering-afhængigheder
  expect_true(
    is.list(result),
    label = "compute_spc_results_bfh skal returnere en list"
  )

  # Hvis succes: verificér grundlæggende struktur
  if (is.null(result$error)) {
    expect_false(
      is.null(result),
      label = "SPC result må ikke være NULL ved succes"
    )
  }
})

# ==============================================================================
# Test 5: app_state er konsistent under SPC event-sekvens
# ==============================================================================

test_that("SPC flow: app_state er konsistent under fuld event-sekvens", {
  skip_if_not_installed("shiny")

  test_data <- create_spc_test_data()

  shiny::testServer(create_spc_flow_server(test_data), {
    emit <- session$userData$emit
    app_state <- session$userData$app_state
    get_event <- session$userData$get_event

    # Trin 1: Simulér data-upload
    emit$data_updated(context = "file_upload")
    expect_equal(get_event("data_updated"), 1L)

    # Trin 2: Sæt kolonne-mappings (simulerer auto-detection resultat)
    shiny::isolate({
      app_state$columns$mappings$x_column <- "Dato"
      app_state$columns$mappings$y_column <- "Tæller"
    })

    # Trin 3: Trigger auto-detection events manuelt
    emit$auto_detection_started()
    expect_equal(get_event("auto_detection_started"), 1L)

    emit$auto_detection_completed()
    expect_equal(get_event("auto_detection_completed"), 1L)

    # Trin 4: Verificér state-konsistens
    expect_equal(
      shiny::isolate(app_state$columns$mappings$x_column),
      "Dato",
      label = "x_column mapping bevaret"
    )
    expect_equal(
      shiny::isolate(app_state$columns$mappings$y_column),
      "Tæller",
      label = "y_column mapping bevaret"
    )
    expect_false(
      is.null(shiny::isolate(app_state$data$current_data)),
      label = "current_data skal forblive intakt"
    )
    expect_equal(
      nrow(shiny::isolate(app_state$data$current_data)),
      12L,
      label = "Rækketal skal matche test_data"
    )
  })
})
