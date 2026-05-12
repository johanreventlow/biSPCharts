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

  setup_navigation_guard_listener(app_state, emit, session)

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
