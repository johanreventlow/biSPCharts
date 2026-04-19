# ==============================================================================
# test-helper-mocks-contracts.R
# ==============================================================================
# §2.4.3 — Kontrakttest: verificér at mocks matcher real API formals().
#
# Disse tests fanger API-drift. Når en ekstern pakke ændrer en funktions
# signatur, skal mocken opdateres — ellers kan tests give falske positiver
# (koden virker med mock, men fejler i produktion).
#
# Pattern: skip_if_not_installed() + formals() sammenligning.
# ==============================================================================

# ------------------------------------------------------------------------------
# BFHllm mock contracts
# ------------------------------------------------------------------------------

test_that("mock_bfhllm_spc_suggestion matches BFHllm::bfhllm_spc_suggestion signature", {
  skip_if_not_installed("BFHllm")

  real_args <- names(formals(BFHllm::bfhllm_spc_suggestion))
  mock_args <- names(formals(mock_bfhllm_spc_suggestion))

  expect_setequal(mock_args, real_args)
})

# ------------------------------------------------------------------------------
# BFHcharts mock contracts
# ------------------------------------------------------------------------------

test_that("mock_bfh_qic matches BFHcharts::bfh_qic signature", {
  skip_if_not_installed("BFHcharts")
  skip_if(!exists("bfh_qic", where = asNamespace("BFHcharts")),
    message = "BFHcharts::bfh_qic not exported in this version"
  )

  real_args <- names(formals(BFHcharts::bfh_qic))
  mock_args <- names(formals(mock_bfh_qic))

  expect_setequal(mock_args, real_args)
})

# ------------------------------------------------------------------------------
# pins mock contracts
# ------------------------------------------------------------------------------

test_that("mock_board_connect matches pins::board_connect signature", {
  skip_if_not_installed("pins")

  real_args <- names(formals(pins::board_connect))
  mock_args <- names(formals(mock_board_connect))

  expect_setequal(mock_args, real_args)
})

# ------------------------------------------------------------------------------
# gert mock contracts
# ------------------------------------------------------------------------------

test_that("mock_git_clone matches gert::git_clone signature", {
  skip_if_not_installed("gert")

  real_args <- names(formals(gert::git_clone))
  mock_args <- names(formals(mock_git_clone))

  expect_setequal(mock_args, real_args)
})

test_that("mock_git_commit matches gert::git_commit signature", {
  skip_if_not_installed("gert")

  real_args <- names(formals(gert::git_commit))
  mock_args <- names(formals(mock_git_commit))

  expect_setequal(mock_args, real_args)
})

# ------------------------------------------------------------------------------
# httr2 mock contracts
# ------------------------------------------------------------------------------

test_that("mock_req_perform matches httr2::req_perform signature", {
  skip_if_not_installed("httr2")

  real_args <- names(formals(httr2::req_perform))
  mock_args <- names(formals(mock_req_perform))

  expect_setequal(mock_args, real_args)
})

# ------------------------------------------------------------------------------
# localStorage mock contracts (intern struktur-kontrakt)
# ------------------------------------------------------------------------------

test_that("mock_local_storage_peek_result produces expected structure", {
  # Default (no payload)
  result_empty <- mock_local_storage_peek_result(has_payload = FALSE)
  expect_type(result_empty, "list")
  expect_named(result_empty, c("has_payload", "schema_version"),
    ignore.order = TRUE
  )
  expect_false(result_empty$has_payload)
  expect_equal(result_empty$schema_version, "2.0")

  # With payload
  result_full <- mock_local_storage_peek_result(
    has_payload = TRUE,
    nrows = 42, ncols = 5
  )
  expect_true(result_full$has_payload)
  expect_true(all(c("timestamp", "nrows", "ncols") %in% names(result_full)))
  expect_equal(result_full$nrows, 42)
  expect_equal(result_full$ncols, 5)
})

test_that("mock_local_storage_save_result produces expected structure", {
  # Success case
  result_ok <- mock_local_storage_save_result(success = TRUE)
  expect_type(result_ok, "list")
  expect_true(all(c("success", "error_type", "message", "timestamp") %in%
    names(result_ok)))
  expect_true(result_ok$success)
  expect_null(result_ok$error_type)

  # Failure case (quota exceeded)
  result_fail <- mock_local_storage_save_result(success = FALSE)
  expect_false(result_fail$success)
  expect_equal(result_fail$error_type, "QuotaExceededError")
})

# ------------------------------------------------------------------------------
# Basic sanity: mocks executable uden crash
# ------------------------------------------------------------------------------

test_that("mocks execute without crashing", {
  # BFHllm mock
  result <- mock_bfhllm_spc_suggestion(spc_result = list(), context = list())
  expect_type(result, "character")
  expect_gt(nchar(result), 0)

  # pins mock
  board <- mock_board_connect()
  expect_s3_class(board, "pins_board")
  expect_true(board$is_mock)

  # gert mocks
  path <- mock_git_clone(url = "https://mock.local/repo.git")
  expect_true(dir.exists(path))
  unlink(path, recursive = TRUE)

  commit_hash <- mock_git_commit(message = "test")
  expect_type(commit_hash, "character")
  expect_equal(nchar(commit_hash), 40) # git hash length

  # httr2 mock
  response <- mock_req_perform(req = list())
  expect_s3_class(response, "httr2_response")
  expect_equal(response$status_code, 200L)
})
