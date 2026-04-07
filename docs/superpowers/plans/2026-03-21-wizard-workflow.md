# Wizard Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refaktorér biSPCharts's UI fra single-page layout til en 4-trins Datawrapper-inspireret wizard.

**Architecture:** bslib `navset_bar()` tabs stylet via custom CSS til wizard-look. Wizard-moduler er UI-layout containere — form-inputs forbliver på top-level scope for at undgå at bryde ~190 eksisterende `input$`-referencer. Eksisterende event-bus, state management og business logic bevares uændret.

**Tech Stack:** Shiny, bslib, shinyjs, custom CSS. Eksisterende: BFHcharts, qicharts2, excelR.

**Spec:** `docs/superpowers/specs/2026-03-21-wizard-workflow-design.md`

**Worktree:** `.worktrees/wizard-workflow` (branch: `feat/wizard-workflow-impl`)

---

## File Structure

### Nye filer

| Fil | Ansvar |
|-----|--------|
| `inst/app/www/wizard.css` | Step indicator styling, wizard layout, sub-tab styling |
| `R/mod_wizard_upload.R` | Trin 1: Upload/blank UI + server |
| `R/mod_wizard_data.R` | Trin 2: Kolonne-mapping, tabel-wrapper UI + server |
| `R/mod_wizard_analyse.R` | Trin 3: Chart config, metadata, preview UI + server |

### Filer der omskrives

| Fil | Nuværende linjer | Ændring |
|-----|-----------------|---------|
| `R/app_ui.R` | 147 | Erstat med wizard `navset_bar()` layout |
| `R/ui_app_ui.R` | 1112 | Fjern/refaktorér — funktionalitet flyttes til wizard-moduler |

### Filer der tilpasses

| Fil | Ændring |
|-----|---------|
| `R/app_server_main.R` | Kald wizard modul-servere, fjern deprecated setup |
| `R/mod_export_ui.R` | Fjern duplikerede metadata-felter, læs fra app_state |
| `R/mod_export_server.R` | Læs metadata fra app_state i stedet for egne inputs |
| `R/utils_event_context_handlers.R` | Fjern auto-trigger i `handle_load_context()` |
| `R/state_management.R` | Tilføj metadata-felter til `app_state$session` |

### Filer der bevares uændret

- `R/fct_*.R`, `R/utils_*.R` (undtagen ovenstående), `R/config_*.R`
- `R/utils_event_system.R`, `global.R`
- `R/mod_spc_chart_ui.R`, `R/mod_spc_chart_server.R` (genbruges direkte)

---

## Task 0: Spike — Validér bslib + CSS tilgang

**Formål:** Bekræft at `navset_bar()` kan styles som wizard og at top-level inputs fungerer korrekt.

**Files:**
- Create: `.worktrees/wizard-workflow/spike/spike_wizard.R`

- [ ] **Step 1: Opret minimal spike-app**

```r
# spike/spike_wizard.R
library(shiny)
library(bslib)

ui <- page_navbar(
  title = "biSPCharts Spike",
  nav_panel(
    title = "1. Upload",
    value = "step_upload",
    h3("Upload"),
    fileInput("upload", "Vælg fil")
  ),
  nav_panel(
    title = "2. Data",
    value = "step_data",
    h3("Data"),
    selectInput("x_column", "X-akse:", choices = c("A", "B")),
    selectInput("y_column", "Y-akse:", choices = c("C", "D"))
  ),
  nav_panel(
    title = "3. Analyse",
    value = "step_analyse",
    navset_tab(
      nav_panel("Diagram",
        layout_sidebar(
          sidebar = sidebar(
            selectInput("chart_type", "Type:", choices = c("run", "i", "p")),
            width = 280, position = "left"
          ),
          plotOutput("preview_plot")
        )
      ),
      nav_panel("Detaljer",
        layout_sidebar(
          sidebar = sidebar(
            textInput("indicator_title", "Titel:"),
            width = 280, position = "left"
          ),
          plotOutput("preview_plot_details")
        )
      )
    )
  ),
  nav_panel(
    title = "4. Eksport",
    value = "step_export",
    h3("Eksport"),
    downloadButton("download", "Download")
  )
)

server <- function(input, output, session) {
  output$preview_plot <- renderPlot({ plot(1:10, main = input$chart_type) })
  output$preview_plot_details <- renderPlot({
    plot(1:10, main = input$indicator_title)
  })

  observe({
    cat("chart_type:", input$chart_type, "\n")
    cat("x_column:", input$x_column, "\n")
    cat("indicator_title:", input$indicator_title, "\n")
  })
}

shinyApp(ui, server)
```

- [ ] **Step 2: Kør spike og verificér**

Run: `cd .worktrees/wizard-workflow && Rscript -e "shiny::runApp('spike/spike_wizard.R', port = 4242)"`

Verificér:
1. Tabs vises som navigation
2. Inputs er tilgængelige på top-level scope (`input$chart_type` virker)
3. Sub-tabs i Trin 3 virker
4. `layout_sidebar()` med `position = "left"` virker
5. plotOutput vises i begge sub-tabs
6. **Duplikeret output ID test:** Prøv at have to plotOutput med samme ID i forskellige sub-tabs. Virker det, eller vises kun den ene? Hvis det ikke virker, brug separate output IDs (`preview_plot_diagram` og `preview_plot_detaljer`) og render begge server-side.
7. Verificér at `wizard.css` auto-inkluderes via `bundle_resources()` eller kræver manuel `tags$link()`

- [ ] **Step 3: Test CSS customization af tabs**

Tilføj inline CSS til spike-appen der styles tabs som wizard-cirkler:

```css
.nav-link { position: relative; }
.nav-link::before {
  content: attr(data-step);
  display: inline-flex;
  width: 28px; height: 28px;
  border-radius: 50%;
  align-items: center; justify-content: center;
  margin-right: 8px;
  background: #dee2e6; color: #6c757d;
  font-weight: 600; font-size: 13px;
}
.nav-link.active::before {
  background: #0d6efd; color: white;
}
```

Verificér at CSS påvirker tab-styling korrekt.

- [ ] **Step 4: Dokumentér spike-resultater**

Skriv kort notat om hvad der virker/ikke virker. Slet spike-filer.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "spike: validér bslib navset_bar() wizard styling"
```

---

## Task 1: Opret wizard.css

**Files:**
- Create: `inst/app/www/wizard.css`

- [ ] **Step 1: Opret wizard.css med step indicator styling**

```css
/* inst/app/www/wizard.css */

/* === WIZARD STEP INDICATOR === */

/* Skjul standard bslib nav-link tekst-styling */
.wizard-nav .nav-link {
  border: none !important;
  background: transparent !important;
  padding: 0.75rem 1.5rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #6c757d;
  font-weight: 500;
  transition: all 0.2s ease;
}

/* Step-cirkel (via CSS pseudo-element) */
.wizard-nav .nav-link .step-number {
  display: inline-flex;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 14px;
  background: #e9ecef;
  color: #6c757d;
  border: 2px solid #dee2e6;
  transition: all 0.2s ease;
  flex-shrink: 0;
}

/* Aktivt trin */
.wizard-nav .nav-link.active {
  color: #0d6efd;
  font-weight: 600;
}

.wizard-nav .nav-link.active .step-number {
  background: #0d6efd;
  color: white;
  border-color: #0d6efd;
  box-shadow: 0 0 0 4px rgba(13, 110, 253, 0.2);
}

/* Gennemført trin */
.wizard-nav .nav-link.step-complete {
  color: #198754;
}

.wizard-nav .nav-link.step-complete .step-number {
  background: #198754;
  color: white;
  border-color: #198754;
}

/* Fejl/mangler */
.wizard-nav .nav-link.step-error .step-number {
  border-color: #fd7e14;
  color: #fd7e14;
  background: rgba(253, 126, 20, 0.1);
}

/* Forbindelseslinje mellem trin */
.wizard-nav .nav-item:not(:last-child)::after {
  content: "";
  flex: 1;
  height: 2px;
  background: #dee2e6;
  margin: 0 -0.5rem;
  align-self: center;
}

.wizard-nav .nav-item.step-complete-item:not(:last-child)::after {
  background: #198754;
}

/* === TRIN 3: ANALYSE LAYOUT === */

.analyse-sidebar {
  background: rgba(0, 0, 0, 0.02);
  border-right: 1px solid #dee2e6;
}

.analyse-sidebar .form-label {
  font-size: 0.8rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: #6c757d;
  margin-bottom: 0.25rem;
}

/* === TRIN 1: UPLOAD KORT === */

.upload-card {
  border: 2px dashed #dee2e6;
  border-radius: 12px;
  padding: 2.5rem 2rem;
  text-align: center;
  cursor: pointer;
  transition: all 0.2s ease;
  max-width: 300px;
}

.upload-card:hover {
  border-color: #0d6efd;
  background: rgba(13, 110, 253, 0.03);
}

.upload-card-icon {
  font-size: 2.5rem;
  margin-bottom: 0.5rem;
}

.upload-card-title {
  font-weight: 600;
  font-size: 1.1rem;
  margin-bottom: 0.5rem;
}

.upload-card-desc {
  font-size: 0.85rem;
  color: #6c757d;
}

.upload-divider {
  color: #adb5bd;
  font-weight: 600;
  padding: 0 1rem;
}

/* === VALUE BOXES (Anhøj rules) === */

.anhoej-boxes {
  display: flex;
  gap: 0.75rem;
  margin-top: 1rem;
}

.anhoej-box {
  flex: 1;
  border-radius: 8px;
  padding: 0.75rem;
  text-align: center;
}

.anhoej-box-label {
  font-size: 0.7rem;
  text-transform: uppercase;
  color: #6c757d;
  margin-bottom: 0.25rem;
}

.anhoej-box-value {
  font-size: 1.4rem;
  font-weight: 700;
}

.anhoej-box.status-ok {
  background: rgba(25, 135, 84, 0.1);
  border: 1px solid rgba(25, 135, 84, 0.3);
}

.anhoej-box.status-ok .anhoej-box-value { color: #198754; }

.anhoej-box.status-warning {
  background: rgba(255, 152, 0, 0.1);
  border: 1px solid rgba(255, 152, 0, 0.3);
}

.anhoej-box.status-warning .anhoej-box-value { color: #ff9800; }

/* === RESPONSIVE (follow-up, basic support) === */
/* Detaljeret responsive design er out-of-scope for v1.
   Desktop-first, tablet/mobil håndteres i separat task. */
```

- [ ] **Step 2: Verificér filen er syntaktisk korrekt**

Run: `cat inst/app/www/wizard.css | head -5`

- [ ] **Step 3: Commit**

```bash
git add inst/app/www/wizard.css && git commit -m "feat(ui): tilføj wizard.css med step indicator og layout styling"
```

---

## Task 2: Opret mod_wizard_upload.R (Trin 1)

**Files:**
- Create: `R/mod_wizard_upload.R`
- Test: `tests/testthat/test-mod_wizard_upload.R`

- [ ] **Step 1: Skriv test**

```r
# tests/testthat/test-mod_wizard_upload.R
test_that("wizard_upload_ui returnerer valid tagList", {
  ui <- wizard_upload_ui()
  expect_s3_class(ui, "shiny.tag.list")
})

test_that("wizard_upload_ui indeholder upload og blank kort", {
  ui <- wizard_upload_ui()
  html <- as.character(ui)
  expect_true(grepl("upload_file_card", html))
  expect_true(grepl("blank_dataset_card", html))
})
```

- [ ] **Step 2: Kør test — skal fejle**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-mod_wizard_upload.R')"`

Expected: FAIL — `wizard_upload_ui` not found

- [ ] **Step 3: Implementér mod_wizard_upload.R**

```r
# R/mod_wizard_upload.R

#' Wizard Trin 1: Upload
#'
#' UI for upload af datafil eller valg af blankt datasæt.
#' Inputs defineres UDEN namespace for at bevare top-level scope.
#'
#' @return tagList med upload-UI
wizard_upload_ui <- function() {
  tagList(
    div(
      class = "d-flex justify-content-center align-items-center gap-4",
      style = "min-height: 60vh;",

      # Upload fil kort
      div(
        id = "upload_file_card",
        class = "upload-card",
        onclick = "document.getElementById('upload').click();",
        div(class = "upload-card-icon", "\U0001F4C1"),
        div(class = "upload-card-title", "Upload datafil"),
        div(class = "upload-card-desc", "CSV eller Excel (.xlsx)"),
        div(
          class = "upload-card-desc mt-2",
          style = "font-size: 0.8rem;",
          "Klik for at vælge fil"
        ),
        # Skjult fileInput
        div(
          style = "display: none;",
          fileInput(
            "upload", NULL,
            accept = c(".csv", ".xlsx", ".xls"),
            buttonLabel = "Vælg",
            placeholder = "Ingen fil valgt"
          )
        )
      ),

      # ELLER divider
      div(class = "upload-divider align-self-center", "ELLER"),

      # Blankt datasæt kort
      div(
        id = "blank_dataset_card",
        class = "upload-card",
        style = "border-style: solid;",
        onclick = "Shiny.setInputValue('start_blank', Date.now());",
        div(class = "upload-card-icon", "\U0001F4CB"),
        div(class = "upload-card-title", "Start med blankt datasæt"),
        div(
          class = "upload-card-desc",
          "Opret standardkolonner og indtast data manuelt"
        )
      )
    )
  )
}

#' Wizard Upload Server
#'
#' Håndterer upload-logik og navigation til Trin 2.
#'
#' @param input Shiny input
#' @param output Shiny output
#' @param session Shiny session
#' @param app_state App state environment
#' @param emit Emit API
wizard_upload_server <- function(input, output, session,
                                 app_state, emit) {
  # Navigér til Trin 2 efter upload
  observeEvent(input$upload, {
    req(input$upload)
    bslib::nav_select("wizard_nav", selected = "step_data")
  }, ignoreInit = TRUE)

  # Navigér til Trin 2 efter blank datasæt
  observeEvent(input$start_blank, {
    bslib::nav_select("wizard_nav", selected = "step_data")
  }, ignoreInit = TRUE)
}
```

- [ ] **Step 4: Kør test — skal bestå**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-mod_wizard_upload.R')"`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add R/mod_wizard_upload.R tests/testthat/test-mod_wizard_upload.R
git commit -m "feat(ui): tilføj mod_wizard_upload — Trin 1 upload/blank"
```

---

## Task 3: Opret mod_wizard_data.R (Trin 2)

**Files:**
- Create: `R/mod_wizard_data.R`
- Test: `tests/testthat/test-mod_wizard_data.R`
- Reference: `R/ui_app_ui.R:202+` (eksisterende kolonne-mapping), `R/ui_app_ui.R:500+` (data tabel)

- [ ] **Step 1: Skriv test**

```r
# tests/testthat/test-mod_wizard_data.R
test_that("wizard_data_ui returnerer valid tagList", {
  ui <- wizard_data_ui()
  expect_s3_class(ui, "shiny.tag.list")
})

test_that("wizard_data_ui indeholder kolonne-mapping inputs", {
  ui <- wizard_data_ui()
  html <- as.character(ui)
  expect_true(grepl("x_column", html))
  expect_true(grepl("y_column", html))
  expect_true(grepl("auto_detect_columns", html))
})

test_that("wizard_data_ui indeholder skift og frys inputs", {
  ui <- wizard_data_ui()
  html <- as.character(ui)
  expect_true(grepl("skift_column", html))
  expect_true(grepl("frys_column", html))
})
```

- [ ] **Step 2: Kør test — skal fejle**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-mod_wizard_data.R')"`

- [ ] **Step 3: Implementér mod_wizard_data.R**

Flyt og reorganisér UI-elementer fra `ui_app_ui.R`:
- Kolonne-mapping dropdowns fra `create_chart_settings_card()` Tab 2
- Skift/Frys selectors fra `create_chart_settings_card()` Tab 2
- Data tabel fra `create_data_table_card()`
- Auto-detect knap

```r
# R/mod_wizard_data.R

#' Wizard Trin 2: Data
#'
#' Kolonne-mapping, data-verifikation og redigering.
#' Inputs defineres UDEN namespace (top-level scope).
wizard_data_ui <- function() {
  tagList(
    # Sektion A: Handlingsknapper
    div(
      class = "d-flex gap-2 mb-3",
      actionButton(
        "auto_detect_columns",
        "Auto-detektér kolonner",
        class = "btn-primary btn-sm"
      ),
      actionButton(
        "show_column_mapping_modal",
        "Angiv manuelt",
        class = "btn-outline-secondary btn-sm"
      )
    ),

    # Sektion B: Kolonne-mapping
    div(
      class = "row g-2 mb-3",
      div(
        class = "col-md-2",
        tags$label("X-akse (Tid)", class = "form-label small fw-bold"),
        selectizeInput(
          "x_column", NULL,
          choices = NULL, options = list(placeholder = "Vælg...")
        )
      ),
      div(
        class = "col-md-2",
        tags$label("Y-akse (Værdi)", class = "form-label small fw-bold"),
        selectizeInput(
          "y_column", NULL,
          choices = NULL, options = list(placeholder = "Vælg...")
        )
      ),
      div(
        class = "col-md-2",
        tags$label("N (Nævner)", class = "form-label small fw-bold"),
        selectizeInput(
          "n_column", NULL,
          choices = NULL, options = list(placeholder = "Valgfri")
        )
      ),
      div(
        class = "col-md-2",
        tags$label("Kommentar", class = "form-label small fw-bold"),
        selectizeInput(
          "kommentar_column", NULL,
          choices = NULL, options = list(placeholder = "Valgfri")
        )
      ),
      div(
        class = "col-md-2",
        tags$label("Skift", class = "form-label small fw-bold"),
        selectizeInput(
          "skift_column", NULL,
          choices = NULL, options = list(placeholder = "Valgfri")
        )
      ),
      div(
        class = "col-md-2",
        tags$label("Frys", class = "form-label small fw-bold"),
        selectizeInput(
          "frys_column", NULL,
          choices = NULL, options = list(placeholder = "Valgfri")
        )
      )
    ),

    # Sektion C: Data tabel
    bslib::card(
      bslib::card_header(
        class = "d-flex justify-content-between align-items-center",
        "Data",
        div(
          class = "d-flex gap-1",
          actionButton("add_column", "Tilføj kolonne",
                       class = "btn-outline-secondary btn-sm"),
          actionButton("edit_column_names", "Rediger kolonnenavne",
                       class = "btn-outline-secondary btn-sm")
        )
      ),
      bslib::card_body(
        uiOutput("data_table_container"),
        div(
          class = "text-muted small mt-1",
          textOutput("data_status_text")
        )
      )
    )
  )
}

#' Wizard Data Server
#'
#' Håndterer kolonne-mapping og data-tabel.
#' Genbruger eksisterende setup_column_management() og
#' setup_data_table() funktioner.
wizard_data_server <- function(input, output, session,
                                app_state, emit) {
  # Server-logik håndteres af eksisterende setup_* funktioner
}
```

- [ ] **Step 4: Kør test — skal bestå**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-mod_wizard_data.R')"`

- [ ] **Step 5: Commit**

```bash
git add R/mod_wizard_data.R tests/testthat/test-mod_wizard_data.R
git commit -m "feat(ui): tilføj mod_wizard_data — Trin 2 kolonne-mapping og tabel"
```

---

## Task 4: Opret mod_wizard_analyse.R (Trin 3)

**Files:**
- Create: `R/mod_wizard_analyse.R`
- Test: `tests/testthat/test-mod_wizard_analyse.R`
- Reference: `R/ui_app_ui.R` (chart settings), `R/mod_spc_chart_ui.R` (visualization module)

- [ ] **Step 1: Skriv test**

```r
# tests/testthat/test-mod_wizard_analyse.R
test_that("wizard_analyse_ui returnerer valid tagList", {
  ui <- wizard_analyse_ui()
  expect_s3_class(ui, "shiny.tag.list")
})

test_that("wizard_analyse_ui har Diagram og Detaljer sub-tabs", {
  ui <- wizard_analyse_ui()
  html <- as.character(ui)
  expect_true(grepl("Diagram", html))
  expect_true(grepl("Detaljer", html))
})

test_that("wizard_analyse_ui indeholder chart config inputs", {
  ui <- wizard_analyse_ui()
  html <- as.character(ui)
  expect_true(grepl("chart_type", html))
  expect_true(grepl("y_axis_unit", html))
  expect_true(grepl("target_value", html))
})

test_that("wizard_analyse_ui indeholder metadata inputs", {
  ui <- wizard_analyse_ui()
  html <- as.character(ui)
  expect_true(grepl("indicator_title", html))
  expect_true(grepl("indicator_description", html))
})
```

- [ ] **Step 2: Kør test — skal fejle**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-mod_wizard_analyse.R')"`

- [ ] **Step 3: Implementér mod_wizard_analyse.R**

```r
# R/mod_wizard_analyse.R

#' Wizard Trin 3: Analyse
#'
#' Sub-tabs Diagram og Detaljer med delt chart preview.
#' Inputs defineres UDEN namespace (top-level scope).
wizard_analyse_ui <- function() {
  # Delt preview-panel (genbruges i begge sub-tabs)
  preview_panel <- function() {
    tagList(
      # Chart preview
      div(
        style = "min-height: 300px;",
        visualizationModuleUI("visualization")
      ),
      # Anhøj rules value boxes
      div(
        class = "mt-3",
        visualizationStatusUI("visualization")
      )
    )
  }

  tagList(
    bslib::navset_tab(
      id = "analyse_subtabs",

      # Sub-tab: Diagram
      bslib::nav_panel(
        title = "Diagram",
        value = "diagram",
        bslib::layout_sidebar(
          sidebar = bslib::sidebar(
            width = 280,
            position = "left",
            class = "analyse-sidebar",
            tags$label("Diagramtype", class = "form-label small fw-bold"),
            selectizeInput(
              "chart_type", NULL,
              choices = NULL
            ),
            tags$label("Y-akse enhed", class = "form-label small fw-bold"),
            selectizeInput(
              "y_axis_unit", NULL,
              choices = c(
                "Tal" = "tal",
                "Procent (%)" = "procent",
                "Rate" = "rate",
                "Tid mellem hændelser" = "tid"
              )
            ),
            tags$label("Udviklingsmål", class = "form-label small fw-bold"),
            textInput(
              "target_value", NULL,
              placeholder = "fx >=90% eller <25"
            ),
            tags$label("Evt. baseline", class = "form-label small fw-bold"),
            textInput(
              "centerline_value", NULL,
              placeholder = "Valgfri"
            )
          ),
          preview_panel()
        )
      ),

      # Sub-tab: Detaljer
      bslib::nav_panel(
        title = "Detaljer",
        value = "detaljer",
        bslib::layout_sidebar(
          sidebar = bslib::sidebar(
            width = 280,
            position = "left",
            class = "analyse-sidebar",
            tags$label("Titel på indikator", class = "form-label small fw-bold"),
            textInput("indicator_title", NULL),
            tags$label("Afdeling / Afsnit", class = "form-label small fw-bold"),
            textInput("indicator_department", NULL),
            tags$label("Datadefinition", class = "form-label small fw-bold"),
            textAreaInput(
              "indicator_description", NULL,
              rows = 3, resize = "vertical"
            ),
            tags$label("Udviklingsmål", class = "form-label small fw-bold"),
            textAreaInput(
              "indicator_improvement_goal", NULL,
              rows = 2, resize = "vertical"
            )
          ),
          preview_panel()
        )
      )
    )
  )
}

#' Wizard Analyse Server
#'
#' Server-logik for chart preview og metadata.
wizard_analyse_server <- function(input, output, session,
                                   app_state, emit) {
  # Chart preview håndteres af eksisterende visualizationModuleServer
  # Metadata skrives til app_state for brug i eksport
  observe({
    app_state$session$indicator_title <- input$indicator_title
    app_state$session$indicator_department <- input$indicator_department
    app_state$session$indicator_description <- input$indicator_description
    app_state$session$indicator_improvement_goal <-
      input$indicator_improvement_goal
  })
}
```

**Duplikeret output ID løsning:** Spike (Task 0, step 2.6) skal afklare om samme output ID kan bruges i to sub-tabs. Hvis ikke, brug separate output IDs:
- Diagram tab: `plotOutput("spc_plot_diagram")` + `uiOutput("anhoej_boxes_diagram")`
- Detaljer tab: `plotOutput("spc_plot_detaljer")` + `uiOutput("anhoej_boxes_detaljer")`

Server-side renderes begge fra samme reaktive kæde. `visualizationModuleServer("visualization")` tilpasses til at outputte til begge containers.

- [ ] **Step 4: Kør test — skal bestå**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-mod_wizard_analyse.R')"`

- [ ] **Step 5: Commit**

```bash
git add R/mod_wizard_analyse.R tests/testthat/test-mod_wizard_analyse.R
git commit -m "feat(ui): tilføj mod_wizard_analyse — Trin 3 diagram og detaljer"
```

---

## Task 4b: Tilføj metadata-felter til state_management.R

**Files:**
- Modify: `R/state_management.R`

- [ ] **Step 1: Tilføj metadata-felter til app_state$session**

I `create_app_state()`, find `app_state$session <- reactiveValues(...)` (linje ~162) og tilføj:

```r
# Metadata fra wizard Trin 3 Detaljer (single source of truth)
indicator_title = NULL,
indicator_department = NULL,
indicator_description = NULL,
indicator_improvement_goal = NULL,
```

- [ ] **Step 2: Commit**

```bash
git add R/state_management.R
git commit -m "feat(state): tilføj metadata-felter til app_state for wizard Trin 3"
```

---

## Task 5: Tilpas mod_export til wizard context (Trin 4)

**Note:** Denne task afhænger af Task 4b (state_management metadata-felter) og Task 7 (server wiring). Tests for export-modulet vil ikke bestå fuldt før Task 7 er gennemført, da `wizard_analyse_server` endnu ikke skriver til `app_state`. Dette er forventet.

**Files:**
- Modify: `R/mod_export_ui.R`
- Modify: `R/mod_export_server.R`
- Test: `tests/testthat/test-mod_export.R` (opdater eksisterende)

- [ ] **Step 1: Identificér metadata-felter der skal fjernes fra export UI**

Læs `R/mod_export_ui.R` og identificér:
- `export_title` (linje ~64-77) → erstat med read-only fra `app_state$session$indicator_title`
- `export_department` (linje ~81-91) → erstat med read-only fra `app_state$session$indicator_department`
- `pdf_description` (linje ~101-113) → erstat med read-only fra `app_state$session$indicator_description`
- `pdf_improvement` (linje ~117-129) → erstat med read-only fra `app_state$session$indicator_improvement_goal`

- [ ] **Step 2: Tilpas mod_export_ui.R**

Erstat input-felter med read-only visning:

```r
# I stedet for textAreaInput("export_title", ...)
div(
  tags$label("Titel", class = "form-label small fw-bold"),
  textOutput(ns("display_title")),
  tags$small(
    class = "text-muted",
    "Redigér under Analyse > Detaljer"
  )
)
```

- [ ] **Step 3: Tilpas mod_export_server.R**

Erstat alle `input$export_title` (og lignende) referencer med `app_state$session$` felter. Der er ~47 referencer der skal ændres i `mod_export_server.R`:

```r
# Mapping af gamle → nye referencer:
# input$export_title → app_state$session$indicator_title
# input$export_department → app_state$session$indicator_department
# input$pdf_description → app_state$session$indicator_description
# input$pdf_improvement → app_state$session$indicator_improvement_goal
```

**Vigtig:** AI suggestion-logikken (linje ~461) bruger `updateTextAreaInput(session, "pdf_improvement", value = suggestion)` til at skrive AI-forslag tilbage. Denne skal ændres til at skrive til `app_state$session$indicator_improvement_goal` i stedet.

Søg og erstat med: `grep -n "export_title\\|export_department\\|pdf_description\\|pdf_improvement" R/mod_export_server.R`

Tilføj display outputs:

```r
output$display_title <- renderText({
  app_state$session$indicator_title %||% "(Ingen titel angivet)"
})
output$display_department <- renderText({
  app_state$session$indicator_department %||% "(Ingen afdeling)"
})
```

- [ ] **Step 4: Kør eksisterende tests**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-mod_export.R')"`

Opdater tests der forventer de gamle input-felter.

- [ ] **Step 5: Commit**

```bash
git add R/mod_export_ui.R R/mod_export_server.R tests/testthat/test-mod_export.R
git commit -m "refactor(export): læs metadata fra app_state, fjern duplikerede felter"
```

---

## Task 6: Omskriv app_ui.R med wizard layout

**Files:**
- Modify: `R/app_ui.R`
- Modify: `R/ui_app_ui.R` (fjern/refaktorér)
- Reference: Alle nye mod_wizard_*.R filer

- [ ] **Step 1: Omskriv app_ui.R**

```r
# R/app_ui.R
#' biSPCharts Application UI
#'
#' @param request Internal parameter for `{shiny}`.
#' @noRd
app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),
    shinyjs::useShinyjs(),

    bslib::page_navbar(
      id = "wizard_nav",
      title = tags$span(
        tags$img(
          src = get_hospital_logo_path(), height = "30px",
          class = "me-2"
        ),
        "biSPCharts"
      ),
      theme = get_bootstrap_theme(),

      # Trin 1: Upload
      bslib::nav_panel(
        title = tags$span(
          tags$span(class = "step-number", "1"),
          "Upload"
        ),
        value = "step_upload",
        wizard_upload_ui()
      ),

      # Trin 2: Data
      bslib::nav_panel(
        title = tags$span(
          tags$span(class = "step-number", "2"),
          "Data"
        ),
        value = "step_data",
        wizard_data_ui()
      ),

      # Trin 3: Analyse
      bslib::nav_panel(
        title = tags$span(
          tags$span(class = "step-number", "3"),
          "Analyse"
        ),
        value = "step_analyse",
        wizard_analyse_ui()
      ),

      # Trin 4: Eksport
      bslib::nav_panel(
        title = tags$span(
          tags$span(class = "step-number", "4"),
          "Eksport"
        ),
        value = "step_export",
        mod_export_ui("export")
      )
    )
  )
}
```

- [ ] **Step 2: Refaktorér ui_app_ui.R**

Behold kun `golem_add_external_resources()`, `app_sys()`, og `get_golem_config()`. Fjern eller arkivér:
- `create_ui_header()` → CSS flyttes til wizard.css / bevares delvist
- `create_ui_main_content()` → erstattet af wizard tabs
- `create_chart_settings_card()` → erstattet af mod_wizard_analyse
- `create_plot_only_card()` → erstattet af mod_wizard_analyse
- `create_status_value_boxes()` → erstattet af mod_wizard_analyse
- `create_data_table_card()` → erstattet af mod_wizard_data
- `create_ui_sidebar()` → erstattet af wizard Trin 1
- `create_welcome_page()` → erstattet af wizard Trin 1

- [ ] **Step 3: Verificér at appen loader**

Run: `Rscript -e "pkgload::load_all(); cat('UI loaded OK\n')"`

- [ ] **Step 4: Commit**

```bash
git add R/app_ui.R R/ui_app_ui.R
git commit -m "refactor(ui): omskriv app_ui.R til 4-trins wizard layout"
```

---

## Task 7: Tilpas app_server_main.R

**Files:**
- Modify: `R/app_server_main.R`

- [ ] **Step 1: Tilføj wizard modul server-kald**

I `main_app_server()`, tilføj efter infrastructure setup:

```r
# Wizard modul servere
wizard_upload_server(input, output, session, app_state, emit)
wizard_data_server(input, output, session, app_state, emit)
wizard_analyse_server(input, output, session, app_state, emit)
```

- [ ] **Step 2: Fjern/tilpas deprecated setup-kald**

Identificér setup-kald der nu er erstattet:
- `setup_welcome_page_handlers()` → fjernes (erstattet af Trin 1)
- Eksisterende `setup_*` funktioner genbruges hvor muligt

**Vigtig:** Bevar `setup_file_upload()`, `setup_data_table()`, `setup_column_management()`, `setup_visualization()` — disse indeholder server-logik der stadig bruges. De læser fra `input$` og `app_state$` som før.

- [ ] **Step 3: Tilpas step indicator validation**

Tilføj observere der opdaterer step-indicator CSS classes:

```r
# Step validation
observe({
  # Trin 1: Data tilgængelig?
  has_data <- !is.null(app_state$data$current_data)
  shinyjs::toggleClass(
    selector = "[data-value='step_upload']",
    class = "step-complete",
    condition = has_data
  )

  # Trin 2: Kolonner mappet?
  has_mapping <- !is.null(app_state$columns$mappings$x_column) &&
    !is.null(app_state$columns$mappings$y_column)
  shinyjs::toggleClass(
    selector = "[data-value='step_data']",
    class = "step-complete",
    condition = has_mapping
  )
})
```

- [ ] **Step 4: Kør app og test manuelt**

Run: `Rscript -e "pkgload::load_all(); run_app()"`

Verificér: Wizard vises, tabs er klikbare, inputs responderer.

- [ ] **Step 5: Commit**

```bash
git add R/app_server_main.R
git commit -m "refactor(server): tilpas app_server_main til wizard modul-servere"
```

---

## Task 8: Tilpas auto-detection adfærd

**Files:**
- Modify: `R/utils_event_context_handlers.R`

- [ ] **Step 1: Fjern auto-trigger i handle_load_context()**

Nuværende kode (linje ~158-172):

```r
handle_load_context <- function(app_state, emit) {
  # ... triggers emit$auto_detection_started() automatisk
}
```

Ændr til at IKKE auto-trigge:

```r
handle_load_context <- function(app_state, emit) {
  log_info(
    component = "[CONTEXT_HANDLER]",
    message = "Load context — auto-detection venter på eksplicit handling"
  )
  emit$navigation_changed()
  emit$visualization_update_needed()
  # Fjernet: emit$auto_detection_started()
}
```

- [ ] **Step 2: Verificér at auto-detect knap stadig virker**

Auto-detect knappen (`input$auto_detect_columns`) trigger allerede `emit$auto_detection_started()` via en eksisterende observer. Bekræft dette ved at søge i kodebasen.

- [ ] **Step 3: Kør eksisterende tests**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`

Verificér at ingen tests fejler pga. den fjernede auto-trigger.

- [ ] **Step 4: Commit**

```bash
git add R/utils_event_context_handlers.R
git commit -m "fix(events): fjern auto-detection auto-trigger ved data upload"
```

---

## Task 9: Integration test og cleanup

**Files:**
- Modify: Various test files
- Remove: Deprecated UI helper functions

- [ ] **Step 1: Kør alle tests**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`

Saml liste over fejlende tests.

- [ ] **Step 2: Ret fejlende tests**

Typiske fixes:
- Tests der refererer til fjernede UI-funktioner (`create_chart_settings_card` osv.)
- Tests der forventer specifikke input-ID'er i bestemte kontekster
- Tests der afhænger af auto-detection auto-trigger

- [ ] **Step 3: Manuel end-to-end test**

Kør appen og test hele flowet:

1. Trin 1: Upload CSV → data indlæses
2. Trin 1: Start blank → tom tabel oprettes
3. Trin 2: Auto-detect → kolonner mappes
4. Trin 2: Manuel mapping → dropdowns virker
5. Trin 2: Rediger tabel → data opdateres
6. Trin 3 Diagram: Vælg chart type → preview opdaterer
7. Trin 3 Diagram: Sæt target → linje vises
8. Trin 3 Detaljer: Udfyld titel → preview opdaterer
9. Trin 4: Vælg PDF → preview vises
10. Trin 4: Download → fil downloades
11. Navigation: Spring frit mellem trin
12. Step indicator: Viser korrekte states

- [ ] **Step 4: Cleanup af deprecated kode**

Fjern ubrugte funktioner fra `ui_app_ui.R`:
- `create_chart_settings_card()`
- `create_plot_only_card()`
- `create_status_value_boxes()`
- `create_data_table_card()`
- `create_ui_sidebar()`
- `create_welcome_page()`

- [ ] **Step 5: Final commit**

```bash
git add -A && git commit -m "refactor(cleanup): fjern deprecated UI helpers, ret tests"
```

---

## Task 10: Review checkpoint

- [ ] **Step 1: Kør alle tests**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`

Expected: 0 failures

- [ ] **Step 2: Verificér performance**

Run: `Rscript -e "system.time(pkgload::load_all())"`

Expected: < 100ms

- [ ] **Step 3: Kør /simplify**

Brug `/simplify` skillen til at reviewe al ændret kode for kvalitet og reuse.

- [ ] **Step 4: Klar til finishing-a-development-branch**

Brug `superpowers:finishing-a-development-branch` til at beslutte merge/PR strategi.
