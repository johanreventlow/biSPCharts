test_that("inject_pat_into_url() indsætter PAT i HTTPS URL", {
  result <- inject_pat_into_url(
    "https://github.com/owner/repo.git",
    "ghp_testtoken"
  )
  expect_equal(
    result,
    "https://x-access-token:ghp_testtoken@github.com/owner/repo.git"
  )
})

test_that("inject_pat_into_url() virker uden .git-suffix", {
  result <- inject_pat_into_url(
    "https://github.com/owner/repo",
    "ghp_x"
  )
  expect_equal(
    result,
    "https://x-access-token:ghp_x@github.com/owner/repo"
  )
})

test_that("inject_pat_into_url() fejler paa ikke-HTTPS URL", {
  expect_error(
    inject_pat_into_url("git@github.com:owner/repo.git", "ghp_x"),
    "HTTPS"
  )
})

test_that("build_session_filename() producerer sorterbart navn", {
  filename <- build_session_filename(
    session_id = "abcdef1234567890",
    timestamp = as.POSIXct("2026-04-17 08:42:11", tz = "UTC")
  )
  expect_equal(filename, "20260417T084211Z_abcdef12.rds")
})

test_that("build_session_filename() haandterer NULL session_id", {
  filename <- build_session_filename(
    session_id = NULL,
    timestamp = as.POSIXct("2026-04-17 08:42:11", tz = "UTC")
  )
  expect_match(filename, "^20260417T084211Z_s\\d+\\.rds$")
})

test_that("build_session_filename() haandterer kort session_id", {
  filename <- build_session_filename(
    session_id = "abc",
    timestamp = as.POSIXct("2026-04-17 08:42:11", tz = "UTC")
  )
  expect_equal(filename, "20260417T084211Z_abc.rds")
})

test_that("sync_logs_to_github() returnerer env_not_set uden PAT", {
  withr::with_envvar(
    c(GITHUB_PAT = "", PIN_REPO_URL = ""),
    {
      result <- sync_logs_to_github(
        all_data = list(
          sessions = data.frame(), inputs = data.frame(),
          outputs = data.frame(), errors = data.frame()
        )
      )
      expect_false(result$success)
      expect_equal(result$reason, "env_not_set")
    }
  )
})

test_that("sync_logs_to_github() returnerer env_not_set uden PIN_REPO_URL", {
  withr::with_envvar(
    c(GITHUB_PAT = "ghp_x", PIN_REPO_URL = ""),
    {
      result <- sync_logs_to_github(
        all_data = list(
          sessions = data.frame(), inputs = data.frame(),
          outputs = data.frame(), errors = data.frame()
        )
      )
      expect_false(result$success)
      expect_equal(result$reason, "env_not_set")
    }
  )
})

test_that("sync_logs_to_github() skipper ved tom data", {
  withr::with_envvar(
    c(
      GITHUB_PAT = "ghp_x",
      PIN_REPO_URL = "https://github.com/owner/repo.git"
    ),
    {
      result <- sync_logs_to_github(
        all_data = list(
          sessions = data.frame(), inputs = data.frame(),
          outputs = data.frame(), errors = data.frame()
        )
      )
      expect_false(result$success)
      expect_equal(result$reason, "empty_data")
    }
  )
})
