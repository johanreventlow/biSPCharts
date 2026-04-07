# Paste Data Upload Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign upload-siden med to-kolonne layout: handlingsknapper (venstre) og paste-felt (hoejre), plus sample data feature.

**Architecture:** Omskriv `create_ui_upload_page()` i ui_app_ui.R til 4-8 kolonne layout. Ny server-side funktion `handle_paste_data()` i fct_file_operations.R parser pasted text via readr::read_delim(). Sample data som bundlet dataset.

**Tech Stack:** bslib layout_columns, shiny textAreaInput/actionButton, readr::read_delim

---

### Task 1: Redesign upload-side UI

**Files:**
- Modify: `R/ui_app_ui.R` — `create_ui_upload_page()` funktion (linje ~865-897)

**Step 1: Erstat create_ui_upload_page() med nyt to-kolonne layout**

Erstat HELE `create_ui_upload_page()` funktionen med:

```r
#' Upload-side med paste-felt og handlingsknapper
#'
#' Datawrapper-inspireret layout: handlinger (venstre), paste-felt (hoejre).
#' @export
create_ui_upload_page <- function() {
  sample_csv <- paste(
    "Dato;Vaerdi;Kommentar",
    "2024-01-01;42;",
    "2024-02-01;38;",
    "2024-03-01;45;Ny procedure",
    "2024-04-01;41;",
    "2024-05-01;39;",
    "2024-06-01;44;",
    sep = "\n"
  )

  shiny::div(
    class = "container-fluid",
    style = "max-width: 1000px; margin: 0 auto; padding-top: 30px;",
    bslib::layout_columns(
      col_widths = c(4, 8),

      # Venstre kolonne: handlingsknapper
      bslib::card(
        height = "100%",
        bslib::card_header(
          shiny::div(shiny::icon("folder-open"), " Datakilde")
        ),
        bslib::card_body(
          shiny::actionButton(
            "show_upload_modal",
            "Upload datafil",
            icon = shiny::icon("file-arrow-up"),
            class = "btn-primary w-100 mb-3",
            title = "Upload Excel eller CSV fil"
          ),
          shiny::actionButton(
            "clear_saved",
            "Start ny session",
            icon = shiny::icon("rotate"),
            class = "btn-outline-secondary w-100 mb-3",
            title = "Start med tom standardtabel"
          ),
          shiny::hr(),
          shiny::actionButton(
            "load_sample_data",
            "Proev med eksempeldata",
            icon = shiny::icon("flask"),
            class = "btn-link w-100",
            title = "Indlaes et SPC-eksempeldatasaet"
          )
        )
      ),

      # Hoejre kolonne: paste-felt
      bslib::card(
        height = "100%",
        bslib::card_header(
          shiny::div(shiny::icon("paste"), " Indsaet data")
        ),
        bslib::card_body(
          shiny::textAreaInput(
            "paste_data_input",
            label = NULL,
            value = sample_csv,
            rows = 15,
            width = "100%",
            placeholder = "Indsaet data fra Excel eller CSV her..."
          ),
          shiny::tags$small(
            class = "text-muted d-block mb-3",
            "Kolonner adskilles automatisk (tab, semikolon eller komma)"
          ),
          shiny::actionButton(
            "load_paste_data",
            "Indlaes data",
            icon = shiny::icon("arrow-right"),
            class = "btn-primary",
            title = "Parser og indlaeser det indsatte data"
          )
        )
      )
    )
  )
}
```

**Step 2: Commit**

```bash
git add R/ui_app_ui.R
git commit -m "feat(paste): redesign upload-side med to-kolonne layout og paste-felt"
```

---

### Task 2: Tilfoej handle_paste_data() server-logik

**Files:**
- Modify: `R/fct_file_operations.R` — tilfoej ny funktion efter `handle_csv_upload()`

**Step 1: Tilfoej handle_paste_data() funktion**

Tilfoej denne funktion EFTER `handle_csv_upload()` (efter linje ~549):

```r
#' Haandter indsatte (pasted) data fra textAreaInput
#'
#' Parser tekst-data med auto-detected separator (tab, semikolon, komma).
#' Bruger readr::read_delim med delim = NULL for auto-detection.
#'
#' @param text_data Character string med indsatte data
#' @param app_state Centraliseret app state
#' @param session_id Hashed session token (valgfri)
#' @param emit Event emit API
#' @return Usynligt NULL, opdaterer app_state som side-effekt
#' @keywords internal
handle_paste_data <- function(text_data, app_state, session_id = NULL, emit = NULL) {
  # Valider input
  if (is.null(text_data) || !nzchar(trimws(text_data))) {
    shiny::showNotification("Indsaet data foerst", type = "warning", duration = 3)
    return(invisible(NULL))
  }

  # Parser med auto-detected separator
  data <- tryCatch({
    readr::read_delim(
      I(text_data),
      delim = NULL,
      locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
      show_col_types = FALSE,
      trim_ws = TRUE
    )
  }, error = function(e) {
    # Fallback: proev eksplicit tab, semikolon, komma
    for (sep in c("\t", ";", ",")) {
      result <- tryCatch({
        readr::read_delim(
          I(text_data),
          delim = sep,
          locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
          show_col_types = FALSE,
          trim_ws = TRUE
        )
      }, error = function(e2) NULL)
      if (!is.null(result) && ncol(result) >= 2) return(result)
    }
    return(NULL)
  })

  # Valider resultat
  if (is.null(data) || ncol(data) < 2 || nrow(data) < 1) {
    shiny::showNotification(
      "Kunne ikke parse data. Kontroller at data har mindst 2 kolonner og 1 raekke.",
      type = "error", duration = 5
    )
    return(invisible(NULL))
  }

  # Preprocessing (genbrug eksisterende)
  preprocessing_result <- preprocess_uploaded_data(
    data,
    list(name = "pasted_data", size = nchar(text_data)),
    session_id
  )
  data <- preprocessing_result$data

  # Gem i app state (samme moenster som handle_csv_upload)
  data_frame <- as.data.frame(data)
  set_current_data(app_state, data_frame)
  app_state$data$original_data <- data_frame

  # Emit events
  emit$data_updated(context = "paste_data")
  app_state$session$file_uploaded <- TRUE
  app_state$columns$auto_detect$completed <- FALSE
  app_state$ui$hide_anhoej_rules <- FALSE
  emit$navigation_changed()

  shiny::showNotification(
    paste("Data indlaest:", nrow(data), "raekker,", ncol(data), "kolonner"),
    type = "message", duration = 3
  )

  invisible(NULL)
}
```

**Step 2: Commit**

```bash
git add R/fct_file_operations.R
git commit -m "feat(paste): tilfoej handle_paste_data() med auto-detect separator"
```

---

### Task 3: Tilfoej sample dataset

**Files:**
- Create: `inst/extdata/sample_spc_data.csv`

**Step 1: Opret sample datasaet**

Opret filen `inst/extdata/sample_spc_data.csv` med klinisk relevant eksempeldata (24 maaneder, infektionsrater):

```csv
Dato;Antal infektioner;Antal indlagte;Kommentar
2023-01-01;5;320;
2023-02-01;3;305;
2023-03-01;6;330;
2023-04-01;4;315;
2023-05-01;7;340;Udbrud paa afd. B
2023-06-01;5;325;
2023-07-01;3;290;Sommerferie
2023-08-01;4;310;
2023-09-01;6;335;
2023-10-01;5;320;
2023-11-01;8;345;
2023-12-01;4;300;
2024-01-01;3;315;Ny hygiejneprotokol
2024-02-01;2;310;
2024-03-01;3;325;
2024-04-01;2;330;
2024-05-01;4;340;
2024-06-01;1;320;
2024-07-01;3;295;
2024-08-01;2;315;
2024-09-01;3;335;
2024-10-01;2;320;
2024-11-01;1;340;
2024-12-01;2;310;Aarsopgoering
```

**Step 2: Commit**

```bash
git add inst/extdata/sample_spc_data.csv
git commit -m "feat(paste): tilfoej klinisk sample SPC datasaet"
```

---

### Task 4: Wire observers i server-side

**Files:**
- Modify: `R/utils_server_event_listeners.R` — tilfoej observers for paste og sample data

**Step 1: Tilfoej observer-funktion**

Tilfoej en ny funktion `setup_paste_data_observers()` i `R/utils_server_event_listeners.R` (foer `setup_event_listeners()`), og kald den fra `setup_event_listeners()`:

```r
#' Setup observers for paste data og sample data loading
#'
#' @param input Shiny input
#' @param app_state Centraliseret app state
#' @param session Shiny session
#' @param emit Event emit API
#' @keywords internal
setup_paste_data_observers <- function(input, app_state, session, emit) {
  # Observer: Indlaes pasted data
  shiny::observeEvent(input$load_paste_data, {
    handle_paste_data(
      text_data = input$paste_data_input,
      app_state = app_state,
      session_id = sanitize_session_token(session$token),
      emit = emit
    )
  })

  # Observer: Indlaes sample datasaet
  shiny::observeEvent(input$load_sample_data, {
    sample_path <- system.file("extdata", "sample_spc_data.csv", package = "biSPCharts")

    # Fallback for dev mode
    if (sample_path == "" || !file.exists(sample_path)) {
      sample_path <- "inst/extdata/sample_spc_data.csv"
    }

    if (file.exists(sample_path)) {
      handle_csv_upload(
        file_path = sample_path,
        app_state = app_state,
        session_id = sanitize_session_token(session$token),
        emit = emit
      )
      shiny::showNotification(
        "Eksempeldata indlaest — proev at analysere!",
        type = "message", duration = 3
      )
    } else {
      shiny::showNotification(
        "Kunne ikke finde eksempeldatasaet",
        type = "error", duration = 3
      )
    }
  })
}
```

**Step 2: Kald fra setup_event_listeners()**

I `setup_event_listeners()`, tilfoej kaldet ved siden af `setup_wizard_gates()`:

```r
  # Paste data og sample data observers
  setup_paste_data_observers(input, app_state, session, emit)
```

**Step 3: Commit**

```bash
git add R/utils_server_event_listeners.R
git commit -m "feat(paste): wire paste-data og sample-data observers"
```

---

### Task 5: Manuel test og verificering

**Step 1: Start app**

```r
source("app.R")
```

**Step 2: Verificer paste-data**

Tjekliste:
- [ ] Upload-siden viser to-kolonne layout (knapper venstre, paste-felt hoejre)
- [ ] Paste-feltet er forudfyldt med sample CSV-data
- [ ] Klik "Indlaes data" med forudfyldt data -> navigerer til trin 2, data vises i tabel
- [ ] Slet tekst, paste tab-separerede data fra Excel -> parser korrekt
- [ ] Slet tekst, paste komma-separerede data -> parser korrekt
- [ ] Slet tekst, klik "Indlaes data" med tomt felt -> viser advarsel
- [ ] Klik "Upload datafil" -> aabner fil-upload modal (eksisterende)
- [ ] Klik "Start ny session" -> nulstiller app
- [ ] Klik "Proev med eksempeldata" -> indlaeser 24 maaneders data, navigerer til trin 2

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(paste): komplet paste-data upload med sample data"
```

---

### Opsummering

| Task | Beskrivelse | Filer |
|------|-------------|-------|
| 1 | Redesign upload-side UI | Modify: R/ui_app_ui.R |
| 2 | handle_paste_data() parsing | Modify: R/fct_file_operations.R |
| 3 | Sample dataset | Create: inst/extdata/sample_spc_data.csv |
| 4 | Wire server observers | Modify: R/utils_server_event_listeners.R |
| 5 | Manuel test | Ingen filer |
