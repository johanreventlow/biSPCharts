# Bedre tidshåndtering på y-aksen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Erstat den nuværende skrøbelige tidshåndtering på y-aksen med et robust system: tids-naturlige tick-breaks, komposit label-format (`1t 30m`), eksplicitte input-enheder (minutter/timer/dage) og auto-parsing af HH:MM og `hms`/`difftime`.

**Architecture:** Alt konverteres internt til en kanonisk enhed (minutter som `double`). Ren separation mellem parsing, enhedsvalg, tick-generering og label-formatering. Leveres i tre PR'er: (1) bugfix af eksisterende `"time"` enhed med komposit-format og pæne ticks, (2) parsing-lag og datamodel for nye enheder, (3) UI-dropdown, facade-integration og silent migration af gemte sessions.

**Tech Stack:** R (≥4.3), Shiny, Golem, ggplot2, testthat, `hms`, `lubridate`, `stringr` (alle allerede i Imports).

**Spec:** `docs/superpowers/specs/2026-04-17-time-yaxis-design.md`

---

## File Structure

### Nye filer
- `R/utils_time_formatting.R` — `format_time_composite()`, `time_breaks()`, helper-konstanter for kandidat-intervaller
- `R/utils_time_parsing.R` — `parse_time_to_minutes()`, HH:MM-regex, type-detektion
- `tests/testthat/test-time-formatting.R`
- `tests/testthat/test-time-parsing.R`
- `tests/testthat/test-local-storage-time-migration.R`

### Ændrede filer
- `R/utils_y_axis_formatting.R` — `format_y_axis_time()` bruger nye helpers, accepterer `input_unit`
- `R/utils_label_formatting.R` — `format_y_value()` bruger `format_time_composite()` for `"time_*"` enheder
- `R/utils_y_axis_model.R` — `is_time_unit()`, `default_time_unit_for_chart()`, opdater `determine_internal_class()` og `chart_type_to_ui_type()`
- `R/config_spc_config.R` — udvid `Y_AXIS_UI_TYPES_DA` med 3 nye tids-enheder
- `R/fct_spc_bfh_facade.R` — kald parsing-pipeline før data sendes til BFHcharts
- `R/utils_local_storage.R` — bump `LOCAL_STORAGE_SCHEMA_VERSION` til `"3.0"`, tilføj `migrate_time_yaxis_unit()`
- `R/utils_server_server_management.R` — tilføj silent forward-migration i peek + restore flows
- `R/utils_analytics_pins.R` — migration af gemte pins ved indlæsning

### Uændrede (men verificeres at fortsætte med at virke)
- `R/fct_spc_plot_generation.R`
- `R/fct_autodetect_unified.R`
- UI-modul-filer (dropdown befolkes dynamisk fra `Y_AXIS_UI_TYPES_DA`)

---

# FASE 1 — Bugfix: Komposit-format + tids-naturlige ticks (PR 1)

Antagelse: input er minutter (nuværende default). Output formateres pænt.

## Task 1.1: Opret kandidat-intervaller og komposit-format skelet

**Files:**
- Create: `R/utils_time_formatting.R`
- Test: `tests/testthat/test-time-formatting.R`

- [ ] **Step 1: Opret `tests/testthat/test-time-formatting.R` med basis-tests for `format_time_composite()`**

```r
# test-time-formatting.R
# Tests for tids-kompositformat og tids-naturlige tick-breaks.
# Implementerer Fase 1 af docs/superpowers/specs/2026-04-17-time-yaxis-design.md

library(testthat)

test_that("format_time_composite haandterer grundlaeggende minutter", {
  expect_equal(format_time_composite(0), "0m")
  expect_equal(format_time_composite(1), "1m")
  expect_equal(format_time_composite(45), "45m")
  expect_equal(format_time_composite(59), "59m")
})

test_that("format_time_composite haandterer timer og timer+minutter", {
  expect_equal(format_time_composite(60), "1t")
  expect_equal(format_time_composite(90), "1t 30m")
  expect_equal(format_time_composite(120), "2t")
  expect_equal(format_time_composite(125), "2t 5m")
  expect_equal(format_time_composite(1439), "23t 59m")
})

test_that("format_time_composite haandterer dage", {
  # Ved dage ignoreres minutter (max 2 komponenter: dage+timer)
  expect_equal(format_time_composite(1440), "1d")
  expect_equal(format_time_composite(1500), "1d 1t")
  expect_equal(format_time_composite(2880), "2d")
  expect_equal(format_time_composite(3660), "2d 13t")
})
```

- [ ] **Step 2: Kør testen og verificér at den fejler fordi funktionen ikke findes**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-formatting.R')"`

(Hvis `/usr/local/bin/Rscript` ikke findes, prøv `/Library/Frameworks/R.framework/Resources/bin/Rscript`.)

Expected: FAIL — `could not find function "format_time_composite"` eller tilsvarende.

- [ ] **Step 3: Implementér `format_time_composite()` + kandidat-konstanter i `R/utils_time_formatting.R`**

```r
# utils_time_formatting.R
# Tidshaandtering paa y-aksen: komposit-format og tids-naturlige tick-breaks
#
# Ansvar:
# - format_time_composite(): formatér minutter som "1t 30m", "45m", "2d 4t"
# - time_breaks(): generér tick-breaks paa tids-naturlige intervaller
# - TIME_BREAK_CANDIDATES: kandidat-intervaller i minutter
#
# Kanonisk intern enhed: minutter (double).
# Se docs/superpowers/specs/2026-04-17-time-yaxis-design.md for rationale.

# KANDIDAT-INTERVALLER ========================================================

#' Tids-naturlige kandidat-intervaller i minutter
#'
#' Bruges af time_breaks() til at vaelge tick-afstand. Daekker fra 1 minut
#' op til 30 dage.
#'
#' @keywords internal
TIME_BREAK_CANDIDATES <- c(
  1, 2, 5, 10, 15, 20, 30,       # minutter
  60, 120, 180, 240, 360, 720,   # timer (1t, 2t, 3t, 4t, 6t, 12t)
  1440, 2880, 10080, 43200       # dage (1d, 2d, 7d, 30d)
)

# KOMPOSIT FORMATERING ========================================================

#' Formatér minutter som komposit tidsstreng
#'
#' Runder input til hele minutter foer komponentopdeling for at undgaa
#' overflow (59,7 min → `1t`, ikke `60m`). Max 2 komponenter for laesbarhed:
#' ved dage+timer vises ikke minutter.
#'
#' @param minutes numeric. Tidsvaerdi i minutter. Kan vaere negativ.
#' @return character. Komposit-formateret streng. NA_character_ hvis input er NA.
#' @keywords internal
#' @examples
#' format_time_composite(90)    # "1t 30m"
#' format_time_composite(51)    # "51m"
#' format_time_composite(3660)  # "2d 13t"
#' format_time_composite(-30)   # "-30m"
format_time_composite <- function(minutes) {
  if (length(minutes) == 0) {
    return(character(0))
  }

  vapply(minutes, format_time_composite_single, character(1))
}

#' @keywords internal
format_time_composite_single <- function(v) {
  if (is.na(v)) {
    return(NA_character_)
  }

  sign_prefix <- if (v < 0) "-" else ""
  v_int <- as.integer(round(abs(v)))

  d <- v_int %/% 1440L
  rem <- v_int %% 1440L
  t <- rem %/% 60L
  m <- rem %% 60L

  result <- if (d > 0L && t > 0L) {
    paste0(d, "d ", t, "t")
  } else if (d > 0L) {
    paste0(d, "d")
  } else if (t > 0L && m > 0L) {
    paste0(t, "t ", m, "m")
  } else if (t > 0L) {
    paste0(t, "t")
  } else if (m > 0L) {
    paste0(m, "m")
  } else {
    "0m"
  }

  paste0(sign_prefix, result)
}
```

- [ ] **Step 4: Kør testen og verificér at den passerer**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-formatting.R')"`

Expected: PASS (alle 3 test_that-blokke).

- [ ] **Step 5: Commit**

```bash
git add R/utils_time_formatting.R tests/testthat/test-time-formatting.R
git commit -m "feat(time-axis): tilfoej format_time_composite med kanoniske minutter

Komposit-format (1t 30m, 2d 4t) med max 2 komponenter. Runder input
til hele minutter foer komponentopdeling for at undgaa overflow-fejl
som 59,7m giver '60m' i stedet for '1t'. Del af Fase 1 i
docs/superpowers/specs/2026-04-17-time-yaxis-design.md."
```

---

## Task 1.2: Udvid `format_time_composite()` med edge-cases

**Files:**
- Modify: `R/utils_time_formatting.R`
- Modify: `tests/testthat/test-time-formatting.R`

- [ ] **Step 1: Tilføj edge-case tests**

Tilføj disse `test_that()` blokke til `tests/testthat/test-time-formatting.R`:

```r
test_that("format_time_composite runder overflow korrekt", {
  # 59,7 min rundet til 60 → 1t (ikke 60m)
  expect_equal(format_time_composite(59.7), "1t")
  # 60,4 min rundet til 60 → 1t
  expect_equal(format_time_composite(60.4), "1t")
  # 1439,7 min rundet til 1440 → 1d
  expect_equal(format_time_composite(1439.7), "1d")
  # 119,5 min rundet til 120 → 2t
  expect_equal(format_time_composite(119.5), "2t")
})

test_that("format_time_composite haandterer sub-minut vaerdier", {
  # 0,25 min → rundes til 0 → "0m"
  expect_equal(format_time_composite(0.25), "0m")
  # 0,6 min → rundes til 1 → "1m"
  expect_equal(format_time_composite(0.6), "1m")
})

test_that("format_time_composite haandterer negative vaerdier", {
  expect_equal(format_time_composite(-30), "-30m")
  expect_equal(format_time_composite(-90), "-1t 30m")
  expect_equal(format_time_composite(-1440), "-1d")
})

test_that("format_time_composite haandterer NA og tomme vektorer", {
  expect_true(is.na(format_time_composite(NA)))
  expect_true(is.na(format_time_composite(NA_real_)))
  expect_equal(format_time_composite(numeric(0)), character(0))
})

test_that("format_time_composite er vektoriseret", {
  input <- c(0, 60, 90, NA, 1440)
  expected <- c("0m", "1t", "1t 30m", NA_character_, "1d")
  expect_equal(format_time_composite(input), expected)
})

test_that("format_time_composite: regression test for 0,8541667 timer-bugget", {
  # 0,8541667 timer = 51,25 minutter. Forventet: "51m", ikke "0,8541667 timer"
  minutes_51 <- 0.8541667 * 60
  expect_equal(format_time_composite(minutes_51), "51m")
})
```

- [ ] **Step 2: Kør tests og verificér at alle passerer**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-formatting.R')"`

Expected: PASS — funktionen er allerede skrevet til at håndtere disse cases. Hvis en edge-case fejler, fix i `format_time_composite_single` før commit.

- [ ] **Step 3: Commit**

```bash
git add tests/testthat/test-time-formatting.R
git commit -m "test(time-axis): daek edge-cases i format_time_composite

Overflow-rounding, sub-minut, negative vaerdier, NA, vektorisering,
og regression test for 0,8541667 timer-bugget (51 min)."
```

---

## Task 1.3: Implementér `time_breaks()` — tids-naturlige tick-intervaller

**Files:**
- Modify: `R/utils_time_formatting.R`
- Modify: `tests/testthat/test-time-formatting.R`

- [ ] **Step 1: Tilføj failing tests for `time_breaks()`**

```r
test_that("time_breaks vaelger pæne intervaller for typiske ranges", {
  # Range 0-120 min → 30m interval → 5 ticks
  breaks <- time_breaks(c(0, 120))
  expect_equal(breaks, c(0, 30, 60, 90, 120))

  # Range 15-185 min → 30m interval (snap til grid)
  breaks <- time_breaks(c(15, 185))
  expect_equal(breaks, c(0, 30, 60, 90, 120, 150, 180))

  # Range 0-480 min (0-8t) → 2t interval
  breaks <- time_breaks(c(0, 480))
  expect_equal(breaks, c(0, 120, 240, 360, 480))

  # Range 0-7200 min (0-5d) → 1d interval
  breaks <- time_breaks(c(0, 7200))
  expect_equal(breaks, c(0, 1440, 2880, 4320, 5760, 7200))
})

test_that("time_breaks respekterer target_n argument", {
  # Default target_n = 5L; med target_n = 3 skal intervaller vaere grovere
  breaks <- time_breaks(c(0, 120), target_n = 3L)
  expect_true(length(breaks) >= 3 && length(breaks) <= 4)
})

test_that("time_breaks haandterer konstante og tomme inputs", {
  # Konstant range (min == max) → fall back til minimal interval
  breaks <- time_breaks(c(60, 60))
  expect_true(length(breaks) >= 1)

  # NA input → returnér numeric(0)
  breaks_na <- time_breaks(c(NA_real_, NA_real_))
  expect_true(length(breaks_na) == 0 || all(is.na(breaks_na)))

  # Tom input
  expect_equal(time_breaks(numeric(0)), numeric(0))
})

test_that("time_breaks snapper til interval-grid", {
  # Input range 45-155 → snap til 30m-grid. Floor-snap på begge ender giver
  # 30-150 (ggplot2's expand udvider selv aksen, så y_max=155 er synligt
  # over sidste tick).
  breaks <- time_breaks(c(45, 155))
  expect_true(all(breaks %% 30 == 0))
  expect_true(min(breaks) <= 45)
  expect_true(max(breaks) >= 150)
  # Sidste tick skal være indenfor én intervalafstand af y_max
  # (ellers er aksen for sparsomt dækket)
  expect_true(max(breaks) >= 155 - 30)
})
```

- [ ] **Step 2: Kør testen og verificér fail**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-formatting.R')"`

Expected: FAIL — `could not find function "time_breaks"`.

- [ ] **Step 3: Implementér `time_breaks()` i `R/utils_time_formatting.R`**

Tilføj efter `format_time_composite_single`:

```r
# TICK-BREAKS =================================================================

#' Generér tids-naturlige tick-breaks
#'
#' Vaelger det STOERSTE interval fra TIME_BREAK_CANDIDATES der stadig giver
#' mindst `target_n` ticks inden for data-range. Kriteriet resulterer i
#' naturligt grovere ticks for store ranges og finere for smalle ranges.
#' Begge ender snappes med floor() til multipla af det valgte interval
#' (ggplot2 udvider selv aksen med expansion(), saa y_max er stadig synligt).
#'
#' @param y_values numeric. Data-range at generere ticks til.
#' @param target_n integer. Minimums-antal ticks. Default 5L.
#' @return numeric vektor. Tick-positioner i minutter.
#' @keywords internal
#' @examples
#' time_breaks(c(0, 120))    # 0 30 60 90 120
#' time_breaks(c(15, 185))   # 0 30 60 90 120 150 180
#' time_breaks(c(0, 480))    # 0 120 240 360 480
time_breaks <- function(y_values, target_n = 5L) {
  # Defensiv: filtrer NA og tomme inputs
  y_clean <- y_values[!is.na(y_values)]
  if (length(y_clean) == 0L) {
    return(numeric(0))
  }

  y_min <- min(y_clean)
  y_max <- max(y_clean)

  # Konstant range: returnér enkelt tick paa vaerdien
  if (y_min == y_max) {
    return(y_min)
  }

  # Primaer: stoerste interval med >= target_n ticks.
  # Intervallerne itereres fra lille til stor; n_ticks falder monotont, saa
  # vi kan break ud af loekken saa snart n_ticks falder under target_n.
  chosen_interval <- NULL
  for (interval in TIME_BREAK_CANDIDATES) {
    start <- floor(y_min / interval) * interval
    end <- floor(y_max / interval) * interval
    n_ticks <- (end - start) / interval + 1L
    if (n_ticks >= target_n) {
      chosen_interval <- interval
    } else if (!is.null(chosen_interval)) {
      # Vi har et valg; videre intervaller vil kun give faerre ticks
      break
    }
  }

  # Fallback 1: meget smal range — brug mindste interval med >= 2 ticks
  if (is.null(chosen_interval)) {
    for (interval in TIME_BREAK_CANDIDATES) {
      start <- floor(y_min / interval) * interval
      end <- floor(y_max / interval) * interval
      n_ticks <- (end - start) / interval + 1L
      if (n_ticks >= 2L) {
        chosen_interval <- interval
        break
      }
    }
  }

  # Fallback 2: patologisk case — brug mindste kandidat
  if (is.null(chosen_interval)) {
    chosen_interval <- TIME_BREAK_CANDIDATES[[1]]
  }

  start <- floor(y_min / chosen_interval) * chosen_interval
  end <- floor(y_max / chosen_interval) * chosen_interval

  seq(start, end, by = chosen_interval)
}
```

- [ ] **Step 4: Kør testen og verificér PASS**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-formatting.R')"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/utils_time_formatting.R tests/testthat/test-time-formatting.R
git commit -m "feat(time-axis): tilfoej time_breaks for tids-naturlige ticks

Vaelger mindste interval fra TIME_BREAK_CANDIDATES der giver 3-7 ticks
inden for data-range. Snapper start/slut til interval-grid saa ticks
falder paa paene vaerdier (0, 30, 60, 90, 120 i stedet for 15, 67, 119)."
```

---

## Task 1.4: Integrér komposit-format i `format_y_axis_time()`

**Files:**
- Modify: `R/utils_y_axis_formatting.R:182-220` (hele `format_y_axis_time` funktionen)
- Modify: `tests/testthat/test-y-axis-formatting.R` (tests der refererer til gammel adfærd)

- [ ] **Step 1: Opdater eksisterende tests i `tests/testthat/test-y-axis-formatting.R` til at matche nyt output**

Den eksisterende test for `format_time_with_unit` (linje 86-118) tester den gamle format der giver `"1 timer"`, `"1,5 timer"` etc. Efter integrationen slettes denne hjælpefunktion. Marker testen som deprecated:

Erstat `test_that("format_time_with_unit consolidates duplication correctly", { ... })` samt de to efterfølgende `test_that("format_time_with_unit handles NA values", ...)` og `test_that("format_time_with_unit handles edge cases", ...)` med:

```r
test_that("format_time_with_unit er fjernet til fordel for format_time_composite", {
  skip("Funktionen er fjernet. Se format_time_composite i utils_time_formatting.R")
})
```

Tilføj også ny positiv-test for den nye formatering:

```r
test_that("apply_y_axis_formatting med time-enhed bruger komposit-format", {
  qic_data <- data.frame(x = 1:5, y = c(30, 60, 90, 120, 150))
  plot <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point()

  result <- apply_y_axis_formatting(plot, "time", qic_data)
  expect_s3_class(result, "ggplot")

  built <- ggplot2::ggplot_build(result)
  y_labels <- built$layout$panel_params[[1]]$y$get_labels()

  # Labels skal matche komposit-patterns: "30m", "1t", "1t 30m", "1d", "1d 4t"
  y_labels_clean <- y_labels[!is.na(y_labels)]
  expect_true(all(grepl("^-?(\\\\d+d( \\\\d+t)?|\\\\d+t( \\\\d+m)?|\\\\d+m)$", y_labels_clean)))
})
```

- [ ] **Step 2: Kør tests — forvent at den nye positiv-test fejler (format_y_axis_time bruger stadig det gamle format)**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-y-axis-formatting.R')"`

Expected: Den nye positiv-test FEJLER fordi `format_y_axis_time` stadig skriver `"1,5 timer"`. De øvrige tests passerer (inkl. `skip()`-markeringerne).

- [ ] **Step 3: Erstat `format_y_axis_time()` implementation i `R/utils_y_axis_formatting.R`**

Find funktionen på linje 182 (`format_y_axis_time <- function(qic_data) {`) og erstat HELE funktionen + efterfølgende helper `format_time_with_unit` (linje 261-302) med:

```r
#' Format Y-Axis for Time Data (Composite Format: "1t 30m", "2d 4t")
#'
#' Uses tids-naturlige tick-breaks og komposit label-format. Input
#' antages at vaere i minutter (kanonisk intern enhed).
#'
#' @param qic_data Data frame with qic data containing y column (time values in minutes)
#'
#' @return ggplot2 scale_y_continuous layer for time formatting
#' @keywords internal
format_y_axis_time <- function(qic_data) {
  if (is.null(qic_data) || !"y" %in% names(qic_data)) {
    log_warn(
      "format_y_axis_time: missing qic_data or y column, using default formatting",
      .context = "Y_AXIS_FORMAT"
    )
    return(ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(.25, .25))))
  }

  y_values <- qic_data$y
  breaks <- time_breaks(y_values)

  ggplot2::scale_y_continuous(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    breaks = breaks,
    labels = function(x) {
      if (inherits(x, "waiver")) {
        return(x)
      }
      if (!is.numeric(x)) {
        x <- suppressWarnings(as.numeric(as.character(x)))
      }
      format_time_composite(x)
    }
  )
}
```

VIGTIGT: Slet også den gamle `format_time_with_unit()` helper — den er ikke længere refereret fra nogen kaldsted.

- [ ] **Step 4: Kør alle y-axis tests og verificér PASS**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-y-axis-formatting.R')"`

Expected: Alle tests passerer.

- [ ] **Step 5: Kør fuld test-suite for at fange andre consumers**

Run: `'/usr/local/bin/Rscript' -e "devtools::test()"`

Expected: PASS. Hvis noget andet sted i kodebasen refererer `format_time_with_unit`, grep og ret kaldet til `format_time_composite`:

```bash
grep -rn "format_time_with_unit" R/ tests/
```

- [ ] **Step 6: Commit**

```bash
git add R/utils_y_axis_formatting.R tests/testthat/test-y-axis-formatting.R
git commit -m "refactor(time-axis): format_y_axis_time bruger komposit og paene ticks

Erstatter max_minutes-switch + nsmall=1-rounding med time_breaks()
og format_time_composite(). Fjerner format_time_with_unit helper
som ikke laengere er noedvendig. Loeser P1 og P3 fra
docs/superpowers/specs/2026-04-17-time-yaxis-design.md."
```

---

## Task 1.5: Opdater `format_y_value()` for `"time"` enhed

**Files:**
- Modify: `R/utils_label_formatting.R:97-134` (time-grenen af `format_y_value`)
- Create: `tests/testthat/test-label-formatting.R` (hvis ikke findes)

- [ ] **Step 1: Tjek om der findes eksisterende test af `format_y_value`**

```bash
grep -n "format_y_value" tests/testthat/*.R
```

Hvis tests af den gamle `"1,5 timer"`-output findes, noter filerne. Hvis ikke, opret ny test-fil.

- [ ] **Step 2: Tilføj/opdater test i `tests/testthat/test-label-formatting.R` (opret filen hvis ikke findes)**

```r
# test-label-formatting.R
library(testthat)

test_that("format_y_value med y_unit='time' bruger komposit-format", {
  expect_equal(format_y_value(0, "time"), "0m")
  expect_equal(format_y_value(30, "time"), "30m")
  expect_equal(format_y_value(60, "time"), "1t")
  expect_equal(format_y_value(90, "time"), "1t 30m")
  expect_equal(format_y_value(1440, "time"), "1d")
  expect_equal(format_y_value(3660, "time"), "2d 13t")
})

test_that("format_y_value ignorerer y_range for time (irrelevant i komposit)", {
  expect_equal(format_y_value(60, "time", y_range = c(0, 120)), "1t")
  expect_equal(format_y_value(60, "time", y_range = c(0, 10000)), "1t")
  expect_equal(format_y_value(60, "time", y_range = NULL), "1t")
})

test_that("format_y_value returnerer NA for NA input", {
  expect_true(is.na(format_y_value(NA_real_, "time")))
})
```

- [ ] **Step 3: Kør testen — forvent fail pga. gamle format**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-label-formatting.R')"`

Expected: FAIL — funktionen returnerer stadig `"1 timer"` eller lignende.

- [ ] **Step 4: Erstat time-grenen i `R/utils_label_formatting.R`**

Find blokken på linje 97 (`if (y_unit == "time") {`) og erstat HELE blokken (linje 97-134) med:

```r
  # Time formatting (input: minutes) - komposit-format
  if (y_unit == "time") {
    return(format_time_composite(val))
  }
```

Fjern også warning-sætningen om manglende `y_range` — den er ikke længere nødvendig.

- [ ] **Step 5: Kør label-tests PASS**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-label-formatting.R')"`

Expected: PASS.

- [ ] **Step 6: Kør fuld test-suite**

Run: `'/usr/local/bin/Rscript' -e "devtools::test()"`

Expected: Alle tests passerer.

- [ ] **Step 7: Commit**

```bash
git add R/utils_label_formatting.R tests/testthat/test-label-formatting.R
git commit -m "refactor(time-axis): format_y_value bruger komposit for time-enhed

Delegerer til format_time_composite() for konsistens med
format_y_axis_time(). y_range-parameteren er ikke laengere
noedvendig for time-enheden."
```

---

## Task 1.6: Manuel røgtest af Fase 1

**Files:** Ingen kode-ændringer. Ren verifikation.

- [ ] **Step 1: Kør appen i dev-mode**

Start appen som normalt (fx via `golem::run_dev()` eller tilsvarende projektspecifik launcher).

- [ ] **Step 2: Upload sample-data med tid i minutter som y-værdi**

Brug et dataset hvor y-værdier spænder fx 30-180 (minutter). Vælg `Tid mellem hændelser` som y-enhed.

- [ ] **Step 3: Verificér visuelt**

- Ticks på y-aksen skal være på tids-naturlige værdier (fx `0, 30m, 60m, 90m, 120m, 150m, 180m`) — ikke `0, 45, 90, 135, 180` eller lignende ggplot2-defaults.
- Labels skal være komposit (`1t 30m` ikke `1,5 timer`).
- Ingen værdi må vise mere end 2 komponenter eller decimaler.

- [ ] **Step 4: Test edge cases i UI**

- Upload data med meget små værdier (0-5 min) → ticks `0, 1, 2, 3, 4, 5` med labels `0m, 1m, ..., 5m`.
- Upload data der spænder dage (0-7200 min) → ticks `0, 1d, 2d, 3d, 4d, 5d`.

- [ ] **Step 5: Hvis alt virker — ingen commit. Hvis noget er skævt — åbn issue og ret før PR merges.**

**END FASE 1.** Opret PR titlet `"fix(time-axis): paene tick-breaks og komposit-format paa y-aksen"`.

---

# FASE 2a — Parsing + model (PR 2)

Tilføjer `is_time_unit()` helper, udvider `Y_AXIS_UI_TYPES_DA` (uden at fjerne det gamle `"time"` endnu), og introducerer `parse_time_to_minutes()`. UI-dropdown ændres IKKE i denne PR (UI-flow uændret indtil Fase 2b).

## Task 2a.1: Tilføj `is_time_unit()` og familie-baseret klassifikation

**Files:**
- Modify: `R/utils_y_axis_model.R`
- Modify: `tests/testthat/test-y-axis-model.R`

- [ ] **Step 1: Tilføj failing test for `is_time_unit()` og opdaterede klassifikationer**

Åbn `tests/testthat/test-y-axis-model.R` og tilføj i slutningen:

```r
test_that("is_time_unit identificerer alle tids-enheder (inkl. legacy)", {
  # Legacy
  expect_true(is_time_unit("time"))
  # Nye enheder
  expect_true(is_time_unit("time_minutes"))
  expect_true(is_time_unit("time_hours"))
  expect_true(is_time_unit("time_days"))
  # Ikke-tids-enheder
  expect_false(is_time_unit("count"))
  expect_false(is_time_unit("percent"))
  expect_false(is_time_unit("rate"))
  # Edge cases
  expect_equal(is_time_unit(NULL), logical(0))
  expect_false(is_time_unit(NA_character_))
  expect_false(is_time_unit(""))
})

test_that("determine_internal_class bruger is_time_unit for alle tids-enheder", {
  expect_equal(determine_internal_class("time", y = c(1, 2, 3)), "TIME_BETWEEN")
  expect_equal(determine_internal_class("time_minutes", y = c(30, 60)), "TIME_BETWEEN")
  expect_equal(determine_internal_class("time_hours", y = c(1.5, 2)), "TIME_BETWEEN")
  expect_equal(determine_internal_class("time_days", y = c(1, 2)), "TIME_BETWEEN")
})

test_that("chart_type_to_ui_type returnerer time_days for t-kort", {
  expect_equal(chart_type_to_ui_type("t"), "time_days")
})
```

- [ ] **Step 2: Kør tests og verificér fail**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-y-axis-model.R')"`

Expected: FAIL — `could not find function "is_time_unit"` og `chart_type_to_ui_type("t")` returnerer `"time"` (ikke `"time_days"`).

- [ ] **Step 3: Tilføj `is_time_unit()` og opdater eksisterende funktioner i `R/utils_y_axis_model.R`**

Indsæt FØRST `is_time_unit()` helper efter `INTERNAL_CLASSES`-definitionen (omkring linje 12):

```r
#' Afgoer om en y-akse UI-type tilhoerer tids-familien
#'
#' Omfatter legacy `"time"` og de nye enheds-varianter fra Fase 2.
#' Bruges af `determine_internal_class()` og `default_time_unit_for_chart()`.
#'
#' @param ui_type Character vektor eller NULL.
#' @return Logical vektor samme laengde som ui_type. FALSE for NA/tom.
#' @keywords internal
is_time_unit <- function(ui_type) {
  if (is.null(ui_type) || length(ui_type) == 0L) {
    return(logical(0))
  }
  ui <- tolower(as.character(ui_type))
  !is.na(ui) & ui %in% c("time", "time_minutes", "time_hours", "time_days")
}
```

Erstat linje 32-34 (den gamle `if (ui == "time")`-blok i `determine_internal_class`) med:

```r
  if (is_time_unit(ui)) {
    return(INTERNAL_CLASSES$TIME_BETWEEN)
  }
```

Erstat linje 112-114 i `chart_type_to_ui_type()` (`if (ct == "t") return("time")`):

```r
  if (ct == "t") {
    return("time_days")
  }
```

- [ ] **Step 4: Kør tests PASS**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-y-axis-model.R')"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/utils_y_axis_model.R tests/testthat/test-y-axis-model.R
git commit -m "feat(time-axis): tilfoej is_time_unit helper og familie-klassifikation

Erstatter exact-match mod 'time' med is_time_unit() der ogsaa omfatter
time_minutes/time_hours/time_days. chart_type_to_ui_type('t') returnerer
nu time_days (var time) saa t-kort faar dage som default enhed."
```

---

## Task 2a.2: Tilføj `default_time_unit_for_chart()`

**Files:**
- Modify: `R/utils_y_axis_model.R`
- Modify: `tests/testthat/test-y-axis-model.R`

- [ ] **Step 1: Tilføj failing test**

Tilføj i slutningen af `tests/testthat/test-y-axis-model.R`:

```r
test_that("default_time_unit_for_chart returnerer passende enhed pr. korttype", {
  expect_equal(default_time_unit_for_chart("t"), "time_days")
  # For ikke-tids-specifikke korttyper returneres NULL
  expect_null(default_time_unit_for_chart("i"))
  expect_null(default_time_unit_for_chart("p"))
  expect_null(default_time_unit_for_chart("c"))
  expect_null(default_time_unit_for_chart("u"))
  # NA / NULL input
  expect_null(default_time_unit_for_chart(NULL))
  expect_null(default_time_unit_for_chart(NA_character_))
})
```

- [ ] **Step 2: Kør test fail**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-y-axis-model.R')"`

Expected: FAIL — `could not find function "default_time_unit_for_chart"`.

- [ ] **Step 3: Tilføj funktionen i `R/utils_y_axis_model.R`**

Tilføj i slutningen af filen:

```r
#' Foreslaa default tids-enhed for en korttype
#'
#' Bruges af UI-laget til at pre-vaelge en passende tids-enhed naar
#' brugeren skifter korttype. Returnerer NULL for korttyper der ikke
#' typisk bruger tid paa y-aksen — caller falder saa tilbage til eget default.
#'
#' @param chart_type character. qicharts2-kode eller dansk label.
#' @return character eller NULL.
#' @keywords internal
default_time_unit_for_chart <- function(chart_type) {
  if (is.null(chart_type) || length(chart_type) == 0L) {
    return(NULL)
  }
  if (is.na(chart_type)) {
    return(NULL)
  }
  ct <- get_qic_chart_type(chart_type)
  if (identical(ct, "t")) {
    return("time_days")
  }
  NULL
}
```

- [ ] **Step 4: Kør tests PASS**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-y-axis-model.R')"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/utils_y_axis_model.R tests/testthat/test-y-axis-model.R
git commit -m "feat(time-axis): tilfoej default_time_unit_for_chart

Returnerer time_days for t-kort, NULL for andre korttyper. Bruges af
UI-laget til at pre-vaelge tids-enhed ved skift af korttype."
```

---

## Task 2a.3: Implementér `parse_time_to_minutes()` — numeric path

**Files:**
- Create: `R/utils_time_parsing.R`
- Create: `tests/testthat/test-time-parsing.R`

- [ ] **Step 1: Opret `tests/testthat/test-time-parsing.R`**

```r
# test-time-parsing.R
# Tests for parse_time_to_minutes() — konverterer diverse tids-inputs
# til kanoniske minutter.

library(testthat)

test_that("parse_time_to_minutes haandterer numerisk input med input_unit", {
  expect_equal(parse_time_to_minutes(90, "time_minutes"), 90)
  expect_equal(parse_time_to_minutes(1.5, "time_hours"), 90)
  expect_equal(parse_time_to_minutes(0.0625, "time_days"), 90)
})

test_that("parse_time_to_minutes er vektoriseret", {
  input <- c(30, 60, 90, 120)
  expect_equal(parse_time_to_minutes(input, "time_minutes"), c(30, 60, 90, 120))
  expect_equal(parse_time_to_minutes(c(1, 2, 3), "time_hours"), c(60, 120, 180))
  expect_equal(parse_time_to_minutes(c(1, 2), "time_days"), c(1440, 2880))
})

test_that("parse_time_to_minutes haandterer NA", {
  expect_true(is.na(parse_time_to_minutes(NA_real_, "time_minutes")))
  expect_equal(
    parse_time_to_minutes(c(1, NA, 2), "time_hours"),
    c(60, NA_real_, 120)
  )
})

test_that("parse_time_to_minutes defaulter til time_minutes for ugyldig input_unit", {
  suppressWarnings({
    expect_equal(parse_time_to_minutes(90, NULL), 90)
    expect_equal(parse_time_to_minutes(90, "bogus_unit"), 90)
  })
})
```

- [ ] **Step 2: Kør testen og verificér fail**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-parsing.R')"`

Expected: FAIL — funktionen findes ikke.

- [ ] **Step 3: Implementér numeric path i `R/utils_time_parsing.R`**

```r
# utils_time_parsing.R
# Parsing af tids-input til kanoniske minutter.
#
# Understoetter:
# - Numeric + input_unit ('time_minutes', 'time_hours', 'time_days')
# - hms::hms / difftime objekter
# - Karakter-strenge i HH:MM og HH:MM:SS format (sekunder bevares som brøker)
# - NA og ugyldige vaerdier haandteres graciously
#
# Kanonisk output: minutter som double.
# Se docs/superpowers/specs/2026-04-17-time-yaxis-design.md.

# ENHEDSKONSTANTER ============================================================

#' Skaleringsfaktor fra input-enhed til kanoniske minutter
#' @keywords internal
TIME_INPUT_UNIT_SCALES <- c(
  time_minutes = 1,
  time_hours   = 60,
  time_days    = 1440
)

# PARSING HOVEDFUNKTION =======================================================

#' Konvertér tids-input til kanoniske minutter
#'
#' @param x Input-vektor. Kan vaere numeric, character (HH:MM[:SS]),
#'   hms/difftime objekt, eller NA.
#' @param input_unit Character. En af 'time_minutes', 'time_hours', 'time_days'.
#'   Ignoreres hvis x er hms/difftime eller HH:MM-streng. Default: 'time_minutes'.
#' @return Numeric vektor. Minutter som double. NA for ugyldig input.
#' @keywords internal
parse_time_to_minutes <- function(x, input_unit = "time_minutes") {
  if (length(x) == 0L) {
    return(numeric(0))
  }

  # Validér input_unit; fall-back til minutter med advarsel
  if (is.null(input_unit) || !input_unit %in% names(TIME_INPUT_UNIT_SCALES)) {
    warning(
      "parse_time_to_minutes: ukendt input_unit '",
      input_unit %||% "NULL",
      "' — antager time_minutes"
    )
    input_unit <- "time_minutes"
  }

  scale <- TIME_INPUT_UNIT_SCALES[[input_unit]]

  # Numeric path
  if (is.numeric(x)) {
    return(x * scale)
  }

  # Fremtidige paths (hms/difftime/character) tilfoejes i senere tasks
  suppressWarnings({
    coerced <- as.numeric(as.character(x))
  })
  if (all(is.na(coerced)) && !all(is.na(x))) {
    warning(
      "parse_time_to_minutes: kunne ikke parse input af type '",
      paste(class(x), collapse = "/"),
      "' — returnerer NA. HH:MM og hms-support kommer i senere task."
    )
  }
  coerced * scale
}
```

Bemærk: `%||%` er allerede tilgængelig i biSPCharts via rlang/Shiny (bruges i `R/utils_y_axis_model.R`).

- [ ] **Step 4: Kør testen PASS**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-parsing.R')"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/utils_time_parsing.R tests/testthat/test-time-parsing.R
git commit -m "feat(time-axis): parse_time_to_minutes numeric-path

Konverterer numerisk input til kanoniske minutter baseret paa
input_unit. Ukendt enhed giver warning og fall-back til minutter.
hms/difftime/HH:MM support kommer i efterfoelgende tasks."
```

---

## Task 2a.4: Tilføj `hms` og `difftime` support

**Files:**
- Modify: `R/utils_time_parsing.R`
- Modify: `tests/testthat/test-time-parsing.R`

- [ ] **Step 1: Tilføj tests for hms/difftime**

Tilføj i slutningen af `tests/testthat/test-time-parsing.R`:

```r
test_that("parse_time_to_minutes haandterer difftime med forskellige enheder", {
  # difftime i minutter — input_unit ignoreres for difftime
  dt_min <- as.difftime(c(30, 60, 90), units = "mins")
  expect_equal(parse_time_to_minutes(dt_min, "time_hours"), c(30, 60, 90))

  # difftime i timer
  dt_hrs <- as.difftime(c(1, 2, 3), units = "hours")
  expect_equal(parse_time_to_minutes(dt_hrs, "time_minutes"), c(60, 120, 180))

  # difftime i sekunder (giver brøkdele af minutter)
  dt_sec <- as.difftime(c(60, 120, 90), units = "secs")
  expect_equal(parse_time_to_minutes(dt_sec), c(1, 2, 1.5))
})

test_that("parse_time_to_minutes haandterer hms objekter", {
  skip_if_not_installed("hms")
  h <- hms::hms(seconds = c(90 * 60, 30 * 60))  # 90 min og 30 min
  expect_equal(parse_time_to_minutes(h), c(90, 30))
})
```

- [ ] **Step 2: Kør tests fail**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-parsing.R')"`

Expected: FAIL — warnings om at kunne parse; resultat bliver NA.

- [ ] **Step 3: Udvid `parse_time_to_minutes()` med hms/difftime path**

I `R/utils_time_parsing.R`, indsæt FØR numeric-checken (dvs. før `if (is.numeric(x))`):

```r
  # difftime eller hms: konvertér direkte til minutter, ignorér input_unit
  if (inherits(x, "difftime") || inherits(x, "hms")) {
    return(as.numeric(x, units = "mins"))
  }
```

- [ ] **Step 4: Kør tests PASS**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-parsing.R')"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/utils_time_parsing.R tests/testthat/test-time-parsing.R
git commit -m "feat(time-axis): parse_time_to_minutes understoetter hms og difftime

Objekt-type tilsidesaetter input_unit: vi laeser enheden direkte
fra objektet via as.numeric(x, units = 'mins'). Daekker baade
hms::hms() og base R difftime."
```

---

## Task 2a.5: Tilføj HH:MM og HH:MM:SS parsing

**Files:**
- Modify: `R/utils_time_parsing.R`
- Modify: `tests/testthat/test-time-parsing.R`

- [ ] **Step 1: Tilføj tests for HH:MM-parsing**

Tilføj i slutningen af `tests/testthat/test-time-parsing.R`:

```r
test_that("parse_time_to_minutes haandterer HH:MM-strenge", {
  expect_equal(parse_time_to_minutes("01:30"), 90)
  expect_equal(parse_time_to_minutes("00:45"), 45)
  expect_equal(parse_time_to_minutes("02:00"), 120)
  # Vaerdier >24t er valide (kumulerede tider)
  expect_equal(parse_time_to_minutes("25:15"), 25 * 60 + 15)
  # Enkelt-cifre timer og minutter
  expect_equal(parse_time_to_minutes("1:5"), 65)
})

test_that("parse_time_to_minutes haandterer HH:MM:SS", {
  # Sekunder bevares som broekdele af minutter
  expect_equal(parse_time_to_minutes("01:30:15"), 90.25)
  expect_equal(parse_time_to_minutes("01:30:45"), 90.75)
  expect_equal(parse_time_to_minutes("00:00:30"), 0.5)
})

test_that("parse_time_to_minutes haandterer ugyldige strenge som NA", {
  suppressWarnings({
    expect_true(is.na(parse_time_to_minutes("invalid")))
    expect_true(is.na(parse_time_to_minutes("abc:def")))
    expect_true(is.na(parse_time_to_minutes("")))
  })
})

test_that("parse_time_to_minutes haandterer blandet karakter-vektor", {
  suppressWarnings({
    result <- parse_time_to_minutes(c("01:30", "invalid", "00:45", NA))
    expect_equal(result, c(90, NA_real_, 45, NA_real_))
  })
})

test_that("parse_time_to_minutes kan stadig parse numeriske strenge", {
  # Strenge der ser ud som numre (ingen ':' til HH:MM-parse)
  # behandles som numeric med input_unit
  expect_equal(parse_time_to_minutes("90", "time_minutes"), 90)
  expect_equal(parse_time_to_minutes("1.5", "time_hours"), 90)
})
```

- [ ] **Step 2: Kør tests fail**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-parsing.R')"`

Expected: FAIL — `"01:30"` konverterer til NA via as.numeric-fallback.

- [ ] **Step 3: Tilføj HH:MM-parsing i `R/utils_time_parsing.R` via `stringr::str_match()`**

Tilføj FØR numeric-checken (men efter difftime/hms checken):

```r
  # Character-input: proev HH:MM[:SS] parse foerst, fald tilbage til numeric
  if (is.character(x) || is.factor(x)) {
    x_char <- as.character(x)
    hhmm_result <- parse_hhmm_strings(x_char)

    # For vaerdier hvor HH:MM-parse fejler (NA), proev numeric-parse
    numeric_fallback <- suppressWarnings(as.numeric(x_char)) * scale
    result <- ifelse(is.na(hhmm_result), numeric_fallback, hhmm_result)
    return(result)
  }
```

Tilføj helper-funktionen efter `parse_time_to_minutes`:

```r
#' Parse HH:MM eller HH:MM:SS strenge til minutter
#'
#' Sekunder konverteres til broekdele af minutter (rundes ikke her —
#' det haandteres af format_time_composite() ved render-tid).
#' Ugyldige strenge returnerer NA.
#'
#' @param x Character vektor.
#' @return Numeric vektor med minutter.
#' @keywords internal
parse_hhmm_strings <- function(x) {
  # Regex: optional negative sign, timer (1-3 cifre), minutter (1-2 cifre),
  # valgfrit :SS hvor SS er 1-2 cifre.
  pattern <- "^(-?)(\\d{1,3}):(\\d{1,2})(?::(\\d{1,2}))?$"

  matches <- stringr::str_match(x, pattern)
  # matches er en matrix med kolonner: [full, sign, hours, mins, secs]
  n <- nrow(matches)
  result <- vapply(seq_len(n), function(i) {
    if (is.na(matches[i, 1])) {
      return(NA_real_)
    }
    sign <- if (identical(matches[i, 2], "-")) -1 else 1
    hours <- suppressWarnings(as.numeric(matches[i, 3]))
    mins <- suppressWarnings(as.numeric(matches[i, 4]))
    secs_str <- matches[i, 5]
    secs <- if (is.na(secs_str)) 0 else suppressWarnings(as.numeric(secs_str))
    if (any(is.na(c(hours, mins, secs)))) {
      return(NA_real_)
    }
    sign * (hours * 60 + mins + secs / 60)
  }, numeric(1))
  result
}
```

- [ ] **Step 4: Kør tests PASS**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-parsing.R')"`

Expected: PASS.

- [ ] **Step 5: Kør fuld test-suite**

Run: `'/usr/local/bin/Rscript' -e "devtools::test()"`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add R/utils_time_parsing.R tests/testthat/test-time-parsing.R
git commit -m "feat(time-axis): parse HH:MM og HH:MM:SS strenge til minutter

Karakter-input foerst parsed som HH:MM[:SS] via stringr::str_match,
fall-back til numeric med input_unit skalering. Sekunder beholder
praecision (konverteres til broeker af minutter); rounding til hele
minutter haandteres af format_time_composite() ved render."
```

---

## Task 2a.6: Udvid `Y_AXIS_UI_TYPES_DA` med 3 nye tids-enheder

**Files:**
- Modify: `R/config_spc_config.R:73-79`

- [ ] **Step 1: Opdater `Y_AXIS_UI_TYPES_DA` i `R/config_spc_config.R`**

Erstat hele listen (linje 73-79):

```r
#' UI-typer for Y-akse (simpel valg)
#'
#' Tids-enheder er eksplicit adskilt fra Fase 2 af
#' docs/superpowers/specs/2026-04-17-time-yaxis-design.md. Legacy "time"
#' er fjernet fra UI men accepteres stadig af is_time_unit() for
#' bagudkompatibilitet og migration.
#'
#' @keywords internal
Y_AXIS_UI_TYPES_DA <- list(
  "Tal"              = "count",
  "Procent (%)"      = "percent",
  "Rate"             = "rate",
  "Tid (minutter)"   = "time_minutes",
  "Tid (timer)"      = "time_hours",
  "Tid (dage)"       = "time_days"
)
```

- [ ] **Step 2: Kør alle tests for at fange consumers af den gamle label**

Run: `'/usr/local/bin/Rscript' -e "devtools::test()"`

Expected: Nogle tests kan fejle hvis de hardcoder `"Tid mellem hændelser"`. Fix ved at opdatere testene til at bruge en af de nye værdier — typisk `"time_minutes"` som default.

- [ ] **Step 3: Grep for referencer til den gamle label og opdater hvis fundet**

```bash
grep -rn "Tid mellem hændelser" R/ tests/
```

For hver forekomst: Hvis det er UI-label, opdater til en af de tre nye.

- [ ] **Step 4: Kør fuld test-suite igen**

Run: `'/usr/local/bin/Rscript' -e "devtools::test()"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/config_spc_config.R
git commit -m "feat(time-axis): udvid Y_AXIS_UI_TYPES_DA med 3 tids-enheder

Tilfoejer 'Tid (minutter)', 'Tid (timer)' og 'Tid (dage)' som
eksplicitte UI-valg. Legacy 'Tid mellem haendelser' fjernes fra
UI-listen; runtime-koden 'time' accepteres stadig af is_time_unit()
for bagudkompatibilitet. Migration af gemte sessions landes i Fase 2b."
```

**END FASE 2a.** Opret PR titlet `"feat(time-axis): parsing-lag og familie-klassifikation for tids-enheder"`.

---

# FASE 2b — UI, facade-integration og migration (PR 3)

## Task 2b.1: Tilføj `input_unit` til `time_breaks()` og `format_y_axis_time()`

**Files:**
- Modify: `R/utils_time_formatting.R`
- Modify: `R/utils_y_axis_formatting.R:48+` (dispatch + format_y_axis_time)
- Modify: `tests/testthat/test-time-formatting.R`

- [ ] **Step 1: Tilføj test for input_unit-filtrering**

Tilføj i `tests/testthat/test-time-formatting.R`:

```r
test_that("time_breaks filtrerer intervaller per input_unit", {
  # time_hours: 1m/2m/5m/10m/15m/20m kandidater skal skippes
  breaks_hours <- time_breaks(c(0, 300), input_unit = "time_hours")
  # Alle breaks skal vaere multipla af 30 (mindst 0.5 t)
  expect_true(all(breaks_hours %% 30 == 0))

  # time_days: foretraekker dage-intervaller (multipla af 720)
  breaks_days <- time_breaks(c(0, 14400), input_unit = "time_days")  # 0-10 dage
  expect_true(all(breaks_days %% 720 == 0))

  # time_minutes: alle kandidater tilgaengelige
  breaks_min <- time_breaks(c(0, 120), input_unit = "time_minutes")
  expect_equal(breaks_min, c(0, 30, 60, 90, 120))
})

test_that("time_breaks falder tilbage til ufiltreret liste hvis intet passer", {
  # Meget smal range i days-input kan kraeve fallback
  breaks <- time_breaks(c(0, 60), input_unit = "time_days")
  expect_true(length(breaks) > 0)
})

test_that("time_breaks uden input_unit er bagudkompatibel", {
  breaks <- time_breaks(c(0, 120))
  expect_equal(breaks, c(0, 30, 60, 90, 120))
})
```

- [ ] **Step 2: Kør test fail**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-formatting.R')"`

Expected: FAIL — `time_breaks` accepterer ikke `input_unit`.

- [ ] **Step 3: Udvid `time_breaks()` med `input_unit` parameter**

I `R/utils_time_formatting.R`, tilføj en konstant efter `TIME_BREAK_CANDIDATES`:

```r
#' Tilladte kandidat-intervaller pr. input-enhed
#'
#' Filtrerer TIME_BREAK_CANDIDATES baseret paa hvilke der er "naturlige"
#' i den valgte input-enhed. Fx time_hours tillader ikke 15m-intervaller
#' (= 0.25 t) men tillader 30m (= 0.5 t).
#'
#' @keywords internal
TIME_BREAK_CANDIDATES_BY_UNIT <- list(
  time_minutes = TIME_BREAK_CANDIDATES,
  time_hours   = c(30, 60, 120, 240, 360, 720, 1440, 2880, 10080, 43200),
  time_days    = c(720, 1440, 2880, 10080, 43200)
)
```

Opdater `time_breaks()`:

```r
time_breaks <- function(y_values, target_n = 5L, input_unit = NULL) {
  y_clean <- y_values[!is.na(y_values)]
  if (length(y_clean) == 0L) {
    return(numeric(0))
  }

  y_min <- min(y_clean)
  y_max <- max(y_clean)

  if (y_min == y_max) {
    return(y_min)
  }

  range_span <- y_max - y_min

  # Vaelg kandidat-liste baseret paa input_unit
  candidates <- if (!is.null(input_unit) &&
                    input_unit %in% names(TIME_BREAK_CANDIDATES_BY_UNIT)) {
    TIME_BREAK_CANDIDATES_BY_UNIT[[input_unit]]
  } else {
    TIME_BREAK_CANDIDATES
  }

  min_ticks <- max(3L, target_n - 2L)
  max_ticks <- target_n + 2L

  chosen_interval <- NULL
  for (interval in candidates) {
    n_ticks <- floor(range_span / interval) + 1L
    if (n_ticks >= min_ticks && n_ticks <= max_ticks) {
      chosen_interval <- interval
      break
    }
  }

  # Fallback: proev ufiltreret liste hvis filtreret ikke passer
  if (is.null(chosen_interval) && !identical(candidates, TIME_BREAK_CANDIDATES)) {
    log_info(
      paste0(
        "time_breaks: ingen kandidat fra input_unit='", input_unit,
        "' passer til range [", y_min, ", ", y_max, "] — falder tilbage til ufiltreret"
      ),
      .context = "Y_AXIS_FORMAT"
    )
    for (interval in TIME_BREAK_CANDIDATES) {
      n_ticks <- floor(range_span / interval) + 1L
      if (n_ticks >= min_ticks && n_ticks <= max_ticks) {
        chosen_interval <- interval
        break
      }
    }
  }

  # Sidste fallback: vaelg taettest paa target_n
  if (is.null(chosen_interval)) {
    diffs <- abs(floor(range_span / TIME_BREAK_CANDIDATES) + 1L - target_n)
    chosen_interval <- TIME_BREAK_CANDIDATES[which.min(diffs)]
  }

  start <- floor(y_min / chosen_interval) * chosen_interval
  end <- ceiling(y_max / chosen_interval) * chosen_interval

  seq(start, end, by = chosen_interval)
}
```

- [ ] **Step 4: Opdater `format_y_axis_time()` til at videregive input_unit**

I `R/utils_y_axis_formatting.R`, udvid signaturen:

```r
format_y_axis_time <- function(qic_data, input_unit = NULL) {
  if (is.null(qic_data) || !"y" %in% names(qic_data)) {
    log_warn(
      "format_y_axis_time: missing qic_data or y column, using default formatting",
      .context = "Y_AXIS_FORMAT"
    )
    return(ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(.25, .25))))
  }

  y_values <- qic_data$y
  breaks <- time_breaks(y_values, input_unit = input_unit)

  ggplot2::scale_y_continuous(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    breaks = breaks,
    labels = function(x) {
      if (inherits(x, "waiver")) {
        return(x)
      }
      if (!is.numeric(x)) {
        x <- suppressWarnings(as.numeric(as.character(x)))
      }
      format_time_composite(x)
    }
  )
}
```

Opdater også dispatch-funktionen `apply_y_axis_formatting()`. Find linje 67-69 (time-grenen):

```r
  } else if (is_time_unit(y_axis_unit)) {
    return(plot + format_y_axis_time(qic_data, input_unit = y_axis_unit))
  }
```

Bemærk: dispatch skal også fange de nye `time_*`-enheder via `is_time_unit()`.

- [ ] **Step 5: Kør tests PASS**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-time-formatting.R'); testthat::test_file('tests/testthat/test-y-axis-formatting.R')"`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add R/utils_time_formatting.R R/utils_y_axis_formatting.R tests/testthat/test-time-formatting.R
git commit -m "feat(time-axis): filtrér tick-intervaller per input_unit

time_hours skipper 1m/15m/20m kandidater (ikke hele eller halve timer);
time_days skipper alle intervaller under 12t. Fallback til ufiltreret
liste med log-besked hvis filtreret ikke giver 3-7 ticks.
apply_y_axis_formatting dispatcher via is_time_unit() for alle tids-enheder."
```

---

## Task 2b.2: Opdater `format_y_value()` for nye tids-enheder

**Files:**
- Modify: `R/utils_label_formatting.R:97`
- Modify: `tests/testthat/test-label-formatting.R`

- [ ] **Step 1: Tilføj tests for nye tids-enheder**

Tilføj i `tests/testthat/test-label-formatting.R`:

```r
test_that("format_y_value haandterer nye tids-enheder (time_minutes/hours/days)", {
  # Alle tids-enheder giver komposit-format fordi input allerede er
  # konverteret til kanoniske minutter af parse_time_to_minutes.
  expect_equal(format_y_value(90, "time_minutes"), "1t 30m")
  expect_equal(format_y_value(90, "time_hours"), "1t 30m")
  expect_equal(format_y_value(90, "time_days"), "1t 30m")
  expect_equal(format_y_value(1440, "time_days"), "1d")
})
```

- [ ] **Step 2: Kør test fail**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-label-formatting.R')"`

Expected: FAIL hvis time-grenen kun tjekker `y_unit == "time"`.

- [ ] **Step 3: Opdater time-grenen i `R/utils_label_formatting.R`**

Find linje 97 (`if (y_unit == "time") {`) og erstat med:

```r
  # Time formatting (input: kanoniske minutter) - komposit-format
  # Daekker legacy "time" og de nye enheder time_minutes/time_hours/time_days.
  if (is_time_unit(y_unit)) {
    return(format_time_composite(val))
  }
```

- [ ] **Step 4: Kør tests PASS**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-label-formatting.R')"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/utils_label_formatting.R tests/testthat/test-label-formatting.R
git commit -m "feat(time-axis): format_y_value accepterer nye time_* enheder

Dispatcher via is_time_unit() saa legacy 'time' og nye
time_minutes/time_hours/time_days alle giver komposit-format."
```

---

## Task 2b.3: Integrér `parse_time_to_minutes()` i facade-pipeline

**Files:**
- Modify: `R/fct_spc_bfh_facade.R` (omkring linje 192 / 417 / 491 hvor `y_axis_unit` bruges)

- [ ] **Step 1: Identificér indlæsnings-stedet i `fct_spc_bfh_facade.R`**

```bash
grep -n "y_axis_unit\|y_var\|y_data\|data\\[\\[" R/fct_spc_bfh_facade.R | head -40
```

Find stedet hvor y-kolonnen udtrækkes fra `data` før den sendes videre til BFHcharts. Typisk i `prepare_spc_data()` eller direkte i hovedfunktionen.

- [ ] **Step 2: Tilføj parse-step på det identificerede sted**

Lige efter y-kolonnen udtrækkes (fx `y_data <- data[[y_var]]`), indsæt:

```r
  # Parse tids-input til kanoniske minutter hvis y-enheden er en tids-enhed.
  # Input kan vaere numeric, hms, difftime eller HH:MM-streng.
  if (is_time_unit(y_axis_unit)) {
    y_data <- parse_time_to_minutes(y_data, input_unit = y_axis_unit)
    data[[y_var]] <- y_data
    log_debug(
      paste0("Parsede tids-kolonne '", y_var,
             "' til kanoniske minutter via input_unit='", y_axis_unit, "'"),
      .context = "Y_AXIS_SCALING"
    )
  }
```

BEMÆRK: Eksakt placering afhænger af flowet. Step 1 er nødvendig før step 2 kan udføres korrekt. Princip: parsing skal ske **én gang**, så tidligt som muligt, **før** data går videre til BFHcharts eller qicharts2.

- [ ] **Step 3: Skriv en integrationstest**

Opret `tests/testthat/test-facade-time-parsing.R`:

```r
library(testthat)

test_that("facade-integration: time_hours input skaleres til minutter", {
  skip_if_not_installed("BFHcharts")
  data <- data.frame(
    dato = seq(as.Date("2024-01-01"), by = "day", length.out = 10),
    varighed = c(1, 1.5, 2, 2.5, 1, 1.5, 2, 3, 2, 1.5)
  )

  parsed <- parse_time_to_minutes(data$varighed, input_unit = "time_hours")
  expect_equal(parsed, data$varighed * 60)
})
```

- [ ] **Step 4: Kør tests**

Run: `'/usr/local/bin/Rscript' -e "devtools::test()"`

Expected: PASS. Hvis eksisterende facade-tests fejler pga. ændret data-flow, debug via `log_debug` og juster placering.

- [ ] **Step 5: Commit**

```bash
git add R/fct_spc_bfh_facade.R tests/testthat/test-facade-time-parsing.R
git commit -m "feat(time-axis): integrér parse_time_to_minutes i facade-pipeline

Parsing sker én gang, tidligt, naar y-enheden er en tids-enhed.
Nedstroem (BFHcharts, qicharts2, format_y_axis_time) arbejder
altid i kanoniske minutter."
```

---

## Task 2b.4: Bump schema-version og implementér silent forward-migration

**Files:**
- Modify: `R/utils_local_storage.R:8` (schema-version + ny migration-funktion)
- Modify: `R/utils_server_server_management.R` (integrér migration i peek + restore)
- Create: `tests/testthat/test-local-storage-time-migration.R`

- [ ] **Step 1: Opret failing test for migration**

```r
# test-local-storage-time-migration.R
library(testthat)

test_that("migrate_time_yaxis_unit konverterer legacy 'time' til 'time_minutes'", {
  saved_state <- list(
    version = "2.0",
    metadata = list(
      y_axis_unit = "time",
      chart_type = "t",
      title = "Test"
    )
  )
  migrated <- migrate_time_yaxis_unit(saved_state)
  expect_equal(migrated$metadata$y_axis_unit, "time_minutes")
  expect_equal(migrated$version, "3.0")
})

test_that("migrate_time_yaxis_unit lader ikke-time enheder vaere i fred", {
  saved_state <- list(
    version = "2.0",
    metadata = list(y_axis_unit = "count", chart_type = "p")
  )
  migrated <- migrate_time_yaxis_unit(saved_state)
  expect_equal(migrated$metadata$y_axis_unit, "count")
  expect_equal(migrated$version, "3.0")
})

test_that("migrate_time_yaxis_unit er idempotent for 3.0 payloads", {
  saved_state <- list(
    version = "3.0",
    metadata = list(y_axis_unit = "time_hours")
  )
  migrated <- migrate_time_yaxis_unit(saved_state)
  expect_equal(migrated$metadata$y_axis_unit, "time_hours")
  expect_equal(migrated$version, "3.0")
})

test_that("migrate_time_yaxis_unit haandterer manglende metadata graciously", {
  saved_state <- list(version = "2.0", data = list(nrows = 10))
  migrated <- migrate_time_yaxis_unit(saved_state)
  expect_equal(migrated$version, "3.0")
})
```

- [ ] **Step 2: Kør test fail**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-local-storage-time-migration.R')"`

Expected: FAIL — `migrate_time_yaxis_unit` findes ikke.

- [ ] **Step 3: Bump schema-version i `R/utils_local_storage.R`**

Erstat linje 8:

```r
LOCAL_STORAGE_SCHEMA_VERSION <- "3.0"
```

- [ ] **Step 4: Tilføj `migrate_time_yaxis_unit()` i `R/utils_local_storage.R`**

Tilføj lige under `LOCAL_STORAGE_SCHEMA_VERSION`:

```r
# MIGRATION ==================================================================

#' Silent forward-migration: "time" → "time_minutes"
#'
#' Version 2.0 payloads har y_axis_unit = "time" med implicit antagelse
#' om minutter. Version 3.0 kraever eksplicit time_minutes/time_hours/time_days.
#' Migrationen bevarer klinisk data ved at mappe den implicitte antagelse.
#'
#' @param saved_state List med 'version' og 'metadata'.
#' @return Opdateret list med version = LOCAL_STORAGE_SCHEMA_VERSION.
#' @keywords internal
migrate_time_yaxis_unit <- function(saved_state) {
  if (is.null(saved_state)) {
    return(saved_state)
  }

  src_version <- saved_state$version %||% "unknown"

  # Kun migrér 2.0 → 3.0. Nyere versioner returneres uaendret.
  if (identical(src_version, "2.0")) {
    if (!is.null(saved_state$metadata) &&
        !is.null(saved_state$metadata$y_axis_unit) &&
        identical(saved_state$metadata$y_axis_unit, "time")) {
      saved_state$metadata$y_axis_unit <- "time_minutes"
    }
    saved_state$version <- LOCAL_STORAGE_SCHEMA_VERSION
  }

  saved_state
}
```

- [ ] **Step 5: Kør migration-testen PASS**

Run: `'/usr/local/bin/Rscript' -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-local-storage-time-migration.R')"`

Expected: PASS.

- [ ] **Step 6: Integrér migration i peek + restore flows i `R/utils_server_server_management.R`**

Find `saved_version <- peek$version %||% "unknown"` på linje ~51. INDSÆT lige FØR version-checket:

```r
      # Silent forward-migration 2.0 → 3.0 (time → time_minutes)
      peek <- migrate_time_yaxis_unit(peek)
      saved_version <- peek$version %||% "unknown"
```

Gentag samme pattern i restore-flowet (omkring linje 112):

```r
      saved_state <- migrate_time_yaxis_unit(saved_state)
      saved_version <- saved_state$version %||% "unknown"
```

- [ ] **Step 7: Kør fuld test-suite**

Run: `'/usr/local/bin/Rscript' -e "devtools::test()"`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add R/utils_local_storage.R R/utils_server_server_management.R tests/testthat/test-local-storage-time-migration.R
git commit -m "feat(time-axis): silent forward-migration 2.0 til 3.0 for y_axis_unit

Bumper LOCAL_STORAGE_SCHEMA_VERSION til 3.0. Gamle sessions med
y_axis_unit='time' migreres automatisk til 'time_minutes' (matcher
den implicitte antagelse om minutter). Migration koerer FOER
version-checket i peek og restore observers."
```

---

## Task 2b.5: Migration af `pins`-baserede sessions

**Files:**
- Modify: `R/utils_analytics_pins.R`
- Modify: `tests/testthat/test-local-storage-time-migration.R`

- [ ] **Step 1: Grep for hvor pins indlæses**

```bash
grep -n "pin_read\|load.*pin\|from_pin" R/utils_analytics_pins.R
```

Identificér indlæsnings-funktionen.

- [ ] **Step 2: Tilføj test i `tests/testthat/test-local-storage-time-migration.R`**

```r
test_that("pins-indlaesning kan genbruge migrate_time_yaxis_unit", {
  # Direkte migration er allerede daekket. Denne test verificerer kun at
  # funktionen er tilgaengelig for pins-koden.
  mock_pin <- list(version = "2.0", metadata = list(y_axis_unit = "time"))
  migrated <- migrate_time_yaxis_unit(mock_pin)
  expect_equal(migrated$metadata$y_axis_unit, "time_minutes")
})
```

- [ ] **Step 3: Tilføj migration-kaldet i `R/utils_analytics_pins.R`**

På indlæsnings-stedet (fundet i step 1), tilføj efter pin-læsningen:

```r
  loaded_state <- migrate_time_yaxis_unit(loaded_state)
```

- [ ] **Step 4: Kør tests**

Run: `'/usr/local/bin/Rscript' -e "devtools::test()"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/utils_analytics_pins.R tests/testthat/test-local-storage-time-migration.R
git commit -m "feat(time-axis): anvend time-yaxis migration ved pins-indlaesning

Samme silent forward-migration som localStorage: v2.0 pins med
y_axis_unit='time' mappes til 'time_minutes'."
```

---

## Task 2b.6: Verificér UI-default for t-kort og auto-detect

**Files:** Ingen kode-ændringer forventet (allerede håndteret i Fase 2a). Ren verifikation.

- [ ] **Step 1: Identificér konsumenter af `chart_type_to_ui_type` og `default_time_unit_for_chart`**

```bash
grep -rn "chart_type_to_ui_type\|default_time_unit_for_chart\|decide_default_y_axis_ui_type" R/
```

Verificér at alle kaldsteder bruger den nye adfærd.

- [ ] **Step 2: Tilføj integration-test**

Tilføj i `tests/testthat/test-y-axis-model.R`:

```r
test_that("t-kort: korttype-skift saetter time_days som default y-enhed", {
  expect_equal(chart_type_to_ui_type("t"), "time_days")
  expect_equal(default_time_unit_for_chart("t"), "time_days")
})
```

- [ ] **Step 3: Verificér via manuel test**

Start appen, upload data, skift korttype til t-kort. Y-enhed-dropdown skal auto-vælge `"Tid (dage)"`.

- [ ] **Step 4: Commit hvis ændringer nødvendige; ellers spring over**

Hvis en downstream-konsument stadig hardcoder `"time"` → opdater og commit:

```bash
git add R/<path-to-fix> tests/testthat/test-<relevant>.R
git commit -m "fix(time-axis): t-kort auto-vaelger time_days som default y-enhed"
```

---

## Task 2b.7: End-to-end integrationstest og røgtest

**Files:** Ingen kode-ændringer. Ren verifikation.

- [ ] **Step 1: Kør fuld test-suite**

Run: `'/usr/local/bin/Rscript' -e "devtools::test()"`

Expected: PASS, 0 fejl.

- [ ] **Step 2: Kør `devtools::check()` for NAMESPACE/dokumentations-issues**

Run: `'/usr/local/bin/Rscript' -e "devtools::check(args = '--no-manual')"`

Expected: 0 errors, 0 warnings. Notes OK hvis dokumenterede.

- [ ] **Step 3: Kør appen manuelt og test UI-flow**

Scenarier:
- Upload data med y-værdier i minutter → vælg `Tid (minutter)` → verificér komposit-labels
- Skift y-enhed til `Tid (timer)` — data-værdier tolkes nu som timer, aksen skalerer korrekt
- Upload CSV med HH:MM-strenge i y-kolonnen → vælg `Tid (minutter)` → HH:MM auto-parses
- Skift korttype til t-kort → y-enhed skifter til `Tid (dage)`
- Gendan en gammel gemt session fra localStorage med legacy `y_axis_unit = "time"` → session åbner uden fejl, enheden vises som `Tid (minutter)`

- [ ] **Step 4: Hvis alle scenarier passer — ingen commit. Åbn PR.**

**END FASE 2b.** Opret PR titlet `"feat(time-axis): nye tids-enheder, parsing og silent migration"`.

---

# Rollback-plan

Hvis noget går galt i production efter PR 3:

1. **Revert PR 3** → UI går tilbage til single `"Tid mellem hændelser"`-valg. `LOCAL_STORAGE_SCHEMA_VERSION` skal manuelt resættes til `"2.0"` i kodebasen, eller brugere får én ny hard-reset af localStorage (tabt data).
2. **Behold PR 1 og PR 2** → komposit-format og parsing-laget er selvstændige forbedringer; de bryder ikke backwards compatibility.

For at mindske rollback-smerten: **deploy PR 1 separat fra PR 2 og PR 3**, og vent 1-2 dage mellem hver release for at fange edge cases.

---

# Self-Review Notes

- **Spec coverage:** Hvert af de 4 prioritetsproblemer (P1-P4) har explicit task-dækning:
  - P1 (ugly ticks): Task 1.3 (`time_breaks`) + Task 1.4 (integration) + Task 2b.1 (per-enhed filter)
  - P2 (forvirrende enhedsvalg): Task 2a.6 (nye enheder) + Task 2b.1 (tick-filtrering pr. enhed)
  - P3 (rounding): Task 1.1, 1.2, 1.5 (komposit-format eliminerer sub-minut decimaler og overflow)
  - P4 (input-enhed): Task 2a.6 (dropdown), 2a.3-2a.5 (parsing), 2b.3 (facade-integration)
- **Scope check:** Tre distincte PR'er, hver lander selvstændigt. PR 1 = output-refaktor. PR 2 = infrastruktur uden UI-ændring. PR 3 = UI+migration som én atomisk deploy.
- **Åbne spørgsmål fra spec-doc:**
  - Task 2b.3 pinpointer parsing-placering i `fct_spc_bfh_facade.R` — eksakt linje afklares ved implementation (Step 1 først, Step 2 bagefter).
  - `Y_AXIS_UNITS_DA`-extension er ikke strengt nødvendig i scope; kan håndteres ad-hoc hvis downstream consumers kræver mapping.
- **Risici håndteret:** Task 1.4 advarer om at `format_time_with_unit`-fjernelse kan fange consumers andetsteds — Step 5 dækker via grep.
- **Type/signatur-konsistens:** `time_breaks(y_values, target_n, input_unit)` og `format_y_axis_time(qic_data, input_unit)` er de to tilføjede parametre. `format_time_composite(minutes)` er uændret på tværs af alle tasks. `parse_time_to_minutes(x, input_unit)` er signaturen overalt.
- **Bagudkompatibilitet verificeret:** Fase 1 PR introducerer ingen API-brud. Fase 2a tilføjer kun ny funktionalitet. Fase 2b bryder localStorage-schema men har silent migration.
