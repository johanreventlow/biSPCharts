test_that("should_track_analytics() returnerer FALSE naar consent mangler", {
  expect_false(should_track_analytics(consent = NULL))
  expect_false(should_track_analytics(consent = FALSE))
})

test_that("should_track_analytics() returnerer TRUE naar consent er givet", {
  expect_true(should_track_analytics(consent = TRUE))
})

test_that("should_track_analytics() respekterer feature flag", {
  withr::with_options(
    list(spc.analytics.enabled = FALSE),
    expect_false(should_track_analytics(consent = TRUE))
  )
})

test_that("format_analytics_metadata() returnerer korrekt struktur", {
  metadata <- list(
    visitor_id = "test-uuid-1234",
    user_agent = "Mozilla/5.0",
    screen_width = 1920,
    screen_height = 1080,
    window_width = 1200,
    window_height = 800,
    is_touch = FALSE,
    language = "da",
    timezone = "Europe/Copenhagen",
    referrer = "https://example.com",
    timestamp = "2026-04-15T10:00:00Z"
  )

  result <- format_analytics_metadata(metadata)
  expect_true(is.list(result))
  expect_equal(result$visitor_id, "test-uuid-1234")
  expect_equal(result$browser, "Mozilla/5.0")
  expect_equal(result$screen_width, 1920)
  expect_false(result$is_touch)
})

test_that("format_analytics_metadata() haandterer NULL input", {
  result <- format_analytics_metadata(NULL)
  expect_null(result)
})
