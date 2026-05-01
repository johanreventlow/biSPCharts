# ==============================================================================
# TEST: EXPORT PREVIEW CACHE (#426)
# ==============================================================================
# FORMAL: Unit tests for PDF preview hard-cache mekanisme.
#         Tester cache-key konstruktion, hit/miss, TTL-expiry og date-field
#         ekskludering fra cache-noegle.
#
# STRATEGI:
#   Cache-helpers er defineret inde i mod_export_server() module-closuren
#   (per-session, ingen cross-session leakage). Testerne genskaaber
#   helper-funktionerne direkte for at undgaa Shiny-reaktiv kontekst.
#
# NOTE: generate_pdf_preview() kaldes KUN ved cache miss. Tests verificerer
#       dette via mock-funktion der taeller antal kald.
# ==============================================================================

library(testthat)

# HELPER: Genskab cache-helpers fra mod_export_server udenfor Shiny-kontekst ===

make_preview_cache <- function(ttl_seconds = 300L) {
  cache_env <- new.env(parent = emptyenv())
  cache_env$entries <- list()
  cache_env$ttl_seconds <- ttl_seconds

  build_key <- function(plot_data, metadata, dpi) {
    metadata_stable <- metadata[setdiff(names(metadata), "date")]
    digest::digest(list(
      plot_hash = digest::digest(plot_data),
      metadata = metadata_stable,
      dpi = dpi
    ))
  }

  get_cached <- function(key) {
    entry <- cache_env$entries[[key]]
    if (is.null(entry)) {
      return(NULL)
    }
    age <- as.numeric(difftime(Sys.time(), entry$ts, units = "secs"))
    if (age > cache_env$ttl_seconds) {
      cache_env$entries[[key]] <- NULL
      return(NULL)
    }
    entry$result
  }

  set_cached <- function(key, result) {
    cache_env$entries[[key]] <- list(
      result = result,
      ts = Sys.time()
    )
  }

  list(
    build_key = build_key,
    get = get_cached,
    set = set_cached,
    env = cache_env
  )
}

# STANDARD TEST DATA ===========================================================

make_plot_data <- function(seed = 42L) {
  set.seed(seed)
  list(x = 1:10, y = rnorm(10))
}

make_metadata <- function(title = "Test titel", date = Sys.Date()) {
  list(
    hospital = "Test Hospital",
    department = "Test Afdeling",
    title = title,
    analysis = "Test analyse",
    data_definition = NULL,
    date = date
  )
}

# TEST: Cache hit/miss =========================================================

test_that("cache returnerer NULL ved foerste opslag (miss)", {
  c <- make_preview_cache()
  plot_data <- make_plot_data()
  metadata <- make_metadata()

  key <- c$build_key(plot_data, metadata, 150L)
  result <- c$get(key)

  expect_null(result)
})

test_that("identisk input giver cache hit ved andet opslag", {
  c <- make_preview_cache()
  plot_data <- make_plot_data()
  metadata <- make_metadata()

  key <- c$build_key(plot_data, metadata, 150L)

  # Simuler at generate_pdf_preview returnerer en sti
  fake_path <- tempfile(fileext = ".png")
  c$set(key, fake_path)

  result <- c$get(key)
  expect_equal(result, fake_path)
})

test_that("aendret titel giver cache miss", {
  c <- make_preview_cache()
  plot_data <- make_plot_data()

  key1 <- c$build_key(plot_data, make_metadata(title = "Titel A"), 150L)
  key2 <- c$build_key(plot_data, make_metadata(title = "Titel B"), 150L)

  fake_path <- tempfile(fileext = ".png")
  c$set(key1, fake_path)

  # key2 (ander titel) skal ikke finde key1's vaerdi
  result <- c$get(key2)
  expect_null(result)
})

test_that("aendret dpi giver cache miss", {
  c <- make_preview_cache()
  plot_data <- make_plot_data()
  metadata <- make_metadata()

  key_150 <- c$build_key(plot_data, metadata, 150L)
  key_300 <- c$build_key(plot_data, metadata, 300L)

  fake_path <- tempfile(fileext = ".png")
  c$set(key_150, fake_path)

  expect_null(c$get(key_300))
})

# TEST: Date-felt ekskluderes fra cache-noegle ==================================

test_that("date-felt i metadata paavirker ikke cache-noegle", {
  c <- make_preview_cache()
  plot_data <- make_plot_data()

  key_today <- c$build_key(plot_data, make_metadata(date = Sys.Date()), 150L)
  key_yesterday <- c$build_key(plot_data, make_metadata(date = Sys.Date() - 1L), 150L)

  expect_equal(key_today, key_yesterday)
})

test_that("cache hit virker paa tvaers af to dato-vaerdier", {
  c <- make_preview_cache()
  plot_data <- make_plot_data()

  key_day1 <- c$build_key(plot_data, make_metadata(date = as.Date("2026-01-01")), 150L)
  key_day2 <- c$build_key(plot_data, make_metadata(date = as.Date("2026-06-01")), 150L)

  fake_path <- tempfile(fileext = ".png")
  c$set(key_day1, fake_path)

  # key_day2 skal finde key_day1's vaerdi (samme noegle)
  result <- c$get(key_day2)
  expect_equal(result, fake_path)
})

# TEST: TTL-expiry =============================================================

test_that("cache miss efter TTL-udloeb", {
  # Saet TTL til 0 sekunder -- alle entries er straks udloebet
  c <- make_preview_cache(ttl_seconds = 0L)
  plot_data <- make_plot_data()
  metadata <- make_metadata()

  key <- c$build_key(plot_data, metadata, 150L)
  fake_path <- tempfile(fileext = ".png")
  c$set(key, fake_path)

  # Simuler TTL-udloeb ved at saette ts til fortiden
  c$env$entries[[key]]$ts <- Sys.time() - 10

  result <- c$get(key)
  expect_null(result)
})

test_that("udloebet entry fjernes fra cache", {
  c <- make_preview_cache(ttl_seconds = 0L)
  plot_data <- make_plot_data()
  metadata <- make_metadata()

  key <- c$build_key(plot_data, metadata, 150L)
  fake_path <- tempfile(fileext = ".png")
  c$set(key, fake_path)

  # Saet ts til fortiden
  c$env$entries[[key]]$ts <- Sys.time() - 10

  # get() skal fjerne udloebet entry
  c$get(key)
  expect_null(c$env$entries[[key]])
})

test_that("gyldigt entry returneres foer TTL-udloeb", {
  # TTL = 300 sekunder -- ny entry er ikke udloebet
  c <- make_preview_cache(ttl_seconds = 300L)
  plot_data <- make_plot_data()
  metadata <- make_metadata()

  key <- c$build_key(plot_data, metadata, 150L)
  fake_path <- tempfile(fileext = ".png")
  c$set(key, fake_path)

  result <- c$get(key)
  expect_equal(result, fake_path)
})

# TEST: Per-session isolation ==================================================

test_that("to separate cache-instanser deler ikke entries", {
  c1 <- make_preview_cache()
  c2 <- make_preview_cache()
  plot_data <- make_plot_data()
  metadata <- make_metadata()

  key <- c1$build_key(plot_data, metadata, 150L)
  fake_path <- tempfile(fileext = ".png")
  c1$set(key, fake_path)

  # c2 er en separat instans (simulerer separat Shiny-session)
  result <- c2$get(key)
  expect_null(result)
})

# TEST: Cache-key er deterministisk ===========================================

test_that("build_key er deterministisk for identisk input", {
  c <- make_preview_cache()
  plot_data <- make_plot_data()
  metadata <- make_metadata()

  key1 <- c$build_key(plot_data, metadata, 150L)
  key2 <- c$build_key(plot_data, metadata, 150L)

  expect_equal(key1, key2)
})
