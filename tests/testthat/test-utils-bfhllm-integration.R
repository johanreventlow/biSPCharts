# test-utils-bfhllm-integration.R
# Unit tests for BFHllm integration functions med mockery-stubs.
# Tester graceful degradation når BFHllm ikke er installeret/tilgængeligt.
#
# Scope: initialize_bfhllm, is_bfhllm_available, generate_bfhllm_suggestion.
# Bruger mockery::stub() til at mocke BFHllm-namespace og API-kald.

test_that("initialize_bfhllm returnerer NULL naar BFHllm ikke er installeret", {
  # Simulér manglende BFHllm via mockery
  mockery::stub(initialize_bfhllm, "requireNamespace", FALSE)

  result <- initialize_bfhllm()
  expect_null(result)
})

test_that("is_bfhllm_available returnerer FALSE naar BFHllm ikke er installeret", {
  mockery::stub(is_bfhllm_available, "requireNamespace", FALSE)

  result <- is_bfhllm_available()
  expect_false(result)
})

test_that("is_bfhllm_available returnerer FALSE naar API-key mangler (bfhllm_chat_available=FALSE)", {
  # BFHllm installeret, men API-nøgle ikke sat → bfhllm_chat_available() returnerer FALSE
  mockery::stub(is_bfhllm_available, "requireNamespace", TRUE)
  mockery::stub(is_bfhllm_available, "BFHllm::bfhllm_chat_available", FALSE)

  result <- is_bfhllm_available()
  expect_false(result)
})

test_that("is_bfhllm_available returnerer TRUE naar BFHllm er konfigureret korrekt", {
  mockery::stub(is_bfhllm_available, "requireNamespace", TRUE)
  mockery::stub(is_bfhllm_available, "BFHllm::bfhllm_chat_available", TRUE)

  result <- is_bfhllm_available()
  expect_true(result)
})

test_that("is_bfhllm_available returnerer FALSE + log_warn ved BFHllm-probe-error (#453)", {
  # H7 (#453): hvis BFHllm::bfhllm_chat_available() kaster en fejl
  # (bad config, network probe failure), skal kalderen få FALSE og en
  # warn-besked uden at fejlen propagerer op.
  mockery::stub(is_bfhllm_available, "requireNamespace", TRUE)
  mockery::stub(
    is_bfhllm_available,
    "BFHllm::bfhllm_chat_available",
    function() stop("network probe failed")
  )

  result <- is_bfhllm_available()
  expect_false(result)
})

test_that("generate_bfhllm_suggestion eksisterer og har korrekt signatur", {
  # Verificer funktion eksisterer + har forventede parametre.
  # Graceful degradation ved unavailable BFHllm kræver Shiny-session context
  # (bfhllm_spc_suggestion bruger session til cache-lookup) — testes manuelt.
  require_internal("generate_bfhllm_suggestion", mode = "function")

  args <- names(formals(generate_bfhllm_suggestion))
  expect_true("spc_result" %in% args)
  expect_true("context" %in% args)
  expect_true("session" %in% args)
})

test_that("initialize_bfhllm kalder bfhllm_configure med korrekte parametre", {
  mockery::stub(initialize_bfhllm, "requireNamespace", TRUE)

  # Mock bfhllm_configure og verificer at det kaldes med model-argument
  mock_configure <- mockery::mock(invisible(NULL))
  mockery::stub(initialize_bfhllm, "BFHllm::bfhllm_configure", mock_configure)

  test_config <- list(
    model = "gemini-2.0-flash",
    timeout_seconds = 30,
    max_response_chars = 2000
  )

  initialize_bfhllm(ai_config = test_config)

  mockery::expect_called(mock_configure, 1)
  call_args <- mockery::mock_args(mock_configure)[[1]]
  expect_equal(call_args$model, "gemini-2.0-flash")
  expect_equal(call_args$timeout_seconds, 30)
})

test_that("get_ai_config returnerer sensible defaults", {
  require_internal("get_ai_config", mode = "function")

  config <- get_ai_config()

  expect_true(is.list(config))
  expect_true("model" %in% names(config))
  expect_true("timeout_seconds" %in% names(config))
  expect_true("max_response_chars" %in% names(config))
  expect_true("enabled" %in% names(config))

  # Default timeout er positiv
  expect_true(config$timeout_seconds > 0)
  # Default max_chars er positiv
  expect_true(config$max_response_chars > 0)
})

test_that("get_rag_config returnerer sensible defaults", {
  require_internal("get_rag_config", mode = "function")

  config <- get_rag_config()

  expect_true(is.list(config))
  expect_true("enabled" %in% names(config))
  expect_true("n_results" %in% names(config))
})

test_that("create_bfhllm_cache eksisterer og har korrekt signatur", {
  require_internal("create_bfhllm_cache", mode = "function")

  args <- names(formals(create_bfhllm_cache))
  expect_true("session" %in% args)
})
