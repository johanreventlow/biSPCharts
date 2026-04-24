test_that("read_shinylogs_sessions() returnerer data.frame", {
  tmp_dir <- withr::local_tempdir()

  test_log <- list(
    session = data.frame(
      sessionid = "abc123",
      app = "SPC_Analysis_Tool",
      server_connected = "2026-04-15T10:00:00Z",
      server_disconnected = "2026-04-15T10:15:00Z",
      stringsAsFactors = FALSE
    ),
    inputs = data.frame(),
    outputs = data.frame(),
    errors = data.frame()
  )
  jsonlite::write_json(
    test_log,
    file.path(tmp_dir, "shinylogs_SPC_Analysis_Tool_12345.json"),
    auto_unbox = FALSE
  )

  result <- read_shinylogs_sessions(tmp_dir)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) >= 1)
})

test_that("read_shinylogs_sessions() haandterer tom mappe", {
  tmp_dir <- withr::local_tempdir()
  result <- read_shinylogs_sessions(tmp_dir)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("read_shinylogs_all() laeser shinylogs_*.json direkte i log_dir", {
  tmp_dir <- withr::local_tempdir()

  # shinylogs::store_json skriver EN samlet fil per session med
  # format {session, inputs, outputs, errors}
  test_log <- list(
    session = data.frame(
      sessionid = "abc123",
      app = "SPC_Analysis_Tool",
      server_connected = "2026-04-15T10:00:00Z",
      server_disconnected = "2026-04-15T10:15:00Z",
      stringsAsFactors = FALSE
    ),
    inputs = data.frame(
      sessionid = "abc123",
      name = "chart_type",
      value = "run",
      stringsAsFactors = FALSE
    ),
    outputs = data.frame(
      sessionid = "abc123",
      name = "spc_plot",
      stringsAsFactors = FALSE
    ),
    errors = data.frame(
      sessionid = "abc123",
      name = "render_error",
      error = "Missing column",
      stringsAsFactors = FALSE
    )
  )
  jsonlite::write_json(
    test_log,
    file.path(tmp_dir, "shinylogs_SPC_Analysis_Tool_1234567890.json"),
    auto_unbox = FALSE
  )

  result <- read_shinylogs_all(tmp_dir)

  expect_true(is.list(result))
  expect_equal(sort(names(result)), c("errors", "inputs", "outputs", "sessions"))
  expect_s3_class(result$sessions, "data.frame")
  expect_s3_class(result$inputs, "data.frame")
  expect_s3_class(result$outputs, "data.frame")
  expect_s3_class(result$errors, "data.frame")
  expect_true(nrow(result$sessions) >= 1)
  expect_true(nrow(result$inputs) >= 1)
})

test_that("read_shinylogs_all() haandterer tom mappe", {
  tmp_dir <- withr::local_tempdir()
  result <- read_shinylogs_all(tmp_dir)

  expect_true(is.list(result))
  expect_equal(nrow(result$sessions), 0)
  expect_equal(nrow(result$inputs), 0)
  expect_equal(nrow(result$outputs), 0)
  expect_equal(nrow(result$errors), 0)
})

test_that("read_shinylogs_all() haandterer non-existent path", {
  result <- read_shinylogs_all("/non/existent/path")
  expect_equal(nrow(result$sessions), 0)
})

make_test_all_data <- function(session_id = "raw-token-abc123",
                               with_pat_in_error = FALSE) {
  sessions_df <- data.frame(
    sessionid = session_id,
    app = "biSPCharts",
    user = "test_user",
    user_agent = "Mozilla/5.0",
    server_connected = "2026-04-15T10:00:00Z",
    server_disconnected = "2026-04-15T10:15:00Z",
    stringsAsFactors = FALSE
  )
  inputs_df <- data.frame(
    sessionid = session_id,
    name = "chart_type",
    timestamp = "2026-04-15T10:01:00Z",
    value = "p-chart",
    type = "shiny.action",
    binding = "selectInput",
    stringsAsFactors = FALSE
  )
  outputs_df <- data.frame(
    sessionid = session_id,
    name = "spc_plot",
    timestamp = "2026-04-15T10:01:05Z",
    binding = "plotOutput",
    stringsAsFactors = FALSE
  )
  error_msg <- if (with_pat_in_error) {
    "clone: https://x-access-token:ghp_LEAKED_PAT@github.com/owner/repo"
  } else {
    "render failed: column not found"
  }
  errors_df <- data.frame(
    sessionid = session_id,
    name = "render_error",
    timestamp = "2026-04-15T10:02:00Z",
    error = error_msg,
    stringsAsFactors = FALSE
  )
  list(
    sessions = sessions_df, inputs = inputs_df,
    outputs = outputs_df, errors = errors_df
  )
}

test_that("filter_shinylogs_allowlist() fjerner ikke-tilladte kolonner", {
  all_data <- make_test_all_data()
  filtered <- filter_shinylogs_allowlist(all_data)

  # sessionid erstattet med session_hash
  expect_true("session_hash" %in% names(filtered$sessions))
  expect_false("sessionid" %in% names(filtered$sessions))

  # sensitive sessions-kolonner fjernet
  expect_false("user" %in% names(filtered$sessions))
  expect_false("user_agent" %in% names(filtered$sessions))

  # inputs: type og binding fjernet
  expect_false("type" %in% names(filtered$inputs))
  expect_false("binding" %in% names(filtered$inputs))
  expect_true("name" %in% names(filtered$inputs))
  expect_true("value" %in% names(filtered$inputs))

  # outputs: binding fjernet
  expect_false("binding" %in% names(filtered$outputs))
  expect_true("name" %in% names(filtered$outputs))

  # errors: error-kolonne erstattet med redacted_message
  expect_false("error" %in% names(filtered$errors))
  expect_true("redacted_message" %in% names(filtered$errors))
})

test_that("filter_shinylogs_allowlist() hashes session_id korrekt", {
  all_data <- make_test_all_data(session_id = "raw-token-abc123")
  filtered <- filter_shinylogs_allowlist(all_data)

  # session_hash er 8-tegns hex
  expect_match(filtered$sessions$session_hash, "^[0-9a-f]{8}$")

  # raa token optræder ikke i session_hash
  expect_false(grepl("raw-token", filtered$sessions$session_hash, fixed = TRUE))

  # alle dataframes har samme session_hash
  expect_equal(filtered$sessions$session_hash, filtered$inputs$session_hash)
  expect_equal(filtered$sessions$session_hash, filtered$outputs$session_hash)
  expect_equal(filtered$sessions$session_hash, filtered$errors$session_hash)
})

test_that("filter_shinylogs_allowlist() redacter PAT i errors", {
  all_data <- make_test_all_data(with_pat_in_error = TRUE)
  filtered <- filter_shinylogs_allowlist(all_data)

  expect_false(grepl("ghp_LEAKED_PAT", filtered$errors$redacted_message, fixed = TRUE))
  expect_true(grepl("[REDACTED]", filtered$errors$redacted_message, fixed = TRUE))
})

test_that("filter_shinylogs_allowlist() haandterer tomme dataframes", {
  empty_data <- list(
    sessions = data.frame(),
    inputs = data.frame(),
    outputs = data.frame(),
    errors = data.frame()
  )
  result <- filter_shinylogs_allowlist(empty_data)
  expect_s3_class(result$sessions, "data.frame")
  expect_equal(nrow(result$sessions), 0)
  expect_equal(nrow(result$inputs), 0)
})

test_that("redact_error_messages() omdoeber error til redacted_message", {
  errors_df <- data.frame(
    sessionid = "abc",
    error = "clone: https://x-access-token:ghp_SECRET@github.com",
    stringsAsFactors = FALSE
  )
  result <- redact_error_messages(errors_df)
  expect_true("redacted_message" %in% names(result))
  expect_false("error" %in% names(result))
  expect_false(grepl("ghp_SECRET", result$redacted_message, fixed = TRUE))
})

test_that("rotate_log_files() komprimerer gamle filer", {
  tmp_dir <- withr::local_tempdir()

  old_file <- file.path(tmp_dir, "old_log.json")
  writeLines('{"test": true}', old_file)
  Sys.setFileTime(old_file, Sys.time() - as.difftime(100, units = "days"))

  new_file <- file.path(tmp_dir, "new_log.json")
  writeLines('{"test": true}', new_file)

  rotate_log_files(tmp_dir, compress_after_days = 90, delete_after_days = 365)

  expect_true(file.exists(paste0(old_file, ".gz")))
  expect_false(file.exists(old_file))
  expect_true(file.exists(new_file))
})
