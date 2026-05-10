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

# is_persistence_allowed() — gate for localStorage app-state-persistens
# Binær consent-model: persistens kræver eksplicit samtykke (consent = TRUE).
# Anvendes af saveDataLocally / loadDataLocally / autoSaveAppState.

test_that("is_persistence_allowed() returnerer FALSE naar consent mangler", {
  fake_input <- list(analytics_consent = NULL)
  expect_false(is_persistence_allowed(fake_input))
})

test_that("is_persistence_allowed() returnerer FALSE naar consent eksplicit afvist", {
  fake_input <- list(analytics_consent = FALSE)
  expect_false(is_persistence_allowed(fake_input))
})

test_that("is_persistence_allowed() returnerer TRUE naar consent givet", {
  fake_input <- list(analytics_consent = TRUE)
  expect_true(is_persistence_allowed(fake_input))
})

test_that("is_persistence_allowed() respekterer analytics-feature-flag", {
  fake_input <- list(analytics_consent = TRUE)
  withr::with_options(
    list(spc.analytics.enabled = FALSE),
    # Persistens er IKKE bundet til shinylogs-flaget — det er en separat
    # GDPR-kategori. Selv hvis analytics er disabled på system-niveau,
    # skal user-consent stadig respekteres for persistens.
    expect_true(is_persistence_allowed(fake_input))
  )
})

test_that("is_persistence_allowed() haandterer manglende input-felt", {
  fake_input <- list()
  expect_false(is_persistence_allowed(fake_input))
})

test_that("is_persistence_allowed() er robust ved NA-værdi", {
  fake_input <- list(analytics_consent = NA)
  expect_false(is_persistence_allowed(fake_input))
})
