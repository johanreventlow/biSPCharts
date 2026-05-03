# test-anhoej-signal-semantics-468.R
#
# Regressions-tests der dokumenterer Anhoej-signal-semantik-bug i biSPCharts (#468)
# samt verificerer at fix retter adfaerden korrekt.
#
# BUG-RESUME (kort):
# qicharts2's `runs.signal`-kolonne er KOMBINERET Anhoej-signal (sat naar enten
# runs- ELLER crossings-violation er udloest), ikke kun runs. biSPCharts'
# `extract_anhoej_metadata()` (R/fct_anhoej_rules.R:97-99) og
# `derive_anhoej_results()` (R/fct_spc_anhoej_derivation.R:78-80) mapper
# `qic_data$runs.signal` direkte til feltet `runs_signal`, hvilket faar
# crossing-only signaler til at vises som "Runs-signal: Ja" i UI + Excel.
#
# REFERENCE:
# - Issue: johanreventlow/biSPCharts#468
# - qicharts2 source: helper.functions.R `crsignal()`-helper L91-168
# - BFHcharts: bruger qicharts2 internt -> samme tal, samme fejl-mapping
# - Codex-rescue verifikation 2026-05-03
#
# AFTER-FIX-FORVENTNINGER:
# runs_signal      = longest.run > longest.run.max  (strict >, ikke >=)
# crossings_signal = n.crossings < n.crossings.min  (allerede korrekt)
# anhoej_signal    = runs_signal || crossings_signal
#
# NA-guard: alle tre felter skal vaere NA-safe.

library(testthat)

skip_if_not_installed("qicharts2")

# Helper: kor qic + extract begge biSPCharts-derivationer
collect_anhoej <- function(v) {
  q <- qicharts2::qic(
    x = seq_along(v), y = v, chart = "run", return.data = TRUE
  )
  list(
    qic = q,
    extract = extract_anhoej_metadata(q),
    derive = derive_anhoej_results(q)
  )
}

# ============================================================================
# Scenario 1: CROSSING-ONLY (forekommer ofte i klinisk data med skiftende grupper)
# ============================================================================
# Data: 5 punkter pa 10, 5 pa 20, 5 pa 10, 5 pa 20 (i alt 20 punkter)
# - longest.run = 5  (kort, ingen runs-violation: 5 < 7 max)
# - n.crossings = 3  (faa kryds, crossings-violation: 3 < 6 min)
# - runs.signal = TRUE  (qicharts2 marker det som Anhoej-signal pga. crossings)
#
# KORREKT adfaerd:
# - runs_signal      = FALSE  (intet runs-issue)
# - crossings_signal = TRUE   (crossings under threshold)
# - anhoej_signal    = TRUE   (kombineret)
#
# AKTUEL (bugged) adfaerd:
# - runs_signal      = TRUE   ← FORKERT
# - crossings_signal = TRUE   ← korrekt
# - anhoej_signal    = TRUE (i derive_anhoej_results, men bygget paa forkert runs_signal)
test_that("crossing-only data triggers crossings_signal but NOT runs_signal (#468)", {
  skip("Bug #468 - reaktiver naar fix landed (verificerer korrekt adfaerd efter fix)")

  v <- c(rep(10, 5), rep(20, 5), rep(10, 5), rep(20, 5))
  data <- collect_anhoej(v)

  # Sanity-check qicharts2-output (disse vaerdier dokumenterer ground-truth)
  expect_equal(unique(data$qic$longest.run), 5)
  expect_equal(unique(data$qic$longest.run.max), 7)
  expect_equal(unique(data$qic$n.crossings), 3)
  expect_equal(unique(data$qic$n.crossings.min), 6)
  expect_true(data$qic$runs.signal[1]) # qicharts2 saetter kombineret signal

  # extract_anhoej_metadata (R/fct_anhoej_rules.R:97-99)
  expect_false(data$extract$runs_signal,
    info = "extract: 5 <= 7 max, ingen runs-violation"
  )
  expect_true(data$extract$crossings_signal,
    info = "extract: 3 < 6 min, crossings-violation"
  )

  # derive_anhoej_results (R/fct_spc_anhoej_derivation.R:78-80)
  expect_false(data$derive$runs_signal,
    info = "derive: 5 <= 7 max, ingen runs-violation"
  )
  expect_true(data$derive$crossings_signal,
    info = "derive: 3 < 6 min, crossings-violation"
  )
  expect_true(data$derive$anhoej_signal,
    info = "derive: kombineret (runs OR crossings)"
  )
})

# ============================================================================
# Scenario 2: RUNS-VIOLATION (lange ensartede runs)
# ============================================================================
# Data: 1:15 efterfulgt af 14:1 (29 punkter)
# - longest.run = 14 (lang, runs-violation: 14 > 8 max)
# - runs.signal = TRUE
test_that("long-run data triggers runs_signal correctly (#468)", {
  skip("Bug #468 - reaktiver naar fix landed")

  v <- c(1:15, 14:1)
  data <- collect_anhoej(v)

  expect_equal(unique(data$qic$longest.run), 14)
  expect_true(unique(data$qic$longest.run) > unique(data$qic$longest.run.max),
    info = "Skal vaere runs-violation"
  )

  expect_true(data$extract$runs_signal,
    info = "extract: lang run skal udloese runs_signal"
  )
  expect_true(data$derive$runs_signal,
    info = "derive: lang run skal udloese runs_signal"
  )
  expect_true(data$derive$anhoej_signal)
})

# ============================================================================
# Scenario 3: NO violations (random stabil proces) — control case
# ============================================================================
# Data: rnorm(30, mean=50, sd=5), set.seed(42)
# - longest.run = 6  (kort, OK)
# - n.crossings = 13 (mange, OK)
# - runs.signal = FALSE
test_that("stable random process triggers no Anhoej signals (#468 control)", {
  set.seed(42)
  v <- rnorm(30, mean = 50, sd = 5)
  data <- collect_anhoej(v)

  expect_false(data$qic$runs.signal[1])

  expect_false(data$extract$runs_signal)
  expect_false(data$extract$crossings_signal)

  expect_false(data$derive$runs_signal)
  expect_false(data$derive$crossings_signal)
  expect_false(data$derive$anhoej_signal,
    info = "Stabil proces -> ingen kombineret signal"
  )
})

# ============================================================================
# Scenario 4: BOTH violations (lang run AND for faa kryds)
# ============================================================================
# Data: 10 punkter pa 5, 10 pa 15
# - longest.run = 10 (lang, > 7 max)
# - n.crossings = 1  (faa, < 6 min)
test_that("data with both violations reports both signals separately (#468)", {
  skip("Bug #468 - reaktiver naar fix landed")

  v <- c(rep(5, 10), rep(15, 10))
  data <- collect_anhoej(v)

  expect_equal(unique(data$qic$longest.run), 10)
  expect_equal(unique(data$qic$longest.run.max), 7)
  expect_equal(unique(data$qic$n.crossings), 1)
  expect_equal(unique(data$qic$n.crossings.min), 6)

  expect_true(data$extract$runs_signal,
    info = "extract: 10 ens punkter -> runs-violation"
  )
  expect_true(data$extract$crossings_signal,
    info = "extract: 1 kryds < 6 min"
  )

  expect_true(data$derive$runs_signal)
  expect_true(data$derive$crossings_signal)
  expect_true(data$derive$anhoej_signal)
})

# ============================================================================
# Scenario 5: Boundary (longest.run == longest.run.max)
# ============================================================================
# Anhoej-runs-regel: signal kun hvis longest.run STRICT > longest.run.max
# (jf. qicharts2 source crsignal() L91-168).
#
# Eksisterende test test-derive-anhoej-results.R:427-448 haevder forkert at
# 8 == 8 udloeser runs-signal. Den test skal opdateres som del af #468.
test_that("boundary longest.run == max does NOT trigger runs_signal (#468)", {
  skip("Bug #468 - reaktiver naar fix landed")

  qic_data <- tibble::tibble(
    x = 1:10,
    y = 1:10,
    cl = 5,
    runs.signal = rep(FALSE, 10),
    longest.run = rep(8L, 10),
    longest.run.max = rep(8L, 10),
    n.crossings = rep(5L, 10),
    n.crossings.min = rep(3L, 10)
  )

  e <- extract_anhoej_metadata(qic_data)
  d <- derive_anhoej_results(qic_data)

  expect_false(e$runs_signal,
    info = "extract: 8 == 8 er ikke runs-violation (kraever STRICT >)"
  )
  expect_false(d$runs_signal,
    info = "derive: 8 == 8 er ikke runs-violation"
  )
  expect_false(d$anhoej_signal)
})

# ============================================================================
# Scenario 6: NA-guard (n_useful=0 -> qicharts2 returnerer NA)
# ============================================================================
# Med faa datapunkter kan qicharts2 ikke beregne forventede thresholds.
# biSPCharts skal degradere gracefully (ingen falske signaler).
test_that("NA in longest.run.max triggers no runs_signal (#468)", {
  skip("Bug #468 - reaktiver naar fix landed")

  qic_data <- tibble::tibble(
    x = 1:5,
    y = 1:5,
    cl = 3,
    runs.signal = rep(FALSE, 5),
    longest.run = rep(5L, 5),
    longest.run.max = rep(NA_real_, 5),
    n.crossings = rep(0L, 5),
    n.crossings.min = rep(NA_real_, 5)
  )

  e <- extract_anhoej_metadata(qic_data)
  d <- derive_anhoej_results(qic_data)

  expect_false(e$runs_signal, info = "extract: NA-threshold -> ingen signal")
  expect_false(e$crossings_signal, info = "extract: NA-threshold -> ingen signal")

  expect_false(d$runs_signal, info = "derive: NA-threshold -> ingen signal")
  expect_false(d$crossings_signal, info = "derive: NA-threshold -> ingen signal")
  expect_false(d$anhoej_signal)
})

# ============================================================================
# Scenario 7: NA-guard - longest.run kan ogsaa vaere NA
# ============================================================================
# Codex pegede paa at original NA-guard `!is.na(lr_max) && lr > lr_max` ikke
# er fuldstaendig — `lr` kan ogsaa vaere NA. Korrekt:
# `!is.na(lr) && !is.na(lr_max) && lr > lr_max`
test_that("NA in longest.run itself triggers no runs_signal (#468)", {
  skip("Bug #468 - reaktiver naar fix landed")

  qic_data <- tibble::tibble(
    x = 1:5,
    y = 1:5,
    cl = 3,
    runs.signal = rep(FALSE, 5),
    longest.run = rep(NA_integer_, 5),
    longest.run.max = rep(7L, 5),
    n.crossings = rep(5L, 5),
    n.crossings.min = rep(3L, 5)
  )

  d <- derive_anhoej_results(qic_data)

  expect_false(d$runs_signal,
    info = "longest.run=NA skal ikke udloese signal (NA-guard begge sider)"
  )
})

# ============================================================================
# Scenario 8: Excel Section D row-level Runs-signal (separat scope #468)
# ============================================================================
# `R/fct_spc_excel_analysis.R:404-405, 446-450` bruger qic_data$runs.signal
# direkte som "Runs-signal" rows. Aggregate-fix i derivation-funktioner daekker
# IKKE per-row Section D. Fix skal beregne row-level runs/crossings separat.
test_that("Excel Section D row-level signals separate runs vs crossings (#468)", {
  skip("Bug #468 Section D - separat scope-item, kraever Excel-pipeline fix")
  # Detail-kontrakt at definere naar Section D-fix designes:
  # - "Runs-signal"-row: TRUE kun hvis longest.run > longest.run.max
  # - "Crossings-signal"-row: TRUE kun hvis n.crossings < n.crossings.min
  # - "Samlet signal"-row: TRUE hvis enten af ovenstaaende
})

# ============================================================================
# Cross-check: BFHcharts giver samme tal som qicharts2
# ============================================================================
# Codex verificerede at BFHcharts kalder qicharts2 internt og videregiver
# raa Anhoej-tal uaendret. Denne test sikrer at antagelsen holder paa
# BFHcharts >= 0.14.0.
test_that("BFHcharts produces identical Anhoej raw values as qicharts2 (#468)", {
  skip_if_not_installed("BFHcharts")

  v <- c(rep(10, 5), rep(20, 5), rep(10, 5), rep(20, 5))
  q <- qicharts2::qic(x = seq_along(v), y = v, chart = "run", return.data = TRUE)
  d <- data.frame(idx = seq_along(v), val = v)
  b <- BFHcharts::bfh_qic(
    data = d, x = idx, y = val, chart_type = "run", return.data = TRUE
  )

  expect_equal(unique(b$longest.run), unique(q$longest.run),
    info = "BFHcharts videresender qicharts2 longest.run uaendret"
  )
  expect_equal(unique(b$longest.run.max), unique(q$longest.run.max))
  expect_equal(unique(b$n.crossings), unique(q$n.crossings))
  expect_equal(unique(b$n.crossings.min), unique(q$n.crossings.min))
  expect_equal(b$runs.signal[1], q$runs.signal[1],
    info = "BFHcharts.runs.signal == qicharts2.runs.signal (kombineret)"
  )
})
