test_that("emit$navigation_requested increments event counter and stores target", {
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  shiny::isolate({
    counter_before <- app_state$events$navigation_requested
    emit$navigation_requested("upload")

    expect_equal(
      app_state$events$navigation_requested,
      counter_before + 1L
    )
    expect_equal(app_state$navigation$guard_pending_target, "upload")
  })
})

test_that("emit$navigation_requested validates target argument", {
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  shiny::isolate({
    # Ugyldigt target -> tving til "upload" + log advarsel
    emit$navigation_requested("malicious; rm -rf /")
    expect_equal(app_state$navigation$guard_pending_target, "upload")
  })
})

test_that("guard-listener triggers direct nav when current_data is NULL", {
  # reactiveConsole = TRUE aktiverer reaktiv evaluering uden kørende Shiny-app.
  # Nødvendigt for at observeEvent registreret uden for testServer kan flushe.
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()
  nav_select_calls <- list()

  # Intercept bslib::nav_select med local mock
  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) {
      nav_select_calls[[length(nav_select_calls) + 1]] <<- list(
        id = id, selected = selected
      )
    },
    .package = "bslib"
  )

  setup_navigation_guard_listener(app_state, emit, session, session$input)

  # TODO: move to testServer() wrapper; shiny::: needed until guard-listener has a server-function home (Task 4 may enable this)
  # Første flush forbruger ignoreInit = TRUE
  shiny:::flushReact()

  expect_null(shiny::isolate(app_state$data$current_data))
  emit$navigation_requested("upload")

  # Anden flush udløser observer-kroppen
  shiny:::flushReact()

  expect_length(nav_select_calls, 1)
  expect_equal(nav_select_calls[[1]]$selected, "upload")
  expect_equal(nav_select_calls[[1]]$id, "main_navbar")
  expect_null(shiny::isolate(app_state$navigation$guard_pending_target))
  expect_false(isTRUE(shiny::isolate(app_state$navigation$guard_modal_open)))
})

test_that("guard-listener shows modal when current_data has rows", {
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:5, y = 6:10)
  })

  show_modal_calls <- list()
  testthat::local_mocked_bindings(
    showModal = function(ui, session = NULL) {
      show_modal_calls[[length(show_modal_calls) + 1]] <<- ui
    },
    .package = "shiny"
  )

  setup_navigation_guard_listener(app_state, emit, session, session$input)

  # Første flush forbruger ignoreInit = TRUE
  shiny:::flushReact()

  emit$navigation_requested("start")

  # Anden flush udløser observer-kroppen
  shiny:::flushReact()

  expect_length(show_modal_calls, 1)
  expect_true(isTRUE(shiny::isolate(app_state$navigation$guard_modal_open)))
  expect_equal(shiny::isolate(app_state$navigation$guard_pending_target), "start")
})

test_that("navigation_guard_modal contains both knapper + checkbox", {
  modal <- navigation_guard_modal()
  html <- as.character(modal)
  expect_match(html, "nav_guard_confirm")
  expect_match(html, "nav_guard_cancel")
  expect_match(html, "nav_guard_download")
  expect_match(html, "Annull") # "Annullér"
  expect_match(html, "Nulstil")
})

test_that("nav_guard_cancel removes modal and clears flags", {
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:3)
    app_state$navigation$guard_pending_target <- "upload"
    app_state$navigation$guard_modal_open <- TRUE
  })

  remove_modal_called <- FALSE
  testthat::local_mocked_bindings(
    removeModal = function(session = NULL) {
      remove_modal_called <<- TRUE
    },
    .package = "shiny"
  )

  setup_navigation_guard_listener(app_state, emit, session, session$input)

  # Flush forbruger ignoreInit = TRUE for alle observers
  shiny:::flushReact()

  # Simulér klik på Annullér
  session$setInputs(nav_guard_cancel = 1)
  shiny:::flushReact()

  expect_true(remove_modal_called)
  expect_null(shiny::isolate(app_state$navigation$guard_pending_target))
  expect_false(shiny::isolate(app_state$navigation$guard_modal_open))
  expect_equal(nrow(shiny::isolate(app_state$data$current_data)), 3) # uændret
})
