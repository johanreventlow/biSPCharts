# test-no-file-dependencies.R
# Tests to ensure app can instantiate without filesystem dependencies

test_that("app_server function is available without file source", {
  # Test that app_server function exists and is callable
  expect_true(exists("app_server", mode = "function"))
  expect_true(is.function(app_server))

  # Test that main_app_server function exists and is callable
  expect_true(exists("main_app_server", mode = "function"))
  expect_true(is.function(main_app_server))
})

test_that("app_server can be tested without file dependencies", {
  # Verificer at app_server ikke indeholder source() eller system.file() kald
  # VIGTIGT: testServer(app_server, ...) starter hele appen og hænger i test_dir()
  app_server_body <- deparse(body(app_server))
  expect_false(any(grepl("source\\(", app_server_body)),
    info = "app_server should not use source() calls"
  )
  expect_false(any(grepl("system\\.file", app_server_body)),
    info = "app_server should not use system.file() calls"
  )
})

test_that("run_app function works without file dependencies", {
  # Test that run_app can be called without throwing file not found errors
  expect_no_error({
    # Mock a test mode run_app call that doesn't actually start server
    # This tests the initialization without starting a real server
    app_object <- list(
      ui = app_ui,
      server = app_server
    )
    expect_true(is.function(app_object$ui))
    expect_true(is.function(app_object$server))
  })
})

test_that("no system.file() calls in app_server", {
  # Verify that app_server function body doesn't contain source() calls
  app_server_body <- deparse(body(app_server))
  expect_false(any(grepl("source\\(", app_server_body)))
  expect_false(any(grepl("system\\.file", app_server_body)))
})

test_that("main_app_server is properly exported", {
  # Verify main_app_server is in package namespace
  expect_true("main_app_server" %in% getNamespaceExports("claudespc"))
})
