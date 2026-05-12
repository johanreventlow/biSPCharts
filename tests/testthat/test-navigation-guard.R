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
    expect_true(
      app_state$navigation$guard_pending_target %in% c("upload", "start")
    )
  })
})
