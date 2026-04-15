# biSPCharts Analytics Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Opret et Quarto Dashboard der visualiserer biSPCharts brugsdata fra shinylogs, med to faner (Overblik for ledelse, Teknisk for udvikler).

**Architecture:** Dashboardet laeser aggregerede log-data via `pins::pin_read()` fra Connect Cloud, beregner KPI'er og genererer ggplot2-grafer. Foerst udvides biSPCharts' pin-publicering til at inkludere alle 4 shinylogs-kategorier, derefter oprettes et nyt Quarto Dashboard repository.

**Tech Stack:** Quarto (format: dashboard), bslib, pins, ggplot2, dplyr, tidyr, lubridate, BFHtheme, scales.

**Design spec:** `docs/superpowers/specs/2026-04-16-analytics-dashboard-design.md`

---

## File Structure

### Del A: AEndringer i biSPCharts (eksisterende repo)

| Fil | AEndring |
|-----|---------|
| `R/utils_analytics_pins.R` | Ny funktion `read_shinylogs_all()`, opdater `aggregate_and_pin_logs()` |
| `R/utils_shinylogs_config.R` | Fjern analytics_client_metadata og analytics_performance fra exclude_input_regex |
| `tests/testthat/test-utils_analytics_pins.R` | Nye tests for `read_shinylogs_all()` |
| `manifest.json` | Regenerer |

### Del B: Nyt repository (biSPCharts-analytics)

| Fil | Ansvar |
|-----|--------|
| `_quarto.yml` | Quarto dashboard konfiguration, BFH tema |
| `index.qmd` | Hoveddokument med to faner |
| `R/data_load.R` | pin_read() + data-forberedelse + fallback ved manglende data |
| `R/kpi_calculations.R` | KPI-beregninger (sessions, unikke, completion, trend) |
| `R/plot_overview.R` | ggplot2 grafer til Overblik-fane (3 grafer) |
| `R/plot_technical.R` | ggplot2 grafer til Teknisk-fane (7 grafer) |
| `renv.lock` | Reproducerbart miljo |
| `.Renviron.example` | Template for env vars |
| `CLAUDE.md` | Projektinstruktioner |
| `manifest.json` | Connect Cloud deploy |

---

## Del A: AEndringer i biSPCharts

### Task 1: Udvid pin-data med alle shinylogs-kategorier

**Files:**
- Modify: `R/utils_analytics_pins.R`
- Modify: `tests/testthat/test-utils_analytics_pins.R`

- [ ] **Step 1: Skriv test for read_shinylogs_all()**

```r
# Tilfoej til tests/testthat/test-utils_analytics_pins.R

test_that("read_shinylogs_all() returnerer liste med 4 data.frames", {
  tmp_dir <- withr::local_tempdir()

  # Opret alle 4 undermapper
  for (subdir in c("sessions", "inputs", "outputs", "errors")) {
    dir.create(file.path(tmp_dir, subdir), recursive = TRUE)
  }

  # Skriv test-data i hver
  jsonlite::write_json(
    list(app = "SPC", server_connected = "2026-04-15T10:00:00Z",
         server_disconnected = "2026-04-15T10:15:00Z", session_duration = 900),
    file.path(tmp_dir, "sessions", "session_test.json")
  )
  jsonlite::write_json(
    list(session = "abc", name = "chart_type", value = "run",
         timestamp = "2026-04-15T10:05:00Z"),
    file.path(tmp_dir, "inputs", "input_test.json")
  )
  jsonlite::write_json(
    list(session = "abc", name = "spc_plot", timestamp = "2026-04-15T10:06:00Z"),
    file.path(tmp_dir, "outputs", "output_test.json")
  )
  jsonlite::write_json(
    list(session = "abc", name = "render_error", error = "Missing column",
         timestamp = "2026-04-15T10:07:00Z"),
    file.path(tmp_dir, "errors", "error_test.json")
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

test_that("read_shinylogs_all() haandterer tomme mapper", {
  tmp_dir <- withr::local_tempdir()
  result <- read_shinylogs_all(tmp_dir)

  expect_true(is.list(result))
  expect_equal(nrow(result$sessions), 0)
  expect_equal(nrow(result$inputs), 0)
  expect_equal(nrow(result$outputs), 0)
  expect_equal(nrow(result$errors), 0)
})
```

- [ ] **Step 2: Koer test — verificer at den fejler**

Run: `Rscript -e "devtools::load_all(); testthat::test_file('tests/testthat/test-utils_analytics_pins.R')"`
Expected: FAIL — `read_shinylogs_all` ikke fundet

- [ ] **Step 3: Implementer read_shinylogs_all()**

Tilfoej i `R/utils_analytics_pins.R` (efter `read_shinylogs_sessions()`):

```r
#' Laes alle shinylogs kategorier til navngivet liste
#'
#' Laeser sessions, inputs, outputs og errors fra shinylogs log-directory.
#'
#' @param log_directory Sti til log-mappe
#' @return Navngivet liste med 4 data.frames: sessions, inputs, outputs, errors
#' @export
read_shinylogs_all <- function(log_directory) {
  categories <- c("sessions", "inputs", "outputs", "errors")

  result <- lapply(stats::setNames(categories, categories), function(cat) {
    cat_dir <- file.path(log_directory, cat)
    if (!dir.exists(cat_dir)) return(data.frame())

    files <- list.files(cat_dir, pattern = "\\.json$", full.names = TRUE)
    if (length(files) == 0) return(data.frame())

    entries <- lapply(files, function(f) {
      tryCatch(
        jsonlite::fromJSON(f, simplifyVector = TRUE),
        error = function(e) {
          log_warn(paste("Kunne ikke laese", cat, "fil:", basename(f)),
                   .context = LOG_CONTEXTS$analytics$pins)
          NULL
        }
      )
    })

    entries <- Filter(Negate(is.null), entries)
    if (length(entries) == 0) return(data.frame())

    tryCatch(
      dplyr::bind_rows(entries),
      error = function(e) {
        log_warn(paste("bind_rows fejlede for", cat, ":", e$message),
                 .context = LOG_CONTEXTS$analytics$pins)
        data.frame()
      }
    )
  })

  result
}
```

- [ ] **Step 4: Opdater aggregate_and_pin_logs() til at bruge read_shinylogs_all()**

Erstat indholdet af `aggregate_and_pin_logs()` i `R/utils_analytics_pins.R`:

```r
#' Aggreger logs og publicer til Connect Cloud via pins
#'
#' Laeser alle shinylogs-kategorier og publicerer som navngivet liste via pins.
#'
#' @param log_directory Sti til log-mappe
#' @export
aggregate_and_pin_logs <- function(log_directory = "logs/") {
  config <- get_analytics_config()
  all_data <- read_shinylogs_all(log_directory)

  # Tjek om der er data overhovedet
  total_rows <- sum(vapply(all_data, nrow, integer(1)))
  if (total_rows == 0) {
    log_debug("Ingen data at aggregere",
              .context = LOG_CONTEXTS$analytics$pins)
    return(invisible(NULL))
  }

  safe_operation(
    "Pin analytics data",
    code = {
      if (requireNamespace("pins", quietly = TRUE) && nchar(Sys.getenv("CONNECT_SERVER")) > 0) {
        board <- pins::board_connect()
        pins::pin_write(board, all_data, config$pin_name,
                        type = "rds",
                        description = paste(
                          "biSPCharts analytics:",
                          nrow(all_data$sessions), "sessions,",
                          nrow(all_data$inputs), "inputs,",
                          nrow(all_data$errors), "errors"
                        ))
        log_info(paste("Analytics pin opdateret:",
                       nrow(all_data$sessions), "sessions,",
                       nrow(all_data$inputs), "inputs"),
                 .context = LOG_CONTEXTS$analytics$pins)
      } else {
        log_debug("Pins ikke tilgaengelig (ikke paa Connect Cloud)",
                  .context = LOG_CONTEXTS$analytics$pins)
      }
    },
    fallback = function(e) {
      log_warn(paste("Pin publicering fejlede:", e$message),
               .context = LOG_CONTEXTS$analytics$pins)
    },
    error_type = "processing"
  )

  rotate_log_files(log_directory)
  invisible(NULL)
}
```

- [ ] **Step 5: Koer tests — verificer at alle bestaar**

Run: `Rscript -e "devtools::load_all(); testthat::test_file('tests/testthat/test-utils_analytics_pins.R')"`
Expected: PASS (alle tests inkl. eksisterende)

- [ ] **Step 6: Commit**

```bash
git add R/utils_analytics_pins.R tests/testthat/test-utils_analytics_pins.R
git commit -m "feat(analytics): udvid pin-data med alle shinylogs-kategorier (sessions, inputs, outputs, errors)"
```

---

### Task 2: Fjern input-filtre for analytics metadata

**Files:**
- Modify: `R/utils_shinylogs_config.R` (linje 88-93)

- [ ] **Step 1: Opdater exclude_input_regex**

I `R/utils_shinylogs_config.R`, erstat den eksisterende `exclude_input_regex`:

```r
    # NUVAERENDE (fjern):
    exclude_input_regex = paste0(
      "^(\\.clientdata|",         # Shiny interne clientdata inputs
      "analytics_consent|",       # Analytics-egne consent inputs
      "analytics_client_metadata|", # Analytics metadata
      "analytics_performance)"    # Analytics performance timing
    ),

    # NY (erstat med):
    exclude_input_regex = paste0(
      "^(\\.clientdata|",         # Shiny interne clientdata inputs
      "analytics_consent)"        # Analytics consent input (ikke data)
    ),
```

Bemaerk: `analytics_client_metadata` og `analytics_performance` er fjernet fra exclude-listen saa shinylogs fanger dem som inputs. `analytics_consent` forbliver ekskluderet da det kun er et boolean consent-signal.

- [ ] **Step 2: Koer eksisterende tests**

Run: `Rscript -e "devtools::load_all(); testthat::test_dir('tests/testthat')"`
Expected: Alle tests bestaar (ingen regression)

- [ ] **Step 3: Commit**

```bash
git add R/utils_shinylogs_config.R
git commit -m "feat(analytics): tillad shinylogs at fange client metadata og performance timing"
```

---

### Task 3: Opdater NAMESPACE, manifest og push biSPCharts

**Files:**
- Modify: `NAMESPACE` (via devtools::document())
- Modify: `manifest.json` (via rsconnect::writeManifest())

- [ ] **Step 1: Opdater NAMESPACE**

Run: `Rscript -e "devtools::document()"`

- [ ] **Step 2: Opdater manifest**

Run: `Rscript -e "rsconnect::writeManifest()"`

- [ ] **Step 3: Koer fuld test-suite**

Run: `Rscript -e "devtools::load_all(); testthat::test_dir('tests/testthat')"`
Expected: Alle tests bestaar

- [ ] **Step 4: Commit og push**

```bash
git add NAMESPACE manifest.json man/
git commit -m "chore: opdater NAMESPACE og manifest for analytics pin-udvidelse"
git push origin master
```

---

## Del B: Nyt Quarto Dashboard Repository

### Task 4: Opret GitHub repository og projektstruktur

- [ ] **Step 1: Opret repository paa GitHub**

Run: `gh repo create johanreventlow/biSPCharts-analytics --public --description "Analytics dashboard for biSPCharts brugsstatistik" --clone`

- [ ] **Step 2: Opret mappestruktur**

```bash
cd biSPCharts-analytics
mkdir -p R
```

- [ ] **Step 3: Opret .gitignore**

```
# R
.Rproj.user
.Rhistory
.RData
.Renviron
renv/library/
renv/staging/

# Quarto
_site/
.quarto/

# OS
.DS_Store

# Superpowers
.superpowers/
```

- [ ] **Step 4: Opret .Renviron.example**

```
# Posit Connect Cloud credentials
# Kopiér til .Renviron og udfyld med rigtige vaerdier
CONNECT_SERVER=https://your-connect-cloud-url.posit.cloud
CONNECT_API_KEY=your-api-key-here
```

- [ ] **Step 5: Opret CLAUDE.md**

```markdown
# Claude Instructions — biSPCharts Analytics

## Project Overview

- **Project Type:** Quarto Dashboard
- **Purpose:** Visualisering af biSPCharts brugsstatistik fra shinylogs
- **Deploy:** Posit Connect Cloud, daglig scheduled rendering
- **Sprog:** Dansk

## Tech Stack

- Quarto (format: dashboard)
- bslib (layout, value boxes)
- pins (laes data fra Connect Cloud)
- ggplot2, dplyr, tidyr, lubridate, scales
- BFHtheme (hospital-branding)

## Data

Data laeser fra pin "spc-analytics-logs" via pins::pin_read().
Pin indeholder en liste med 4 data.frames: sessions, inputs, outputs, errors.

## Render

quarto render index.qmd
```

- [ ] **Step 6: Initialiser renv**

Run: `Rscript -e "renv::init(bare = TRUE)"`

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: initialiser biSPCharts-analytics projekt"
```

---

### Task 5: Quarto konfiguration

**Files:**
- Create: `_quarto.yml`

- [ ] **Step 1: Opret _quarto.yml**

```yaml
project:
  type: website

format:
  dashboard:
    theme: cosmo
    nav-buttons:
      - icon: github
        href: https://github.com/johanreventlow/biSPCharts-analytics
    orientation: rows

website:
  title: "biSPCharts Analytics"

execute:
  echo: false
  warning: false
  message: false
```

- [ ] **Step 2: Verificer at quarto genkender projektet**

Run: `quarto check`
Expected: Quarto version og projekt type rapporteret

- [ ] **Step 3: Commit**

```bash
git add _quarto.yml
git commit -m "feat: tilfoej Quarto dashboard konfiguration"
```

---

### Task 6: Data-lag (R/data_load.R)

**Files:**
- Create: `R/data_load.R`

- [ ] **Step 1: Opret data_load.R**

```r
# R/data_load.R
# Indlaes analytics-data fra Connect Cloud pin

#' Indlaes analytics-data fra pin
#'
#' Laeser "spc-analytics-logs" pin fra Connect Cloud.
#' Returnerer tom default-struktur hvis pin ikke er tilgaengelig.
#'
#' @return Navngivet liste med sessions, inputs, outputs, errors data.frames
load_analytics_data <- function() {
  default_data <- list(
    sessions = data.frame(),
    inputs = data.frame(),
    outputs = data.frame(),
    errors = data.frame()
  )

  tryCatch({
    if (nchar(Sys.getenv("CONNECT_SERVER")) == 0) {
      message("CONNECT_SERVER ikke sat — bruger tom data")
      return(default_data)
    }

    board <- pins::board_connect()
    pin_data <- pins::pin_read(board, "spc-analytics-logs")

    # Valider struktur
    if (!is.list(pin_data)) return(default_data)

    # Sikr at alle 4 kategorier er til stede
    for (cat in c("sessions", "inputs", "outputs", "errors")) {
      if (is.null(pin_data[[cat]])) {
        pin_data[[cat]] <- data.frame()
      }
    }

    pin_data
  }, error = function(e) {
    message(paste("Kunne ikke laese analytics pin:", e$message))
    default_data
  })
}

#' Udtrak client metadata fra inputs
#'
#' Filtrerer analytics_client_metadata inputs og parser til data.frame.
#'
#' @param inputs data.frame med alle inputs fra shinylogs
#' @return data.frame med client metadata (visitor_id, browser, os, screen, etc.)
extract_client_metadata <- function(inputs) {
  if (nrow(inputs) == 0) return(data.frame())

  meta_inputs <- inputs[grepl("analytics_client_metadata", inputs$name, fixed = TRUE), ]
  if (nrow(meta_inputs) == 0) return(data.frame())

  # Parse value-kolonne (JSON-string fra shinylogs)
  parsed <- lapply(meta_inputs$value, function(v) {
    tryCatch(jsonlite::fromJSON(v), error = function(e) NULL)
  })
  parsed <- Filter(Negate(is.null), parsed)
  if (length(parsed) == 0) return(data.frame())

  dplyr::bind_rows(parsed)
}

#' Udtrak performance metrics fra inputs
#'
#' Filtrerer analytics_performance inputs og parser til data.frame.
#'
#' @param inputs data.frame med alle inputs fra shinylogs
#' @return data.frame med performance metrics (type, duration_ms, etc.)
extract_performance_metrics <- function(inputs) {
  if (nrow(inputs) == 0) return(data.frame())

  perf_inputs <- inputs[grepl("analytics_performance", inputs$name, fixed = TRUE), ]
  if (nrow(perf_inputs) == 0) return(data.frame())

  parsed <- lapply(perf_inputs$value, function(v) {
    tryCatch(jsonlite::fromJSON(v), error = function(e) NULL)
  })
  parsed <- Filter(Negate(is.null), parsed)
  if (length(parsed) == 0) return(data.frame())

  dplyr::bind_rows(parsed)
}
```

- [ ] **Step 2: Commit**

```bash
git add R/data_load.R
git commit -m "feat: tilfoej data-lag med pin_read og metadata-extraction"
```

---

### Task 7: KPI-beregninger (R/kpi_calculations.R)

**Files:**
- Create: `R/kpi_calculations.R`

- [ ] **Step 1: Opret kpi_calculations.R**

```r
# R/kpi_calculations.R
# KPI-beregninger for analytics dashboard

#' Beregn alle KPI'er for Overblik-fane
#'
#' @param sessions data.frame med sessions
#' @param inputs data.frame med inputs
#' @param client_meta data.frame med client metadata
#' @param days Antal dage at kigge tilbage (default 7)
#' @return Navngivet liste med KPI-vaerdier
calculate_overview_kpis <- function(sessions, inputs, client_meta, days = 7) {
  if (nrow(sessions) == 0) {
    return(list(
      sessions_count = 0L,
      unique_visitors = 0L,
      completion_rate = NA_real_,
      median_duration_min = NA_real_,
      top_indicator = "Ingen data",
      trend_pct = NA_real_
    ))
  }

  # Parse tidsstempler
  sessions <- sessions |>
    dplyr::mutate(
      connected = lubridate::ymd_hms(.data$server_connected, quiet = TRUE),
      disconnected = lubridate::ymd_hms(.data$server_disconnected, quiet = TRUE)
    )

  cutoff <- lubridate::now() - lubridate::days(days)
  recent <- sessions |> dplyr::filter(.data$connected >= cutoff)

  # Sessions denne uge
  sessions_count <- nrow(recent)

  # Unikke besogende (fra client metadata)
  unique_visitors <- if (nrow(client_meta) > 0 && "visitor_id" %in% names(client_meta)) {
    dplyr::n_distinct(client_meta$visitor_id)
  } else {
    NA_integer_
  }

  # Completion rate: sessions der har et spc_plot output
  sessions_with_plot <- if (nrow(inputs) > 0) {
    chart_sessions <- inputs |>
      dplyr::filter(.data$name == "chart_type") |>
      dplyr::pull(.data$session) |>
      unique()
    length(chart_sessions)
  } else {
    0L
  }
  completion_rate <- if (sessions_count > 0) {
    round(sessions_with_plot / sessions_count * 100, 1)
  } else {
    NA_real_
  }

  # Median session-varighed
  median_duration_min <- if ("session_duration" %in% names(recent) && nrow(recent) > 0) {
    round(stats::median(recent$session_duration, na.rm = TRUE) / 60, 1)
  } else {
    NA_real_
  }

  # Populaereste indikator
  top_indicator <- if (nrow(inputs) > 0 && "name" %in% names(inputs)) {
    indicator_inputs <- inputs |>
      dplyr::filter(.data$name == "indicator_title", nchar(.data$value) > 0)
    if (nrow(indicator_inputs) > 0) {
      indicator_inputs |>
        dplyr::count(.data$value, sort = TRUE) |>
        dplyr::slice(1) |>
        dplyr::pull(.data$value)
    } else {
      "Ingen data"
    }
  } else {
    "Ingen data"
  }

  # Trend: uge-over-uge aendring
  prev_cutoff <- cutoff - lubridate::days(days)
  prev_week <- sessions |>
    dplyr::filter(.data$connected >= prev_cutoff, .data$connected < cutoff)
  trend_pct <- if (nrow(prev_week) > 0) {
    round((sessions_count - nrow(prev_week)) / nrow(prev_week) * 100, 1)
  } else {
    NA_real_
  }

  list(
    sessions_count = sessions_count,
    unique_visitors = unique_visitors,
    completion_rate = completion_rate,
    median_duration_min = median_duration_min,
    top_indicator = top_indicator,
    trend_pct = trend_pct
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add R/kpi_calculations.R
git commit -m "feat: tilfoej KPI-beregninger for overblik-fane"
```

---

### Task 8: Overblik-grafer (R/plot_overview.R)

**Files:**
- Create: `R/plot_overview.R`

- [ ] **Step 1: Opret plot_overview.R**

```r
# R/plot_overview.R
# ggplot2 grafer til Overblik-fane

#' Sessions over tid (30 dage, med glidende gennemsnit)
#'
#' @param sessions data.frame med sessions
#' @return ggplot objekt
plot_sessions_over_time <- function(sessions) {
  if (nrow(sessions) == 0) return(ggplot2::ggplot() + ggplot2::theme_void() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = "Ingen data", size = 6, color = "grey60"))

  daily <- sessions |>
    dplyr::mutate(dato = as.Date(lubridate::ymd_hms(.data$server_connected, quiet = TRUE))) |>
    dplyr::filter(.data$dato >= Sys.Date() - 30) |>
    dplyr::count(.data$dato, name = "sessions")

  # Udfyld manglende dage med 0
  all_days <- data.frame(dato = seq(Sys.Date() - 30, Sys.Date(), by = "day"))
  daily <- dplyr::left_join(all_days, daily, by = "dato") |>
    dplyr::mutate(sessions = tidyr::replace_na(.data$sessions, 0))

  # 7-dages glidende gennemsnit
  daily <- daily |>
    dplyr::mutate(
      gns_7d = zoo::rollmean(.data$sessions, k = 7, fill = NA, align = "right")
    )

  ggplot2::ggplot(daily, ggplot2::aes(x = .data$dato)) +
    ggplot2::geom_col(ggplot2::aes(y = .data$sessions), fill = "#3498db", alpha = 0.4) +
    ggplot2::geom_line(ggplot2::aes(y = .data$gns_7d), color = "#2c3e50", linewidth = 1, na.rm = TRUE) +
    ggplot2::scale_x_date(date_labels = "%d. %b", date_breaks = "1 week") +
    ggplot2::labs(x = NULL, y = "Sessions", title = "Sessions per dag (seneste 30 dage)") +
    ggplot2::theme_minimal()
}

#' Top 10 indikatorer (horisontal barchart)
#'
#' @param inputs data.frame med inputs
#' @return ggplot objekt
plot_top_indicators <- function(inputs) {
  if (nrow(inputs) == 0) return(ggplot2::ggplot() + ggplot2::theme_void() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = "Ingen data", size = 6, color = "grey60"))

  indicators <- inputs |>
    dplyr::filter(.data$name == "indicator_title", nchar(.data$value) > 0) |>
    dplyr::count(.data$value, sort = TRUE, name = "antal") |>
    dplyr::slice_head(n = 10) |>
    dplyr::mutate(value = stats::reorder(.data$value, .data$antal))

  if (nrow(indicators) == 0) return(ggplot2::ggplot() + ggplot2::theme_void() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = "Ingen indikatorer registreret", size = 5, color = "grey60"))

  ggplot2::ggplot(indicators, ggplot2::aes(x = .data$antal, y = .data$value)) +
    ggplot2::geom_col(fill = "#27ae60") +
    ggplot2::labs(x = "Antal sessions", y = NULL, title = "Top 10 indikatorer") +
    ggplot2::theme_minimal()
}

#' Wizard completion funnel
#'
#' @param sessions data.frame med sessions
#' @param inputs data.frame med inputs
#' @return ggplot objekt
plot_wizard_funnel <- function(sessions, inputs) {
  total <- nrow(sessions)
  if (total == 0) return(ggplot2::ggplot() + ggplot2::theme_void() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = "Ingen data", size = 6, color = "grey60"))

  # Upload = alle sessions, Analyser = sessions med chart_type, Eksport = sessions med export format
  upload_count <- total
  analyser_count <- if (nrow(inputs) > 0) {
    inputs |> dplyr::filter(.data$name == "chart_type") |>
      dplyr::pull(.data$session) |> dplyr::n_distinct()
  } else 0L
  eksport_count <- if (nrow(inputs) > 0) {
    inputs |> dplyr::filter(grepl("export", .data$name, fixed = TRUE)) |>
      dplyr::pull(.data$session) |> dplyr::n_distinct()
  } else 0L

  funnel <- data.frame(
    trin = factor(c("Upload", "Analyser", "Eksport"), levels = c("Upload", "Analyser", "Eksport")),
    antal = c(upload_count, analyser_count, eksport_count)
  )

  ggplot2::ggplot(funnel, ggplot2::aes(x = .data$trin, y = .data$antal)) +
    ggplot2::geom_col(fill = c("#3498db", "#2ecc71", "#e67e22")) +
    ggplot2::geom_text(ggplot2::aes(label = .data$antal), vjust = -0.5, fontface = "bold") +
    ggplot2::labs(x = NULL, y = "Antal sessions", title = "Wizard-flow") +
    ggplot2::theme_minimal()
}
```

- [ ] **Step 2: Commit**

```bash
git add R/plot_overview.R
git commit -m "feat: tilfoej overblik-grafer (sessions, top indikatorer, wizard funnel)"
```

---

### Task 9: Tekniske grafer (R/plot_technical.R)

**Files:**
- Create: `R/plot_technical.R`

- [ ] **Step 1: Opret plot_technical.R**

```r
# R/plot_technical.R
# ggplot2 grafer til Teknisk-fane

#' Feature-brug (horisontal barchart)
#'
#' @param inputs data.frame med inputs
#' @return ggplot objekt
plot_feature_usage <- function(inputs) {
  if (nrow(inputs) == 0) return(.empty_plot("Ingen data"))

  # Taael brug af noegle-features
  features <- inputs |>
    dplyr::filter(.data$name %in% c("chart_type", "skift_column", "frys_column")) |>
    dplyr::count(.data$name, .data$value, sort = TRUE, name = "antal") |>
    dplyr::slice_head(n = 15) |>
    dplyr::mutate(label = paste0(.data$name, ": ", .data$value)) |>
    dplyr::mutate(label = stats::reorder(.data$label, .data$antal))

  if (nrow(features) == 0) return(.empty_plot("Ingen feature-data"))

  ggplot2::ggplot(features, ggplot2::aes(x = .data$antal, y = .data$label)) +
    ggplot2::geom_col(fill = "#8e44ad") +
    ggplot2::labs(x = "Antal", y = NULL, title = "Feature-brug") +
    ggplot2::theme_minimal()
}

#' Wizard-flow funnel med frafald (stacked barchart)
#'
#' @param sessions data.frame med sessions
#' @param inputs data.frame med inputs
#' @return ggplot objekt
plot_wizard_funnel_detailed <- function(sessions, inputs) {
  total <- nrow(sessions)
  if (total == 0) return(.empty_plot("Ingen data"))

  upload_count <- total
  analyser_count <- if (nrow(inputs) > 0) {
    inputs |> dplyr::filter(.data$name == "chart_type") |>
      dplyr::pull(.data$session) |> dplyr::n_distinct()
  } else 0L
  eksport_count <- if (nrow(inputs) > 0) {
    inputs |> dplyr::filter(grepl("export", .data$name, fixed = TRUE)) |>
      dplyr::pull(.data$session) |> dplyr::n_distinct()
  } else 0L

  funnel <- data.frame(
    trin = factor(c("Upload", "Analyser", "Eksport"), levels = c("Upload", "Analyser", "Eksport")),
    antal = c(upload_count, analyser_count, eksport_count),
    frafald_pct = c(NA, round((1 - analyser_count / max(upload_count, 1)) * 100, 1),
                    round((1 - eksport_count / max(analyser_count, 1)) * 100, 1))
  )

  ggplot2::ggplot(funnel, ggplot2::aes(x = .data$trin, y = .data$antal)) +
    ggplot2::geom_col(fill = c("#3498db", "#2ecc71", "#e67e22")) +
    ggplot2::geom_text(ggplot2::aes(label = paste0(.data$antal, "\n(",
      ifelse(is.na(.data$frafald_pct), "", paste0("-", .data$frafald_pct, "%")), ")")),
      vjust = -0.3, size = 3.5) +
    ggplot2::labs(x = NULL, y = "Sessions", title = "Wizard-flow med frafald") +
    ggplot2::theme_minimal()
}

#' Fejl-oversigt (top fejltyper)
#'
#' @param errors data.frame med errors
#' @return ggplot objekt
plot_error_overview <- function(errors) {
  if (nrow(errors) == 0) return(.empty_plot("Ingen fejl registreret"))

  top_errors <- errors |>
    dplyr::count(.data$error, sort = TRUE, name = "antal") |>
    dplyr::slice_head(n = 10) |>
    dplyr::mutate(error = stringr::str_trunc(.data$error, 50)) |>
    dplyr::mutate(error = stats::reorder(.data$error, .data$antal))

  ggplot2::ggplot(top_errors, ggplot2::aes(x = .data$antal, y = .data$error)) +
    ggplot2::geom_col(fill = "#e74c3c") +
    ggplot2::labs(x = "Antal", y = NULL, title = "Top 10 fejltyper") +
    ggplot2::theme_minimal()
}

#' Performance boxplot
#'
#' @param perf_metrics data.frame med performance metrics
#' @return ggplot objekt
plot_performance <- function(perf_metrics) {
  if (nrow(perf_metrics) == 0) return(.empty_plot("Ingen performance-data"))

  # Filtrér relevante metrikker
  perf_long <- perf_metrics |>
    dplyr::select(dplyr::any_of(c("type", "load_complete_ms", "dom_ready_ms",
                                   "ttfb_ms", "duration_ms"))) |>
    tidyr::pivot_longer(
      cols = dplyr::any_of(c("load_complete_ms", "dom_ready_ms", "ttfb_ms", "duration_ms")),
      names_to = "metric",
      values_to = "ms"
    ) |>
    dplyr::filter(!is.na(.data$ms))

  if (nrow(perf_long) == 0) return(.empty_plot("Ingen performance-data"))

  ggplot2::ggplot(perf_long, ggplot2::aes(x = .data$metric, y = .data$ms)) +
    ggplot2::geom_boxplot(fill = "#f39c12", alpha = 0.6) +
    ggplot2::labs(x = NULL, y = "Millisekunder", title = "Performance-fordeling") +
    ggplot2::coord_flip() +
    ggplot2::theme_minimal()
}

#' Browser/OS donut chart
#'
#' @param client_meta data.frame med client metadata
#' @return ggplot objekt
plot_browser_os <- function(client_meta) {
  if (nrow(client_meta) == 0) return(.empty_plot("Ingen browser-data"))

  # Enkel browser-parsing fra user_agent
  browser_data <- client_meta |>
    dplyr::mutate(browser = dplyr::case_when(
      grepl("Chrome", .data$user_agent) & !grepl("Edg", .data$user_agent) ~ "Chrome",
      grepl("Firefox", .data$user_agent) ~ "Firefox",
      grepl("Safari", .data$user_agent) & !grepl("Chrome", .data$user_agent) ~ "Safari",
      grepl("Edg", .data$user_agent) ~ "Edge",
      TRUE ~ "Anden"
    )) |>
    dplyr::count(.data$browser, sort = TRUE, name = "antal")

  ggplot2::ggplot(browser_data, ggplot2::aes(x = "", y = .data$antal, fill = .data$browser)) +
    ggplot2::geom_col(width = 1) +
    ggplot2::coord_polar("y") +
    ggplot2::labs(fill = "Browser", title = "Browser-fordeling") +
    ggplot2::theme_void() +
    ggplot2::theme(legend.position = "bottom")
}

#' Returning visitors (stacked area chart)
#'
#' @param sessions data.frame med sessions
#' @param client_meta data.frame med client metadata
#' @return ggplot objekt
plot_returning_visitors <- function(sessions, client_meta) {
  if (nrow(sessions) == 0 || nrow(client_meta) == 0) return(.empty_plot("Ingen data"))

  # Foerste besog per visitor_id
  if (!"visitor_id" %in% names(client_meta)) return(.empty_plot("Ingen visitor-ID data"))

  first_seen <- client_meta |>
    dplyr::group_by(.data$visitor_id) |>
    dplyr::summarise(first_visit = min(.data$timestamp, na.rm = TRUE), .groups = "drop")

  visitor_sessions <- client_meta |>
    dplyr::mutate(dato = as.Date(.data$timestamp)) |>
    dplyr::left_join(first_seen, by = "visitor_id") |>
    dplyr::mutate(type = ifelse(as.Date(.data$first_visit) == .data$dato, "Ny", "Tilbagevendende")) |>
    dplyr::count(.data$dato, .data$type, name = "antal")

  ggplot2::ggplot(visitor_sessions, ggplot2::aes(x = .data$dato, y = .data$antal, fill = .data$type)) +
    ggplot2::geom_area(alpha = 0.7) +
    ggplot2::scale_fill_manual(values = c("Ny" = "#3498db", "Tilbagevendende" = "#2ecc71")) +
    ggplot2::labs(x = NULL, y = "Antal", fill = NULL, title = "Nye vs. tilbagevendende besogende") +
    ggplot2::theme_minimal() +
    ggplot2::theme(legend.position = "bottom")
}

#' Tidsmoenstre heatmap (ugedag x time)
#'
#' @param sessions data.frame med sessions
#' @return ggplot objekt
plot_time_patterns <- function(sessions) {
  if (nrow(sessions) == 0) return(.empty_plot("Ingen data"))

  time_data <- sessions |>
    dplyr::mutate(
      connected = lubridate::ymd_hms(.data$server_connected, quiet = TRUE),
      ugedag = factor(
        lubridate::wday(.data$connected, label = TRUE, abbr = TRUE, locale = "da_DK.UTF-8"),
        levels = c("man", "tir", "ons", "tor", "fre", "lor", "son")
      ),
      time = lubridate::hour(.data$connected)
    ) |>
    dplyr::count(.data$ugedag, .data$time, name = "antal")

  ggplot2::ggplot(time_data, ggplot2::aes(x = .data$time, y = .data$ugedag, fill = .data$antal)) +
    ggplot2::geom_tile(color = "white") +
    ggplot2::scale_fill_gradient(low = "#eef6ff", high = "#2c3e50") +
    ggplot2::scale_x_continuous(breaks = seq(0, 23, 3)) +
    ggplot2::labs(x = "Time", y = NULL, fill = "Sessions", title = "Tidsmoenstre (ugedag x time)") +
    ggplot2::theme_minimal()
}

# Intern helper til tom graf
.empty_plot <- function(label = "Ingen data") {
  ggplot2::ggplot() +
    ggplot2::theme_void() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = label, size = 6, color = "grey60")
}
```

- [ ] **Step 2: Commit**

```bash
git add R/plot_technical.R
git commit -m "feat: tilfoej tekniske grafer (feature-brug, fejl, performance, browser, visitors, heatmap)"
```

---

### Task 10: Hoveddokument (index.qmd)

**Files:**
- Create: `index.qmd`

- [ ] **Step 1: Opret index.qmd**

````markdown
---
title: "biSPCharts Analytics"
format: dashboard
---

```{r}
#| label: setup
#| include: false
library(dplyr)
library(ggplot2)
library(lubridate)
library(pins)
library(scales)
library(tidyr)

# Indlaes alle R-filer
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# Indlaes data
data <- load_analytics_data()
client_meta <- extract_client_metadata(data$inputs)
perf_metrics <- extract_performance_metrics(data$inputs)
kpis <- calculate_overview_kpis(data$sessions, data$inputs, client_meta)
```

# Overblik

## Row {height=20%}

```{r}
#| content: valuebox
#| title: "Sessions denne uge"
list(
  value = kpis$sessions_count,
  icon = "bar-chart",
  color = "primary"
)
```

```{r}
#| content: valuebox
#| title: "Unikke besogende"
list(
  value = ifelse(is.na(kpis$unique_visitors), "—", kpis$unique_visitors),
  icon = "people",
  color = "info"
)
```

```{r}
#| content: valuebox
#| title: "Completion rate"
list(
  value = ifelse(is.na(kpis$completion_rate), "—", paste0(kpis$completion_rate, "%")),
  icon = "check-circle",
  color = ifelse(!is.na(kpis$completion_rate) && kpis$completion_rate >= 50, "success", "warning")
)
```

```{r}
#| content: valuebox
#| title: "Gns. varighed"
list(
  value = ifelse(is.na(kpis$median_duration_min), "—", paste0(kpis$median_duration_min, " min")),
  icon = "clock",
  color = "secondary"
)
```

```{r}
#| content: valuebox
#| title: "Top indikator"
list(
  value = kpis$top_indicator,
  icon = "star"
)
```

```{r}
#| content: valuebox
#| title: "Trend (uge/uge)"
trend_label <- if (is.na(kpis$trend_pct)) "—" else paste0(
  ifelse(kpis$trend_pct >= 0, "+", ""), kpis$trend_pct, "%"
)
list(
  value = trend_label,
  icon = ifelse(!is.na(kpis$trend_pct) && kpis$trend_pct >= 0, "arrow-up", "arrow-down"),
  color = ifelse(!is.na(kpis$trend_pct) && kpis$trend_pct >= 0, "success", "danger")
)
```

## Row {height=40%}

### Column {width=60%}

```{r}
#| title: "Sessions per dag"
plot_sessions_over_time(data$sessions)
```

### Column {width=40%}

```{r}
#| title: "Top 10 indikatorer"
plot_top_indicators(data$inputs)
```

## Row {height=40%}

```{r}
#| title: "Wizard-flow"
plot_wizard_funnel(data$sessions, data$inputs)
```

# Teknisk

## Row {height=50%}

### Column {width=60%}

```{r}
#| title: "Feature-brug"
plot_feature_usage(data$inputs)
```

### Column {width=40%}

```{r}
#| title: "Wizard-flow (frafald)"
plot_wizard_funnel_detailed(data$sessions, data$inputs)
```

## Row {height=50%}

### Column {width=50%}

```{r}
#| title: "Fejl-oversigt"
plot_error_overview(data$errors)
```

### Column {width=50%}

```{r}
#| title: "Performance"
plot_performance(perf_metrics)
```

## Row {height=50%}

### Column {width=33%}

```{r}
#| title: "Browser/OS"
plot_browser_os(client_meta)
```

### Column {width=33%}

```{r}
#| title: "Nye vs. tilbagevendende"
plot_returning_visitors(data$sessions, client_meta)
```

### Column {width=34%}

```{r}
#| title: "Tidsmoenstre"
plot_time_patterns(data$sessions)
```
````

- [ ] **Step 2: Commit**

```bash
git add index.qmd
git commit -m "feat: tilfoej hoveddokument med overblik og teknisk fane"
```

---

### Task 11: Install dependencies og render

- [ ] **Step 1: Installer dependencies**

Run:
```bash
Rscript -e "renv::install(c('pins', 'ggplot2', 'dplyr', 'tidyr', 'lubridate', 'scales', 'bslib', 'jsonlite', 'stringr', 'zoo'))"
Rscript -e "renv::snapshot()"
```

- [ ] **Step 2: Test render lokalt (forventes at vise tom data)**

Run: `quarto render index.qmd`
Expected: HTML-fil genereret i `_site/` uden fejl (alle grafer viser "Ingen data" placeholders)

- [ ] **Step 3: Opret manifest for Connect Cloud**

Run: `Rscript -e "rsconnect::writeManifest()"`

- [ ] **Step 4: Commit og push**

```bash
git add -A
git commit -m "feat: installer dependencies, render dashboard, tilfoej manifest"
git push origin main
```

---

### Task 12: Deploy til Connect Cloud

- [ ] **Step 1: Publish til Connect Cloud**

Gaa til Connect Cloud og connect GitHub repository `johanreventlow/biSPCharts-analytics`.

- [ ] **Step 2: Konfigurer environment variables**

I Connect Cloud UI, tilfoej:
- `CONNECT_SERVER` — Connect Cloud URL
- `CONNECT_API_KEY` — API key

- [ ] **Step 3: Konfigurer scheduled rendering**

I Connect Cloud UI, saet schedule til daglig rendering (fx kl. 06:00).

- [ ] **Step 4: Verificer at dashboard loader og viser placeholders**

Aaben dashboard URL og verificer:
- To faner synlige (Overblik, Teknisk)
- Value boxes viser "0" eller "—"
- Grafer viser "Ingen data" placeholders
- Ingen render-fejl

---

## Opsummering

| Del | Tasks | Beskrivelse |
|-----|-------|-------------|
| **A: biSPCharts** | 1-3 | Udvid pin-data, fjern input-filtre, opdater NAMESPACE/manifest |
| **B: Dashboard** | 4-12 | Nyt repo, Quarto config, data-lag, KPI'er, grafer, index.qmd, deploy |
