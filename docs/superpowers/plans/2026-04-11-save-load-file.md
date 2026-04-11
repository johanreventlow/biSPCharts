# Fil-baseret gem og indlæs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Brugere kan gemme data og alle indstillinger til en Excel-fil og indlæse den igen på en vilkårlig computer via det eksisterende upload-flow.

**Architecture:** En ny `R/fct_spc_file_save_load.R` med to rene funktioner (`build_spc_excel` / `parse_spc_excel`) håndterer fil-I/O. Upload-handleren i `fct_file_operations.R` detekterer "Indstillinger"-arket og genopretter state via den eksisterende `restore_metadata()`. En `downloadButton` i wizard-navigationen giver brugeren adgang til gem-funktionen.

**Tech Stack:** `openxlsx` (>=4.2.0, allerede i DESCRIPTION), `readxl` (>=1.4.0, allerede i DESCRIPTION), `shinyjs` (allerede i DESCRIPTION), `stringr` (allerede i DESCRIPTION), `testthat` til unit-tests.

---

## Filer

| Status | Fil | Ændring |
|--------|-----|---------|
| OPRET | `R/fct_spc_file_save_load.R` | `build_spc_excel()` + `parse_spc_excel()` |
| OPRET | `tests/testthat/test-fct_spc_file_save_load.R` | Unit-tests |
| MODIFICÉR | `R/fct_file_operations.R` | Linje ~348: tilføj "Indstillinger"-detektion i `handle_excel_upload()` |
| MODIFICÉR | `R/utils_server_event_listeners.R` | Linje ~1494: udvid routing-betingelse i `direct_file_upload`-observer + downloadHandler |
| MODIFICÉR | `R/ui_app_ui.R` | Linje ~313: tilføj `downloadButton` i wizard-footer |
| MODIFICÉR | `R/utils_server_event_listeners.R` | Tilføj `downloadHandler` + enable/disable observer |

---

## Task 1: `build_spc_excel()` — skriv Excel med to ark

**Files:**
- Create: `tests/testthat/test-fct_spc_file_save_load.R`
- Create: `R/fct_spc_file_save_load.R`

- [ ] **Trin 1: Skriv fejlende tests**

Opret `tests/testthat/test-fct_spc_file_save_load.R`:

```r
test_that("build_spc_excel opretter fil med to ark: Data og Indstillinger", {
  data <- data.frame(dato = as.Date("2024-01-01") + 0:4,
                     vaerdi = c(1.0, 2.0, 3.0, 4.0, 5.0))
  metadata <- list(x_column = "dato", y_column = "vaerdi", chart_type = "p")

  path <- build_spc_excel(data, metadata)

  expect_true(file.exists(path))
  sheets <- readxl::excel_sheets(path)
  expect_true("Data" %in% sheets)
  expect_true("Indstillinger" %in% sheets)
})

test_that("build_spc_excel Data-ark indeholder korrekte rækker og kolonner", {
  data <- data.frame(dato = as.Date("2024-01-01") + 0:4,
                     vaerdi = c(1.0, 2.0, 3.0, 4.0, 5.0))
  metadata <- list(x_column = "dato")

  path <- build_spc_excel(data, metadata)
  result <- readxl::read_excel(path, sheet = "Data")

  expect_equal(nrow(result), 5)
  expect_true("dato" %in% names(result))
  expect_true("vaerdi" %in% names(result))
})

test_that("build_spc_excel Indstillinger-ark indeholder metadata som Felt/Vaerdi", {
  data <- data.frame(x = 1:3, y = 4:6)
  metadata <- list(x_column = "x", y_column = "y", chart_type = "p",
                   indicator_title = "Min titel")

  path <- build_spc_excel(data, metadata)
  # skip = 2: spring kommentarcelleblok og tom linje over
  settings <- readxl::read_excel(path, sheet = "Indstillinger", skip = 2)

  expect_true("Felt" %in% names(settings))
  expect_true("Vaerdi" %in% names(settings))

  felt_values <- settings$Felt
  expect_true("x_column" %in% felt_values)
  expect_true("indicator_title" %in% felt_values)

  title_row <- settings[settings$Felt == "indicator_title", ]
  expect_equal(title_row$Vaerdi, "Min titel")
})

test_that("build_spc_excel returnerer sti til eksisterende fil", {
  data <- data.frame(x = 1)
  metadata <- list()

  path <- build_spc_excel(data, metadata)

  expect_true(is.character(path))
  expect_true(grepl("\\.xlsx$", path))
  expect_true(file.exists(path))
})
```

- [ ] **Trin 2: Kør tests og bekræft at de fejler**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-fct_spc_file_save_load.R')"
```

Forventet: FEJL — `could not find function "build_spc_excel"`

- [ ] **Trin 3: Implementér `build_spc_excel()`**

Opret `R/fct_spc_file_save_load.R`:

```r
#' Fil-baseret gem og indlæs
#'
#' To rene funktioner til at skrive og læse biSPCharts Excel-filer.
#' Filen har to ark: "Data" (de rå rækker) og "Indstillinger" (alle
#' UI-indstillinger som Felt/Værdi-tabel), svarende til hvad
#' collect_metadata() returnerer.
#'
#' @name fct_spc_file_save_load
NULL

#' Byg biSPCharts Excel-fil med Data- og Indstillinger-ark
#'
#' @param data data.frame med brugerens data
#' @param metadata Named list svarende til collect_metadata()-output
#' @return Karakter-streng: sti til midlertidig .xlsx-fil
#' @keywords internal
build_spc_excel <- function(data, metadata) {
  wb <- openxlsx::createWorkbook()

  # --- Ark 1: Data ---
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, sheet = "Data", x = data, rowNames = FALSE)

  # --- Ark 2: Indstillinger ---
  openxlsx::addWorksheet(wb, "Indstillinger")

  # Forklarende kommentar i celle A1
  kommentar <- paste0(
    "Dette ark bruges af biSPCharts til at gendanne dine indstillinger. ",
    "Du kan redigere v\u00e6rdierne, men undg\u00e5 at slette arket."
  )
  openxlsx::writeData(wb, sheet = "Indstillinger",
    x = data.frame(Besked = kommentar), startRow = 1, colNames = FALSE)

  # Metadata som Felt/Vaerdi-tabel fra række 3
  meta_df <- data.frame(
    Felt   = names(metadata),
    Vaerdi = vapply(metadata, function(x) {
      if (is.null(x) || (length(x) == 1 && is.na(x))) "" else as.character(x)
    }, character(1)),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, sheet = "Indstillinger",
    x = meta_df, startRow = 3, rowNames = FALSE)

  # Gem til temp-fil
  temp_path <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, temp_path, overwrite = TRUE)
  temp_path
}
```

- [ ] **Trin 4: Kør tests og bekræft at de er grønne**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-fct_spc_file_save_load.R')"
```

Forventet: 4 tests PASS

- [ ] **Trin 5: Commit**

```bash
git add R/fct_spc_file_save_load.R tests/testthat/test-fct_spc_file_save_load.R
git commit -m "feat(save-load): tilføj build_spc_excel() med tests"
```

---

## Task 2: `parse_spc_excel()` — læs Indstillinger-ark

**Files:**
- Modify: `R/fct_spc_file_save_load.R`
- Modify: `tests/testthat/test-fct_spc_file_save_load.R`

- [ ] **Trin 1: Skriv fejlende tests**

Tilføj til bunden af `tests/testthat/test-fct_spc_file_save_load.R`:

```r
test_that("parse_spc_excel returnerer NULL for fil uden Indstillinger-ark", {
  data <- data.frame(x = 1:3, y = 4:6)
  path <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(data, path)

  result <- parse_spc_excel(path)
  expect_null(result)
})

test_that("parse_spc_excel returnerer named list med metadata-felter", {
  data <- data.frame(dato = as.Date("2024-01-01") + 0:4,
                     vaerdi = c(1.0, 2.0, 3.0, 4.0, 5.0))
  metadata <- list(
    x_column        = "dato",
    y_column        = "vaerdi",
    chart_type      = "p",
    indicator_title = "Ventetid til operation",
    target_value    = "30",
    y_axis_unit     = "dage"
  )

  path <- build_spc_excel(data, metadata)
  parsed <- parse_spc_excel(path)

  expect_false(is.null(parsed))
  expect_equal(parsed$x_column,        "dato")
  expect_equal(parsed$y_column,        "vaerdi")
  expect_equal(parsed$chart_type,      "p")
  expect_equal(parsed$indicator_title, "Ventetid til operation")
  expect_equal(parsed$target_value,    "30")
  expect_equal(parsed$y_axis_unit,     "dage")
})

test_that("parse_spc_excel round-trip: byg og parse giver identisk metadata", {
  data <- data.frame(x = 1:3)
  metadata <- list(
    x_column           = "x",
    y_column           = "y",
    chart_type         = "c",
    indicator_title    = "Test",
    indicator_description = "Beskrivelse",
    target_value       = "",
    centerline_value   = "",
    y_axis_unit        = "count",
    unit_type          = "select",
    unit_select        = "med",
    unit_custom        = "",
    export_title       = "Eksport titel",
    export_department  = "Afdeling X",
    export_format      = "pdf",
    pdf_description    = "",
    pdf_improvement    = "",
    png_size_preset    = "HD",
    png_dpi            = "300",
    active_tab         = "analyser",
    skift_column       = "",
    frys_column        = "",
    kommentar_column   = "",
    n_column           = ""
  )

  path <- build_spc_excel(data, metadata)
  parsed <- parse_spc_excel(path)

  for (felt in names(metadata)) {
    expect_equal(parsed[[felt]], metadata[[felt]],
      info = paste("Felt mismatch:", felt))
  }
})

test_that("parse_spc_excel returnerer NULL ved korrupt Indstillinger-ark", {
  # Lav fil med tomt Indstillinger-ark (ingen kolonner)
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, sheet = "Data", x = data.frame(x = 1))
  openxlsx::addWorksheet(wb, "Indstillinger")
  # Skriv kun kommentarlinje, ingen Felt/Vaerdi kolonner
  openxlsx::writeData(wb, sheet = "Indstillinger",
    x = data.frame(Besked = "kun kommentar"), startRow = 1, colNames = FALSE)
  path <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  result <- parse_spc_excel(path)
  # NULL eller tom liste begge accepteres — ingen crash
  expect_true(is.null(result) || length(result) == 0)
})
```

- [ ] **Trin 2: Kør tests og bekræft fejl**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-fct_spc_file_save_load.R')"
```

Forventet: FEJL — `could not find function "parse_spc_excel"`

- [ ] **Trin 3: Implementér `parse_spc_excel()`**

Tilføj til bunden af `R/fct_spc_file_save_load.R`:

```r
#' Læs Indstillinger-ark fra biSPCharts Excel-fil
#'
#' @param file_path Sti til Excel-filen
#' @return Named list svarende til collect_metadata()-output, eller NULL
#'   hvis arket mangler eller er korrupt
#' @keywords internal
parse_spc_excel <- function(file_path) {
  tryCatch({
    sheets <- readxl::excel_sheets(file_path)
    if (!"Indstillinger" %in% sheets) {
      return(NULL)
    }

    # skip = 2: spring kommentarcelleblok (række 1) og tom linje (række 2) over
    raw <- suppressMessages(
      readxl::read_excel(file_path, sheet = "Indstillinger",
        skip = 2, col_names = TRUE)
    )

    if (is.null(raw) || ncol(raw) < 2 || nrow(raw) == 0) {
      return(NULL)
    }

    felter  <- as.character(raw[[1]])
    vaerder <- as.character(raw[[2]])

    # NA fra tomme celler → ""
    vaerder[is.na(vaerder)] <- ""

    # Byg named list
    metadata <- as.list(vaerder)
    names(metadata) <- felter

    metadata
  }, error = function(e) {
    log_warn(
      paste("Kunne ikke parse Indstillinger-ark:", e$message),
      .context = "FILE_SAVE_LOAD"
    )
    NULL
  })
}
```

- [ ] **Trin 4: Kør alle tests**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-fct_spc_file_save_load.R')"
```

Forventet: Alle 8 tests PASS

- [ ] **Trin 5: Commit**

```bash
git add R/fct_spc_file_save_load.R tests/testthat/test-fct_spc_file_save_load.R
git commit -m "feat(save-load): tilføj parse_spc_excel() med round-trip tests"
```

---

## Task 3: Upload-detektion af "Indstillinger"-ark

**Baggrund:** Der er to upload-stier i appen. Den aktive sti er `input$direct_file_upload` i `R/utils_server_event_listeners.R` (linje ~1471). Den kalder `handle_excel_upload()` i `fct_file_operations.R` kun når den opdager "Data"+"Metadata"-ark. Vi skal udvide begge.

**Files:**
- Modify: `R/utils_server_event_listeners.R` linje ~1494
- Modify: `R/fct_file_operations.R` linje ~348

- [ ] **Trin 1: Udvid routing-betingelse i `direct_file_upload`-observer**

I `R/utils_server_event_listeners.R`, linje ~1494, er den nuværende kode:

```r
        if ("Data" %in% excel_sheets && "Metadata" %in% excel_sheets) {
          handle_excel_upload(file_info$datapath, session, app_state, emit)
        } else {
```

Erstat den med:

```r
        if ("Data" %in% excel_sheets &&
            ("Metadata" %in% excel_sheets || "Indstillinger" %in% excel_sheets)) {
          handle_excel_upload(file_info$datapath, session, app_state, emit, ui_service)
        } else {
```

Bemærk: tilføj også `ui_service` som argument — det eksisterende kald mangler det, men `handle_excel_upload` accepterer det.

- [ ] **Trin 2: Tilføj "Indstillinger"-detektion i `handle_excel_upload()`**

I `R/fct_file_operations.R`, linje 345-348:

```r
handle_excel_upload <- function(file_path, session, app_state, emit, ui_service = NULL) {
  excel_sheets <- readxl::excel_sheets(file_path)

  if ("Data" %in% excel_sheets && "Metadata" %in% excel_sheets) {
```

Indsæt følgende blok OVENFOR `if ("Data" %in% excel_sheets && "Metadata" ...`:

```r
  # Nyt biSPCharts gem-format: "Data" + "Indstillinger"
  if ("Data" %in% excel_sheets && "Indstillinger" %in% excel_sheets) {
    data <- readxl::read_excel(file_path, sheet = "Data", col_names = TRUE)
    data <- ensure_standard_columns(data)
    metadata <- parse_spc_excel(file_path)

    data_frame <- as.data.frame(data)
    set_current_data(app_state, data_frame)
    app_state$data$original_data <- data_frame

    emit$data_updated("file_loaded")
    app_state$session$file_uploaded <- TRUE
    app_state$columns$auto_detect$completed <- TRUE
    app_state$ui$hide_anhoej_rules <- FALSE
    emit$navigation_changed()

    if (!is.null(metadata)) {
      shiny::invalidateLater(500)
      shiny::isolate({
        restore_metadata(session, metadata, ui_service)
      })
    }

    besked <- if (!is.null(metadata)) {
      paste0("Gendannet: ", nrow(data_frame), " r\u00e6kker, ",
             ncol(data_frame), " kolonner + indstillinger")
    } else {
      paste0("Data indl\u00e6st: ", nrow(data_frame), " r\u00e6kker \u2014 ",
             "indstillinger kunne ikke gendannes")
    }
    shiny::showNotification(besked, type = "message", duration = 4)
    return(invisible(NULL))
  }

```

- [ ] **Trin 3: Kør eksisterende tests for at verificere ingen regression**

```bash
Rscript -e "testthat::test_dir('tests/testthat')"
```

Forventet: Alle tests PASS (ingen regressions)

- [ ] **Trin 4: Commit**

```bash
git add R/fct_file_operations.R R/utils_server_event_listeners.R
git commit -m "feat(save-load): detektér Indstillinger-ark ved Excel-upload"
```

---

## Task 4: Tilføj `downloadButton` i wizard-footer

**Files:**
- Modify: `R/ui_app_ui.R` linje ~313-330

- [ ] **Trin 1: Find det eksisterende nav-div**

I `R/ui_app_ui.R` linje ~313 er den nuværende kode:

```r
    shiny::div(
      style = "display: flex; justify-content: space-between;",
      shiny::actionButton(
        "back_to_upload",
        shiny::tagList(shiny::icon("arrow-left"), " Tilbage"),
        class = "btn-secondary",
        style = "width: 200px;",
        title = "Gå tilbage til upload"
      ),
      shiny::actionButton(
        "continue_to_export",
        shiny::tagList("Fortsæt ", shiny::icon("arrow-right")),
        class = "btn-primary",
        style = "width: 200px;",
        title = "Gå til eksport"
      )
    )
```

- [ ] **Trin 2: Erstat div med tre-element layout**

Erstat den eksisterende `shiny::div(...)` med:

```r
    shiny::div(
      style = "display: flex; justify-content: space-between; align-items: center;",
      shiny::actionButton(
        "back_to_upload",
        shiny::tagList(shiny::icon("arrow-left"), " Tilbage"),
        class = "btn-secondary",
        style = "width: 200px;",
        title = "G\u00e5 tilbage til upload"
      ),
      shinyjs::disabled(
        shiny::downloadButton(
          "download_spc_file",
          shiny::tagList(shiny::icon("download"), " Gem til fil"),
          class = "btn-outline-secondary",
          style = "width: 200px;",
          title = "Gem data og indstillinger til Excel-fil"
        )
      ),
      shiny::actionButton(
        "continue_to_export",
        shiny::tagList("Forts\u00e6t ", shiny::icon("arrow-right")),
        class = "btn-primary",
        style = "width: 200px;",
        title = "G\u00e5 til eksport"
      )
    )
```

`shinyjs::disabled()` wrapper sikrer at knappen er grå ved start uden data.

- [ ] **Trin 3: Kør appen og verificer visuelt**

```bash
Rscript -e "source('global.R'); shiny::runApp()"
```

Check: Wizard-footer viser tre knapper jævnt fordelt. Gem-knappen er grå.

- [ ] **Trin 4: Commit**

```bash
git add R/ui_app_ui.R
git commit -m "feat(save-load): tilføj Gem til fil-knap i wizard-footer"
```

---

## Task 5: `downloadHandler` + enable/disable i server

**Files:**
- Modify: `R/utils_server_event_listeners.R`

- [ ] **Trin 1: Find indsættelsesstedet**

I `R/utils_server_event_listeners.R` er der en `shiny::observe()` der enables/disables `continue_to_export` (linje ~1305). Find dette mønster og indsæt de to nye blokke UMIDDELBART EFTER den eksisterende observe for `continue_to_export`.

Find denne kode (linje ~1317):

```r
  # Tilbage-knap: Trin 2 -> Trin 1
  shiny::observeEvent(input$back_to_upload, {
```

Indsæt følgende blokke INDEN `# Tilbage-knap`:

- [ ] **Trin 2: Indsæt enable/disable observer**

```r
  # Gem-knap: aktiv når data er uploadet
  shiny::observe({
    has_data <- isTRUE(app_state$session$file_uploaded) ||
      (!is.null(app_state$data$current_data) &&
        nrow(shiny::isolate(app_state$data$current_data)) > 0)

    if (has_data) {
      shinyjs::enable("download_spc_file")
    } else {
      shinyjs::disable("download_spc_file")
    }
  })

```

- [ ] **Trin 3: Indsæt `downloadHandler`**

Indsæt umiddelbart efter enable/disable-observeren:

```r
  # Gem til fil: download handler
  output$download_spc_file <- shiny::downloadHandler(
    filename = function() {
      md <- collect_metadata(input, app_state)
      title <- md$indicator_title
      if (is.null(title) || nchar(trimws(title)) == 0) {
        return("data_biSPCharts.xlsx")
      }
      safe_title <- title |>
        stringr::str_replace_all("[^\\w\\s\\-\u00e6\u00f8\u00e5\u00c6\u00d8\u00c5]", "") |>
        stringr::str_replace_all("\\s+", "_") |>
        stringr::str_trunc(50, ellipsis = "")
      paste0(safe_title, "_biSPCharts.xlsx")
    },
    content = function(file) {
      safe_operation(
        "Gem til fil",
        code = {
          data <- shiny::isolate(app_state$data$current_data)
          metadata <- collect_metadata(input, app_state)
          temp_path <- build_spc_excel(data, metadata)
          file.copy(temp_path, file)
        },
        error_type = "processing",
        session = session,
        show_user = TRUE,
        user_message = "Filen kunne ikke oprettes. Pr\u00f8v igen."
      )
    }
  )

```

- [ ] **Trin 4: Kør alle tests**

```bash
Rscript -e "testthat::test_dir('tests/testthat')"
```

Forventet: Alle tests PASS

- [ ] **Trin 5: Manuel test**

```bash
Rscript -e "source('global.R'); shiny::runApp()"
```

Testscenario A — Gem:
1. Upload en CSV-datafil
2. Verificer at "Gem til fil"-knappen bliver aktiv (blå outline)
3. Udfyld titel og diagramtype i trin 2
4. Klik "Gem til fil"
5. Bekræft at fil downloades med navn `[titel]_biSPCharts.xlsx`
6. Åbn i Excel: "Data"-ark har data, "Indstillinger"-ark har Felt/Værdi-tabel

Testscenario B — Gendan:
1. Upload den gemte `_biSPCharts.xlsx`-fil
2. Bekræft notifikation viser "Gendannet: N rækker … + indstillinger"
3. Bekræft trin 2 er automatisk udfyldt med korrekte kolonner og diagramtype
4. Bekræft titel og enhed er genoprettet

Testscenario C — Normal upload stadig virker:
1. Upload en almindelig CSV-fil
2. Bekræft normal flow (ingen restore, ingen fejlmeddelelse)

- [ ] **Trin 6: Commit**

```bash
git add R/utils_server_event_listeners.R
git commit -m "feat(save-load): tilføj downloadHandler og enable/disable til Gem-knap"
```

---

## Task 6: Hjælpetekst ved upload-knappen

**Files:**
- Modify: `R/ui_app_ui.R` linje ~690 (upload-knap-sektion)

Upload-knapperne er i `R/ui_app_ui.R`. Det skjulte fileInput `direct_file_upload` er linje ~679. Der er en "Indlæs XLS/CSV"-knap (`trigger_file_upload`) som er den bruger-synlige knap.

- [ ] **Trin 1: Find upload-knap-blokken**

```bash
grep -n "trigger_file_upload\|direct_file_upload\|Indlæs" R/ui_app_ui.R | head -10
```

- [ ] **Trin 2: Tilføj hjælpetekst under upload-knap-sektionen**

Find den `shiny::div(style = "flex: 0 0 120px;", ...)` der indeholder `direct_file_upload` og `trigger_file_upload` (linje ~674-692). Tilføj en `shiny::tags$small` umiddelbart efter den ydre `shiny::div` closing tag for upload-knap-blokken:

```r
shiny::tags$small(
  style = "color: #6c757d; font-size: 0.75rem; text-align: center; display: block; margin-top: 4px;",
  "Upload datafil eller gemt biSPCharts-fil"
)
```

- [ ] **Trin 3: Kør appen og verificer visuelt**

```bash
Rscript -e "source('global.R'); shiny::runApp()"
```

Check: Lille grå hjælpetekst vises under "Indlæs XLS/CSV"-knappen.

- [ ] **Trin 4: Commit**

```bash
git add R/ui_app_ui.R
git commit -m "feat(save-load): tilføj hjælpetekst ved upload-knap"
```

---

## Afslutning

Kør fuld testsuite én gang til:

```bash
Rscript -e "testthat::test_dir('tests/testthat')"
```

Forventet: Alle tests PASS, ingen regressions.
