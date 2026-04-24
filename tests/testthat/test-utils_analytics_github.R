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

test_that("build_session_filename() producerer sorterbart navn med hash-prefix", {
  filename <- build_session_filename(
    session_id = "abcdef1234567890",
    timestamp = as.POSIXct("2026-04-17 08:42:11", tz = "UTC")
  )
  expect_match(filename, "^20260417T084211Z_[0-9a-f]{8}\\.rds$")
})

test_that("build_session_filename() never exposes raw session_id", {
  session_id <- "abcdef1234567890"
  filename <- build_session_filename(
    session_id = session_id,
    timestamp = as.POSIXct("2026-04-17 08:42:11", tz = "UTC")
  )
  expect_false(grepl(substr(session_id, 1L, 8L), filename, fixed = TRUE))
  expect_false(grepl(session_id, filename, fixed = TRUE))
})

test_that("build_session_filename() er deterministisk (samme input, samme hash)", {
  ts <- as.POSIXct("2026-04-17 08:42:11", tz = "UTC")
  expect_equal(
    build_session_filename("my-session", ts),
    build_session_filename("my-session", ts)
  )
})

test_that("build_session_filename() haandterer NULL session_id", {
  filename <- build_session_filename(
    session_id = NULL,
    timestamp = as.POSIXct("2026-04-17 08:42:11", tz = "UTC")
  )
  expect_match(filename, "^20260417T084211Z_[0-9a-f]{8}\\.rds$")
})

test_that("build_session_filename() haandterer tom session_id", {
  filename <- build_session_filename(
    session_id = "",
    timestamp = as.POSIXct("2026-04-17 08:42:11", tz = "UTC")
  )
  expect_match(filename, "^20260417T084211Z_[0-9a-f]{8}\\.rds$")
})

test_that("redact_pat_in_url() fjerner PAT fra GitHub auth-URL", {
  msg <- "Failed: https://x-access-token:ghp_SECRET123@github.com/owner/repo.git: 403"
  result <- redact_pat_in_url(msg)
  expect_false(grepl("ghp_SECRET123", result, fixed = TRUE))
  expect_true(grepl("x-access-token:[REDACTED]@", result, fixed = TRUE))
})

test_that("redact_pat_in_url() er no-op paa besked uden credentials", {
  msg <- "Network timeout after 30s"
  expect_equal(redact_pat_in_url(msg), msg)
})

test_that("redact_pat_in_url() haandterer token med specialtegn", {
  msg <- "clone: https://x-access-token:abc_DEF-123.xyz@github.com/r.git"
  result <- redact_pat_in_url(msg)
  expect_false(grepl("abc_DEF-123.xyz", result, fixed = TRUE))
  expect_true(grepl("[REDACTED]", result, fixed = TRUE))
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
