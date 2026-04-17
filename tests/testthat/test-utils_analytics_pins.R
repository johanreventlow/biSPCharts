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
