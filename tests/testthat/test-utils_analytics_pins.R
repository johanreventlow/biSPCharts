test_that("read_shinylogs_sessions() returnerer data.frame", {
  tmp_dir <- withr::local_tempdir()
  session_dir <- file.path(tmp_dir, "sessions")
  dir.create(session_dir, recursive = TRUE)

  test_session <- list(
    app = "SPC_Analysis_Tool",
    user = "",
    server_connected = "2026-04-15T10:00:00Z",
    server_disconnected = "2026-04-15T10:15:00Z",
    session_duration = 900
  )
  jsonlite::write_json(test_session,
    file.path(session_dir, "session_2026-04-15_test123.json"))

  result <- read_shinylogs_sessions(tmp_dir)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) >= 1)
  expect_true("session_duration" %in% names(result))
})

test_that("read_shinylogs_sessions() haandterer tom mappe", {
  tmp_dir <- withr::local_tempdir()
  result <- read_shinylogs_sessions(tmp_dir)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
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
