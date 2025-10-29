# test-utils_ragnar_integration.R
# Unit tests for Ragnar RAG integration layer
# Tests: load_ragnar_store(), query_spc_knowledge(), get_rag_config(), is_rag_enabled()

# ==============================================================================
# TEST SETUP: Load Required Functions
# ==============================================================================

# Source utils_ragnar_integration.R if functions aren't available
if (!exists("reset_ragnar_store_cache")) {
  source(here::here("R/utils_ragnar_integration.R"))
  source(here::here("R/utils_logging.R"))  # For log_* functions
}

# ==============================================================================
# TEST SETUP: Mock Ragnar Functions
# ==============================================================================

# Mock ragnar package functions for testing without actual ragnar installation
mock_ragnar_store <- function(store_path, embeddings_provider = NULL) {
  structure(
    list(
      store_path = store_path,
      embeddings_provider = embeddings_provider,
      mock = TRUE
    ),
    class = "ragnar_store"
  )
}

mock_ragnar_retrieve <- function(store, query, n = 3, method = "hybrid") {
  # Return mock results matching Ragnar's actual API (uses 'text' not 'content')
  data.frame(
    text = c(
      "SPC chart fundamentals: Common vs special cause variation",
      "Anhøj rules for detecting signals in run charts",
      "Target comparison and interpretation guidance"
    )[1:min(n, 3)],
    score = c(0.95, 0.87, 0.82)[1:min(n, 3)],
    stringsAsFactors = FALSE
  )
}

# ==============================================================================
# TEST: load_ragnar_store() - Session-Scoped Caching
# ==============================================================================

test_that("load_ragnar_store returns cached store on subsequent calls", {
  # Reset cache first
  reset_ragnar_store_cache()

  # Mock ragnar package availability using stub
  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) {
    if (package == "ragnar") TRUE else FALSE
  })
  mockery::stub(load_ragnar_store, "system.file", "/fake/path/to/ragnar_store")
  mockery::stub(load_ragnar_store, "dir.exists", function(path) {
    path == "/fake/path/to/ragnar_store"
  })
  mockery::stub(load_ragnar_store, "ragnar::ragnar_store", mock_ragnar_store)

  # First call should load
  store1 <- load_ragnar_store()
  expect_false(is.null(store1))
  expect_s3_class(store1, "ragnar_store")

  # Second call should return cached
  store2 <- load_ragnar_store()
  expect_identical(store1, store2)

  # Cleanup
  reset_ragnar_store_cache()
})

test_that("load_ragnar_store returns NULL if ragnar package not installed", {
  reset_ragnar_store_cache()

  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) FALSE)

  store <- load_ragnar_store()
  expect_null(store)

  reset_ragnar_store_cache()
})

test_that("load_ragnar_store returns NULL if store directory missing", {
  reset_ragnar_store_cache()

  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) TRUE)
  mockery::stub(load_ragnar_store, "system.file", "")

  store <- load_ragnar_store()
  expect_null(store)

  reset_ragnar_store_cache()
})

test_that("load_ragnar_store does not retry after failed load", {
  reset_ragnar_store_cache()

  call_count <- 0

  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) TRUE)
  mockery::stub(load_ragnar_store, "system.file", function(...) {
    call_count <<- call_count + 1
    ""
  })

  # First call fails
  store1 <- load_ragnar_store()
  expect_null(store1)
  expect_equal(call_count, 1)

  # Second call should not retry
  store2 <- load_ragnar_store()
  expect_null(store2)
  expect_equal(call_count, 1)  # No additional call

  reset_ragnar_store_cache()
})

test_that("reset_ragnar_store_cache clears cache and load attempt flag", {
  reset_ragnar_store_cache()

  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) TRUE)
  mockery::stub(load_ragnar_store, "system.file", "/fake/path")
  mockery::stub(load_ragnar_store, "dir.exists", function(path) TRUE)
  mockery::stub(load_ragnar_store, "ragnar::ragnar_store", mock_ragnar_store)

  # Load store
  store1 <- load_ragnar_store()
  expect_false(is.null(store1))

  # Reset cache
  reset_ragnar_store_cache()

  # Stub again for second call
  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) TRUE)
  mockery::stub(load_ragnar_store, "system.file", "/fake/path")
  mockery::stub(load_ragnar_store, "dir.exists", function(path) TRUE)
  mockery::stub(load_ragnar_store, "ragnar::ragnar_store", mock_ragnar_store)

  # Should reload
  store2 <- load_ragnar_store()
  expect_false(is.null(store2))
  expect_false(identical(store1, store2))

  reset_ragnar_store_cache()
})

# ==============================================================================
# TEST: query_spc_knowledge() - Knowledge Retrieval
# ==============================================================================

test_that("query_spc_knowledge constructs query from SPC metadata", {
  reset_ragnar_store_cache()

  query_captured <- NULL

  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) TRUE)
  mockery::stub(load_ragnar_store, "system.file", "/fake/path")
  mockery::stub(load_ragnar_store, "dir.exists", function(path) TRUE)
  mockery::stub(load_ragnar_store, "ragnar::ragnar_store", mock_ragnar_store)

  mockery::stub(query_spc_knowledge, "ragnar::ragnar_retrieve", function(store, query, n, method) {
    query_captured <<- query
    mock_ragnar_retrieve(store, query, n, method)
  })

  context <- query_spc_knowledge(
    chart_type = "run",
    signals = c("Serielængde", "Krydsninger"),
    target_comparison = "over målet",
    n_results = 3,
    method = "hybrid"
  )

  # Verify query construction
  expect_false(is.null(query_captured))
  expect_true(grepl("Chart type: run", query_captured, fixed = TRUE))
  expect_true(grepl("Signals detected: Serielængde, Krydsninger", query_captured))
  expect_true(grepl("Target comparison: over målet", query_captured))
  expect_true(grepl("How to interpret", query_captured))

  # Verify context returned
  expect_type(context, "character")
  expect_true(nchar(context) > 0)

  reset_ragnar_store_cache()
})

test_that("query_spc_knowledge handles NULL signals gracefully", {
  reset_ragnar_store_cache()

  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) TRUE)
  mockery::stub(load_ragnar_store, "system.file", "/fake/path")
  mockery::stub(load_ragnar_store, "dir.exists", function(path) TRUE)
  mockery::stub(load_ragnar_store, "ragnar::ragnar_store", mock_ragnar_store)

  mockery::stub(query_spc_knowledge, "ragnar::ragnar_retrieve", mock_ragnar_retrieve)

  context <- query_spc_knowledge(
    chart_type = "run",
    signals = NULL,
    target_comparison = NULL,
    n_results = 3
  )

  expect_type(context, "character")
  expect_true(nchar(context) > 0)

  reset_ragnar_store_cache()
})

test_that("query_spc_knowledge returns NULL if store not available", {
  reset_ragnar_store_cache()

  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) FALSE)

  context <- query_spc_knowledge(
    chart_type = "run",
    signals = c("Serielængde"),
    n_results = 3
  )

  expect_null(context)

  reset_ragnar_store_cache()
})

test_that("query_spc_knowledge uses provided store if available", {
  reset_ragnar_store_cache()

  mock_store <- mock_ragnar_store("/fake/path")

  mockery::stub(query_spc_knowledge, "ragnar::ragnar_retrieve", mock_ragnar_retrieve)

  context <- query_spc_knowledge(
    chart_type = "run",
    signals = c("Serielængde"),
    store = mock_store,
    n_results = 3
  )

  expect_type(context, "character")
  expect_true(nchar(context) > 0)

  reset_ragnar_store_cache()
})

test_that("query_spc_knowledge concatenates multiple results", {
  reset_ragnar_store_cache()

  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) TRUE)
  mockery::stub(load_ragnar_store, "system.file", "/fake/path")
  mockery::stub(load_ragnar_store, "dir.exists", function(path) TRUE)
  mockery::stub(load_ragnar_store, "ragnar::ragnar_store", mock_ragnar_store)

  mockery::stub(query_spc_knowledge, "ragnar::ragnar_retrieve", function(store, query, n, method) {
    data.frame(
      text = c("Result 1", "Result 2", "Result 3"),
      score = c(0.9, 0.8, 0.7),
      stringsAsFactors = FALSE
    )
  })

  context <- query_spc_knowledge(
    chart_type = "run",
    signals = NULL,
    n_results = 3
  )

  expect_true(grepl("Result 1", context, fixed = TRUE))
  expect_true(grepl("Result 2", context, fixed = TRUE))
  expect_true(grepl("Result 3", context, fixed = TRUE))
  expect_true(grepl("\n\n", context, fixed = TRUE))  # Separator

  reset_ragnar_store_cache()
})

# ==============================================================================
# TEST: get_rag_config() - Configuration Loading
# ==============================================================================

test_that("get_rag_config returns default config when golem config missing", {
  mockery::stub(get_rag_config, "golem::get_golem_options", function(key) NULL)

  rag_config <- get_rag_config()

  expect_type(rag_config, "list")
  expect_true(rag_config$enabled)
  expect_equal(rag_config$n_results, 3)
  expect_equal(rag_config$method, "hybrid")
})

test_that("get_rag_config loads config from golem options", {
  mockery::stub(get_rag_config, "golem::get_golem_options", function(key) {
    if (key == "ai") {
      list(
        rag = list(
          enabled = FALSE,
          n_results = 5,
          method = "vector"
        )
      )
    } else {
      NULL
    }
  })

  rag_config <- get_rag_config()

  expect_false(rag_config$enabled)
  expect_equal(rag_config$n_results, 5)
  expect_equal(rag_config$method, "vector")
})

test_that("get_rag_config uses fallback for missing sub-keys", {
  mockery::stub(get_rag_config, "golem::get_golem_options", function(key) {
    if (key == "ai") {
      list(
        rag = list(
          enabled = FALSE
          # n_results and method missing
        )
      )
    } else {
      NULL
    }
  })

  rag_config <- get_rag_config()

  expect_false(rag_config$enabled)
  expect_equal(rag_config$n_results, 3)  # Fallback
  expect_equal(rag_config$method, "hybrid")  # Fallback
})

# ==============================================================================
# TEST: is_rag_enabled() - Combined Availability Check
# ==============================================================================

test_that("is_rag_enabled returns TRUE when config enabled and store available", {
  reset_ragnar_store_cache()

  mockery::stub(get_rag_config, "golem::get_golem_options", function(key) {
    if (key == "ai") list(rag = list(enabled = TRUE)) else NULL
  })

  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) TRUE)
  mockery::stub(load_ragnar_store, "system.file", "/fake/path")
  mockery::stub(load_ragnar_store, "dir.exists", function(path) TRUE)
  mockery::stub(load_ragnar_store, "ragnar::ragnar_store", mock_ragnar_store)

  expect_true(is_rag_enabled())

  reset_ragnar_store_cache()
})

test_that("is_rag_enabled returns FALSE when config disabled", {
  reset_ragnar_store_cache()

  mockery::stub(get_rag_config, "golem::get_golem_options", function(key) {
    if (key == "ai") list(rag = list(enabled = FALSE)) else NULL
  })

  expect_false(is_rag_enabled())

  reset_ragnar_store_cache()
})

test_that("is_rag_enabled returns FALSE when store not available", {
  reset_ragnar_store_cache()

  mockery::stub(get_rag_config, "golem::get_golem_options", function(key) {
    if (key == "ai") list(rag = list(enabled = TRUE)) else NULL
  })

  mockery::stub(load_ragnar_store, "requireNamespace", function(package, quietly = TRUE) FALSE)

  expect_false(is_rag_enabled())

  reset_ragnar_store_cache()
})

# ==============================================================================
# TEST CLEANUP
# ==============================================================================

# Reset cache after all tests
reset_ragnar_store_cache()
