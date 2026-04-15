# Hjælp-informationsarkitektur Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adskil SPC-teori og app-vejledning i to separate hjælpesider, tilføj kontekstuel hjælp (info-ikoner + sammenklapbare paneler), og tilføj discoveryability-links på velkomstsiden.

**Architecture:** Den eksisterende `mod_help_ui.R`/`mod_help_server.R` beholdes og renses for app-guide-indhold (sektion 6). En ny `mod_app_guide_ui.R`/`mod_app_guide_server.R` oprettes med detaljeret app-vejledning. Navbar i `app_ui.R` udvides med en ekstra tab. Kontekstuel hjælp tilføjes via `bslib::tooltip()` på Analysér- og Eksportér-siderne. Sammenklapbare paneler tilføjes som `shinyjs::toggle()`-baserede sektioner.

**Tech Stack:** Shiny, bslib (tooltip, value_box), shinyjs (toggle), HTML/CSS

---

### Task 1: Opret ny app-guide modul (mod_app_guide)

**Files:**
- Create: `R/mod_app_guide_ui.R`
- Create: `R/mod_app_guide_server.R`

- [ ] **Step 1: Opret `R/mod_app_guide_server.R`**

```r
# mod_app_guide_server.R
# Server for app-vejledning modul

#' App Guide Module Server
#'
#' Minimal server logik for app-vejledningssiden.
#' Indholdet er statisk, så ingen reaktivitet er nødvendig.
#'
#' @param id Module ID
#' @return NULL (ingen outputs)
#' @export
mod_app_guide_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    NULL
  })
}
```

- [ ] **Step 2: Opret `R/mod_app_guide_ui.R` med indholdsfortegnelse og alle sektioner**

Indhold skal dække:
- Indholdsfortegnelse med ankerlinks
- **Overblik**: Kort opsummering af 3-trins flowet (Upload → Analysér → Eksportér)
- **Trin 1: Upload data**: De 4 inputmetoder (kopiér/indsæt, XLS/CSV, eksempeldata, blank session), dataformat-krav, download af Excel-skabelon
- **Trin 2: Analysér**: Kolonne-mappings (X-akse, Y-akse, Nævner, Skift, Frys, Kommentar), diagramtyper og hvornår man bruger hvilken, indstillinger (Y-akse enhed, udviklingsmål, baseline), aflæsning af value boxes (serielængde, antal kryds, kontrolgrænser)
- **Trin 3: Eksportér**: PDF vs PNG, udfyldning af metadata (titel, hospital, afdeling), datadefinition, analyse af processen, AI-genereret analyse
- **Tips**: Hvad gør "Gem kopi af data og indstillinger", session-restore

```r
# mod_app_guide_ui.R
# App-vejledning: Sådan bruger du appen

#' App Guide Module UI
#'
#' Detaljeret vejledning til brug af biSPCharts-appen.
#' Dækker alle tre trin: Upload, Analysér, Eksportér.
#'
#' @param id Character. Namespace ID for modulet
#' @return Shiny UI element
#' @export
mod_app_guide_ui <- function(id) {
  ns <- shiny::NS(id)

  shiny::div(
    class = "container-fluid",
    style = "max-width: 900px; margin: 0 auto; padding: 30px 20px;",

    # Indholdsfortegnelse
    shiny::div(
      class = "card mb-4",
      shiny::div(
        class = "card-body",
        shiny::tags$h5("Indhold", class = "card-title"),
        shiny::tags$ol(
          style = "margin-bottom: 0;",
          shiny::tags$li(shiny::tags$a(href = "#guide-overblik", "Overblik")),
          shiny::tags$li(shiny::tags$a(href = "#guide-upload", "Trin 1: Upload data")),
          shiny::tags$li(shiny::tags$a(href = "#guide-analyser", "Trin 2: Analys\u00e9r")),
          shiny::tags$li(shiny::tags$a(href = "#guide-eksporter", "Trin 3: Eksport\u00e9r")),
          shiny::tags$li(shiny::tags$a(href = "#guide-tips", "Tips og genveje"))
        )
      )
    ),

    # Sektion 1: Overblik
    shiny::tags$section(
      id = "guide-overblik",
      shiny::tags$h2("Overblik"),
      shiny::tags$p(
        "biSPCharts guider dig igennem tre trin:"
      ),
      shiny::tags$ol(
        shiny::tags$li(
          shiny::tags$strong("Upload"),
          " \u2014 Indl\u00e6s dine data fra Excel, CSV, eller direkte fra et regneark."
        ),
        shiny::tags$li(
          shiny::tags$strong("Analys\u00e9r"),
          " \u2014 V\u00e6lg kolonner og diagramtype. Appen beregner automatisk centrallinjer, ",
          "kontrolgr\u00e6nser og signaldetektion."
        ),
        shiny::tags$li(
          shiny::tags$strong("Eksport\u00e9r"),
          " \u2014 Tilf\u00f8j metadata og download dit diagram som PDF eller PNG i regionalt layout."
        )
      ),
      shiny::tags$p(
        "Du kan frit navigere mellem trinnene via fanerne i toppen."
      ),
      shiny::tags$hr()
    ),

    # Sektion 2: Upload
    shiny::tags$section(
      id = "guide-upload",
      shiny::tags$h2("Trin 1: Upload data"),
      shiny::tags$p("Der er fire m\u00e5der at f\u00e5 data ind i appen:"),
      shiny::tags$div(
        class = "row mb-3",
        shiny::tags$div(
          class = "col-md-6",
          shiny::tags$div(
            class = "card h-100",
            shiny::tags$div(
              class = "card-body",
              shiny::tags$h5("Kopi\u00e9r & Inds\u00e6t", class = "card-title"),
              shiny::tags$p(
                class = "card-text",
                "Marker dine data i Excel og tryk Ctrl+C. Klik i tekstfeltet i appen og tryk Ctrl+V. ",
                "Husk at inkludere kolonneoverskrifterne i f\u00f8rste r\u00e6kke."
              )
            )
          )
        ),
        shiny::tags$div(
          class = "col-md-6",
          shiny::tags$div(
            class = "card h-100",
            shiny::tags$div(
              class = "card-body",
              shiny::tags$h5("Indl\u00e6s XLS/CSV", class = "card-title"),
              shiny::tags$p(
                class = "card-text",
                "Upload en fil direkte fra din computer. Appen underst\u00f8tter .csv, .xls og .xlsx formater."
              )
            )
          )
        )
      ),
      shiny::tags$div(
        class = "row mb-3",
        shiny::tags$div(
          class = "col-md-6",
          shiny::tags$div(
            class = "card h-100",
            shiny::tags$div(
              class = "card-body",
              shiny::tags$h5("Pr\u00f8v med eksempeldata", class = "card-title"),
              shiny::tags$p(
                class = "card-text",
                "Pr\u00f8v appen med foruddefinerede datas\u00e6t. Godt til at l\u00e6re appen at kende ",
                "f\u00f8r du bruger egne data."
              )
            )
          )
        ),
        shiny::tags$div(
          class = "col-md-6",
          shiny::tags$div(
            class = "card h-100",
            shiny::tags$div(
              class = "card-body",
              shiny::tags$h5("Blank session", class = "card-title"),
              shiny::tags$p(
                class = "card-text",
                "Start med en tom tabel og indtast data manuelt direkte i appen."
              )
            )
          )
        )
      ),
      shiny::tags$h4("Dataformat"),
      shiny::tags$p(
        "Dine data skal v\u00e6re organiseret i kolonner med en overskriftsrække. Minimum krav:"
      ),
      shiny::tags$ul(
        shiny::tags$li(
          shiny::tags$strong("Tidspunkt/r\u00e6kkef\u00f8lge"),
          " \u2014 en kolonne med datoer, uger, m\u00e5neder eller l\u00f8benumre (bruges som X-akse)"
        ),
        shiny::tags$li(
          shiny::tags$strong("V\u00e6rdi"),
          " \u2014 en kolonne med den numeriske v\u00e6rdi der skal f\u00f8lges (bruges som Y-akse)"
        )
      ),
      shiny::tags$p(
        "Derudover kan du have kolonner for n\u00e6vner (til andele/rater), skift, frys og kommentarer. ",
        "Du kan ogs\u00e5 downloade en tom Excel-skabelon fra Upload-siden."
      ),
      shiny::tags$hr()
    ),

    # Sektion 3: Analysér
    shiny::tags$section(
      id = "guide-analyser",
      shiny::tags$h2("Trin 2: Analys\u00e9r"),
      shiny::tags$p(
        "N\u00e5r data er indl\u00e6st, fors\u00f8ger appen at detektere dine kolonner automatisk. ",
        "Du kan altid justere tildelingerne manuelt."
      ),
      shiny::tags$h4("Kolonnetildelinger"),
      shiny::tags$table(
        class = "table table-striped",
        shiny::tags$thead(
          shiny::tags$tr(
            shiny::tags$th("Felt"),
            shiny::tags$th("Beskrivelse"),
            shiny::tags$th("P\u00e5kr\u00e6vet?")
          )
        ),
        shiny::tags$tbody(
          shiny::tags$tr(
            shiny::tags$td("X-akse"),
            shiny::tags$td("Tidspunkt eller observationsnummer (fx dato, uge, m\u00e5ned)"),
            shiny::tags$td("Ja")
          ),
          shiny::tags$tr(
            shiny::tags$td("Y-akse"),
            shiny::tags$td("Den v\u00e6rdi der skal f\u00f8lges (fx antal, ventetid, score)"),
            shiny::tags$td("Ja")
          ),
          shiny::tags$tr(
            shiny::tags$td("N\u00e6vner (n)"),
            shiny::tags$td("Brug denne hvis du arbejder med andele eller rater (fx infektioner pr. 100 patienter)"),
            shiny::tags$td("Kun ved P-/U-kort")
          ),
          shiny::tags$tr(
            shiny::tags$td("Skift"),
            shiny::tags$td(
              "Opdeler diagrammet i faser ved kendte proces\u00e6ndringer. ",
              "Kolonne med TRUE/1 markerer hvor en ny fase starter. ",
              "Tilf\u00f8jes automatisk hvis kolonnen mangler."
            ),
            shiny::tags$td("Nej")
          ),
          shiny::tags$tr(
            shiny::tags$td("Frys"),
            shiny::tags$td(
              "L\u00e5ser kontrolgr\u00e6nser baseret p\u00e5 en baseline-periode. ",
              "Kolonne med TRUE/1 markerer baseline-punkterne. ",
              "S\u00e5 kan du se om nye data afviger fra det historiske niveau."
            ),
            shiny::tags$td("Nej")
          ),
          shiny::tags$tr(
            shiny::tags$td("Kommentar"),
            shiny::tags$td("Valgfri kolonne med noter der vises p\u00e5 diagrammet"),
            shiny::tags$td("Nej")
          )
        )
      ),
      shiny::tags$h4("Diagramtyper"),
      shiny::tags$table(
        class = "table table-striped",
        shiny::tags$thead(
          shiny::tags$tr(
            shiny::tags$th("Type"),
            shiny::tags$th("Bruges n\u00e5r"),
            shiny::tags$th("Kr\u00e6ver n\u00e6vner?")
          )
        ),
        shiny::tags$tbody(
          shiny::tags$tr(
            shiny::tags$td("Seriediagram (Run)"),
            shiny::tags$td("Den simpleste type \u2014 start altid her. Bruger medianen som centrallinje."),
            shiny::tags$td("Nej")
          ),
          shiny::tags$tr(
            shiny::tags$td("I-kort"),
            shiny::tags$td("Individuelle m\u00e5linger (fx ventetid, temperatur). Tilf\u00f8jer kontrolgr\u00e6nser."),
            shiny::tags$td("Nej")
          ),
          shiny::tags$tr(
            shiny::tags$td("P-kort"),
            shiny::tags$td("Andele/procenter (fx andel patienter med komplikation)"),
            shiny::tags$td("Ja")
          ),
          shiny::tags$tr(
            shiny::tags$td("U-kort"),
            shiny::tags$td("Rater (fx infektioner per 1000 plejedage)"),
            shiny::tags$td("Ja")
          ),
          shiny::tags$tr(
            shiny::tags$td("C-kort"),
            shiny::tags$td("T\u00e6llinger (fx antal fald per m\u00e5ned)"),
            shiny::tags$td("Nej")
          )
        )
      ),
      shiny::tags$h4("Indstillinger"),
      shiny::tags$ul(
        shiny::tags$li(
          shiny::tags$strong("Y-akse enhed:"),
          " V\u00e6lg om v\u00e6rdierne er tal, procent, eller promille."
        ),
        shiny::tags$li(
          shiny::tags$strong("Udviklingsm\u00e5l:"),
          " Tilf\u00f8j en vandret m\u00e5llinje p\u00e5 diagrammet. P\u00e5virker ikke beregninger."
        ),
        shiny::tags$li(
          shiny::tags$strong("Baseline:"),
          " Angiv en baseline-periode (fx de f\u00f8rste 22 punkter). Centrallinjen og kontrolgr\u00e6nserne ",
          "beregnes kun ud fra baseline-perioden."
        )
      ),
      shiny::tags$h4("Afl\u00e6sning af resultater"),
      shiny::tags$p(
        "Under diagrammet vises tre v\u00e6rdibokse med resultater fra Anh\u00f8j-reglerne:"
      ),
      shiny::tags$ul(
        shiny::tags$li(
          shiny::tags$strong("Seriel\u00e6ngde:"),
          " Viser den l\u00e6ngste serie af punkter p\u00e5 samme side af centrallinjen. ",
          "Hvis det faktiske tal overstiger det forventede, er der tegn p\u00e5 et skift i processen."
        ),
        shiny::tags$li(
          shiny::tags$strong("Antal kryds:"),
          " Viser hvor mange gange linjen krydser centrallinjen. ",
          "Hvis det faktiske tal er lavere end det forventede, er der tegn p\u00e5 clustering i data."
        ),
        shiny::tags$li(
          shiny::tags$strong("Uden for kontrolgr\u00e6nser:"),
          " Antal punkter der ligger uden for kontrolgr\u00e6nserne (kun relevant for kontroldiagrammer, ikke seriediagrammer)."
        )
      ),
      shiny::tags$p(
        "Boksene skifter farve n\u00e5r der er et signal: gr\u00e5 betyder ingen signal, farvet betyder signal detekteret."
      ),
      shiny::tags$hr()
    ),

    # Sektion 4: Eksportér
    shiny::tags$section(
      id = "guide-eksporter",
      shiny::tags$h2("Trin 3: Eksport\u00e9r"),
      shiny::tags$p(
        "P\u00e5 eksportsiden kan du tilf\u00f8je metadata til dit diagram og downloade det i regionalt layout."
      ),
      shiny::tags$h4("Format"),
      shiny::tags$ul(
        shiny::tags$li(
          shiny::tags$strong("PDF:"),
          " Fuld rapport med titel, hospital, afdeling, datadefinition og analyse. Klar til print eller deling."
        ),
        shiny::tags$li(
          shiny::tags$strong("PNG:"),
          " Billedfil til inds\u00e6ttelse i pr\u00e6sentationer eller dokumenter."
        )
      ),
      shiny::tags$h4("Felter"),
      shiny::tags$ul(
        shiny::tags$li(
          shiny::tags$strong("Titel:"),
          " En kort titel eller konklusion der opsummerer hvad diagrammet viser."
        ),
        shiny::tags$li(
          shiny::tags$strong("Hospital/Afdeling:"),
          " Udfyldes automatisk med hospitalsnavn. Tilf\u00f8j din afdeling."
        ),
        shiny::tags$li(
          shiny::tags$strong("Datadefinition:"),
          " Beskriv hvad indikatoren m\u00e5ler og hvordan data er opgjort. ",
          "Fx: \u201cAndel patienter m\u00f8dt til ambulant aftale (m\u00f8dt/tilkaldt), opgjort m\u00e5nedligt.\u201d"
        ),
        shiny::tags$li(
          shiny::tags$strong("Analyse af processen:"),
          " Beskriv hvad diagrammet viser \u2014 er processen stabil? Er der signaler? ",
          "Hvad kan forklare eventuelle udsving? Feltet auto-udfyldes, men b\u00f8r redigeres."
        )
      ),
      shiny::tags$p(
        "Du kan bruge ", shiny::tags$strong("AI-funktionen"),
        " til at generere et udkast til analyseteksten baseret p\u00e5 dine data. ",
        "Teksten b\u00f8r altid genneml\u00e6ses og redigeres."
      ),
      shiny::tags$hr()
    ),

    # Sektion 5: Tips
    shiny::tags$section(
      id = "guide-tips",
      shiny::tags$h2("Tips og genveje"),
      shiny::tags$ul(
        shiny::tags$li(
          shiny::tags$strong("Gem kopi:"),
          " Klik \u201cGem kopi af data og indstillinger\u201d for at gemme dit arbejde lokalt i browseren. ",
          "N\u00e6ste gang du \u00e5bner appen, kan du forts\u00e6tte hvor du slap."
        ),
        shiny::tags$li(
          shiny::tags$strong("Rediger data direkte:"),
          " Du kan redigere data i tabellen p\u00e5 Analys\u00e9r-siden. Klik p\u00e5 en celle for at \u00e6ndre v\u00e6rdien."
        ),
        shiny::tags$li(
          shiny::tags$strong("Tilf\u00f8j kolonner:"),
          " Brug \u201c+ Kolonne\u201d-knappen til at tilf\u00f8je Skift- eller Frys-kolonner, ",
          "hvis de ikke allerede er i dine data."
        ),
        shiny::tags$li(
          shiny::tags$strong("Omd\u00f8b kolonner:"),
          " Brug \u201cOmd\u00f8b\u201d-knappen til at give kolonnerne mere beskrivende navne."
        ),
        shiny::tags$li(
          shiny::tags$strong("Pr\u00f8v eksempeldata f\u00f8rst:"),
          " Hvis du er ny, s\u00e5 start med et af eksempeldatas\u00e6ttene for at l\u00e6re appen at kende."
        )
      )
    )
  )
}
```

- [ ] **Step 3: Kør `devtools::document()` for at opdatere NAMESPACE**

Run: `Rscript -e "devtools::document()"`

- [ ] **Step 4: Commit**

```bash
git add R/mod_app_guide_ui.R R/mod_app_guide_server.R NAMESPACE
git commit -m "feat: opret ny app-vejledningsmodul (mod_app_guide)"
```

---

### Task 2: Tilføj app-guide tab i navbar

**Files:**
- Modify: `R/app_ui.R:111-117` (tilføj ny nav_panel før "Lær om SPC")
- Modify: `R/app_ui.R:16-38` (tilføj CSS for den nye tab i wizard-nav)
- Modify: `R/app_server_main.R` (tilføj `mod_app_guide_server` kald)

- [ ] **Step 1: Tilføj CSS-regler for den nye `app_guide` tab i `R/app_ui.R`**

Tilføj `'app_guide'` i samme mønster som de eksisterende tabs i CSS-blokken (linje 16-38). Tilføj `, .navbar .nav-link[data-value='app_guide']` og tilsvarende `.navbar .nav-item:has(.nav-link[data-value='app_guide'])` i alle tre CSS-blokke (hide, show flex, show block).

- [ ] **Step 2: Tilføj ny `nav_panel` i `R/app_ui.R` før "Lær om SPC"**

Indsæt mellem linje 110 og 111 (før den eksisterende hjælp-panel):

```r
      # App-vejledning (adskilt fra wizard-flow)
      bslib::nav_panel(
        title = "S\u00e5dan bruger du appen",
        icon = shiny::icon("circle-question"),
        value = "app_guide",
        mod_app_guide_ui("app_guide")
      ),
```

- [ ] **Step 3: Tilføj server-kald i `R/app_server_main.R`**

Find hvor `mod_help_server("help")` kaldes og tilføj lige før:

```r
  mod_app_guide_server("app_guide")
```

- [ ] **Step 4: Verificér at appen starter korrekt**

Run: `Rscript -e "library(biSPCharts); print('Load OK')"`

- [ ] **Step 5: Commit**

```bash
git add R/app_ui.R R/app_server_main.R
git commit -m "feat: tilf\u00f8j app-vejledning tab i navbar"
```

---

### Task 3: Rens "Lær om SPC" for app-guide indhold

**Files:**
- Modify: `R/mod_help_ui.R:26-34` (fjern punkt 6 fra indholdsfortegnelse)
- Modify: `R/mod_help_ui.R:297-345` (fjern sektion 6 "Sådan bruger du appen")

- [ ] **Step 1: Fjern punkt 6 fra indholdsfortegnelsen i `R/mod_help_ui.R`**

Fjern linje 32:
```r
          shiny::tags$li(shiny::tags$a(href = "#app-vejledning", "S\u00e5dan bruger du appen")),
```

Og opdatér nummereringen i den resterende liste (punkt 7 "Gode råd" bliver punkt 6, punkt 8 "Videre læsning" bliver punkt 7).

- [ ] **Step 2: Fjern sektion 6 (app-vejledning) fra `R/mod_help_ui.R`**

Fjern hele `shiny::tags$section(id = "app-vejledning", ...)` blokken (linje 298-345 ca.).

- [ ] **Step 3: Verificér at "Lær om SPC" stadig renderer korrekt**

Run: `Rscript -e "library(biSPCharts); print('Load OK')"`

- [ ] **Step 4: Commit**

```bash
git add R/mod_help_ui.R
git commit -m "refactor: fjern app-guide indhold fra L\u00e6r om SPC-siden"
```

---

### Task 4: Tilføj discoveryability-links på velkomstsiden

**Files:**
- Modify: `R/mod_landing_ui.R:72-78` (tilføj links under "Kom i gang"-knappen)
- Modify: `R/mod_landing_server.R` (tilføj click handlers for de to links)

- [ ] **Step 1: Tilføj links under "Kom i gang"-knappen i `R/mod_landing_ui.R`**

Tilføj efter `actionButton(ns("start_wizard"), ...)` (efter linje 77):

```r
    # Discoveryability links
    shiny::div(
      style = paste0(
        "margin-top: 16px; font-size: 0.9rem; color: ", muted_color, ";"
      ),
      "Ny her? ",
      shiny::tags$a(
        href = "#",
        onclick = sprintf(
          "Shiny.setInputValue('%s', Math.random()); return false;",
          ns("goto_app_guide")
        ),
        style = "text-decoration: underline;",
        "S\u00e5dan bruger du appen"
      ),
      " \u00b7 ",
      shiny::tags$a(
        href = "#",
        onclick = sprintf(
          "Shiny.setInputValue('%s', Math.random()); return false;",
          ns("goto_spc")
        ),
        style = "text-decoration: underline;",
        "L\u00e6r om SPC"
      )
    )
```

- [ ] **Step 2: Tilføj click handlers i `R/mod_landing_server.R`**

I server-funktionen (efter den eksisterende `start_wizard` observer), tilføj:

```r
    # Navigation til hjælpesider fra landing
    shiny::observeEvent(input$goto_app_guide, {
      bslib::nav_select("main_nav", selected = "app_guide", session = parent_session)
    })

    shiny::observeEvent(input$goto_spc, {
      bslib::nav_select("main_nav", selected = "hjaelp", session = parent_session)
    })
```

Bemærk: Tjek at `mod_landing_server` har adgang til `parent_session` (den overordnede session) for at skifte navbar-tab. Hvis den ikke allerede har det, skal `session` parameteret fra `app_server_main.R` videregives.

- [ ] **Step 3: Tilføj tilsvarende links i restore-landing (`landing_restore_ui`)**

Tilføj de samme discoveryability-links efter knap-gruppen (linje 165 ca.), med samme styling men placeret under kortets bund:

```r
    # Discoveryability links (efter restore-kortet)
    shiny::div(
      style = paste0(
        "margin-top: 16px; font-size: 0.9rem; color: ", muted_color, ";"
      ),
      "Ny her? ",
      shiny::tags$a(
        href = "#",
        onclick = sprintf(
          "Shiny.setInputValue('%s', Math.random()); return false;",
          ns("goto_app_guide")
        ),
        style = "text-decoration: underline;",
        "S\u00e5dan bruger du appen"
      ),
      " \u00b7 ",
      shiny::tags$a(
        href = "#",
        onclick = sprintf(
          "Shiny.setInputValue('%s', Math.random()); return false;",
          ns("goto_spc")
        ),
        style = "text-decoration: underline;",
        "L\u00e6r om SPC"
      )
    )
```

- [ ] **Step 4: Commit**

```bash
git add R/mod_landing_ui.R R/mod_landing_server.R
git commit -m "feat: tilf\u00f8j discoveryability-links p\u00e5 velkomstsiden"
```

---

### Task 5: Tilføj sammenklapbare hjælpepaneler på Analysér- og Eksportér-siderne

**Files:**
- Modify: `R/ui_app_ui.R` (tilføj sammenklapbart panel øverst på analysér-siden)
- Modify: `R/mod_export_ui.R` (tilføj sammenklapbart panel øverst på eksport-indstillinger)

- [ ] **Step 1: Tilføj sammenklapbart panel på Analysér-siden i `R/ui_app_ui.R`**

Tilføj øverst i analysér-tab-indholdet (lige efter `bslib::layout_columns(` starter, men _over_ den eksisterende 6-6 grid):

```r
      # Sammenklapbar hjælp
      shiny::div(
        id = "analyser_help_panel",
        class = "mb-2",
        shiny::tags$button(
          class = "btn btn-sm btn-link text-muted p-0",
          style = "text-decoration: none; font-size: 0.85rem;",
          onclick = "$('#analyser_help_content').slideToggle(200); $(this).find('.chevron-icon').toggleClass('fa-chevron-down fa-chevron-up');",
          shiny::icon("chevron-down", class = "chevron-icon", style = "font-size: 0.7em; margin-right: 4px;"),
          "Hj\u00e6lp til dette trin"
        ),
        shiny::div(
          id = "analyser_help_content",
          style = "display: none;",
          shiny::div(
            class = "alert alert-light border mt-1 mb-0",
            style = "font-size: 0.85rem; padding: 10px 14px;",
            shiny::tags$p(
              class = "mb-1",
              shiny::tags$strong("1."), " Tjek at kolonnerne er tildelt korrekt (X-akse, Y-akse, evt. n\u00e6vner)."
            ),
            shiny::tags$p(
              class = "mb-1",
              shiny::tags$strong("2."), " V\u00e6lg diagramtype. Start med seriediagram hvis du er i tvivl."
            ),
            shiny::tags$p(
              class = "mb-0",
              shiny::tags$strong("3."), " Tjek v\u00e6rdiboksene under diagrammet \u2014 de viser om der er signaler i dine data."
            )
          )
        )
      ),
```

- [ ] **Step 2: Tilføj sammenklapbart panel på Eksportér-siden i `R/mod_export_ui.R`**

Tilføj øverst i eksport-indstillinger panelet (lige efter `card_header`):

```r
        # Sammenklapbar hjælp
        shiny::div(
          class = "mb-2",
          shiny::tags$button(
            class = "btn btn-sm btn-link text-muted p-0",
            style = "text-decoration: none; font-size: 0.85rem;",
            onclick = "$('#eksporter_help_content').slideToggle(200); $(this).find('.chevron-icon').toggleClass('fa-chevron-down fa-chevron-up');",
            shiny::icon("chevron-down", class = "chevron-icon", style = "font-size: 0.7em; margin-right: 4px;"),
            "Hj\u00e6lp til dette trin"
          ),
          shiny::div(
            id = "eksporter_help_content",
            style = "display: none;",
            shiny::div(
              class = "alert alert-light border mt-1 mb-0",
              style = "font-size: 0.85rem; padding: 10px 14px;",
              shiny::tags$p(
                class = "mb-1",
                shiny::tags$strong("1."), " V\u00e6lg format (PDF for rapporter, PNG for pr\u00e6sentationer)."
              ),
              shiny::tags$p(
                class = "mb-1",
                shiny::tags$strong("2."), " Skriv en kort titel der opsummerer hvad diagrammet viser."
              ),
              shiny::tags$p(
                class = "mb-1",
                shiny::tags$strong("3."), " Udfyld datadefinition og analyse af processen."
              ),
              shiny::tags$p(
                class = "mb-0",
                shiny::tags$strong("Tip:"), " Brug AI-funktionen til at generere et udkast til analyseteksten, og redig\u00e9r derefter."
              )
            )
          )
        ),
```

- [ ] **Step 3: Commit**

```bash
git add R/ui_app_ui.R R/mod_export_ui.R
git commit -m "feat: tilf\u00f8j sammenklapbare hj\u00e6lpepaneler p\u00e5 Analys\u00e9r og Eksport\u00e9r"
```

---

### Task 6: Tilføj og kvalitetssikr info-ikoner (tooltips) på Analysér-siden

**Files:**
- Modify: `R/utils_spc_chart_ui_helpers.R:140-141` (kvalitetssikr serielængde tooltip)
- Modify: `R/utils_spc_chart_ui_helpers.R:196-199` (kvalitetssikr antal kryds tooltip)
- Modify: `R/utils_spc_chart_ui_helpers.R:258-261` (kvalitetssikr kontrolgrænser tooltip)
- Modify: `R/ui_app_ui.R` (tilføj tooltip ved Udviklingsmål-felt)

- [ ] **Step 1: Kvalitetssikr serielængde tooltip i `R/utils_spc_chart_ui_helpers.R`**

Eksisterende tooltip tekst (linje 141):
```
"Længste serie af punkter på samme side af centerlinjen. Hvis den overstiger grænsen, kan der være en systematisk ændring i processen."
```

Opdatér til:
```
"Antal på hinanden følgende punkter på samme side af centrallinjen. Hvis det faktiske tal overstiger det forventede, er der tegn på et skift i processen."
```

- [ ] **Step 2: Kvalitetssikr antal kryds tooltip i `R/utils_spc_chart_ui_helpers.R`**

Eksisterende tooltip tekst (linje 199):
```
"Antal gange datapunkterne krydser centerlinjen. For få krydsninger kan tyde på trends eller skift i processen."
```

Opdatér til:
```
"Antal gange linjen krydser centrallinjen. Hvis det faktiske tal er lavere end det forventede, er der tegn på clustering eller trends i data."
```

- [ ] **Step 3: Kvalitetssikr kontrolgrænser tooltip i `R/utils_spc_chart_ui_helpers.R`**

Eksisterende tooltip tekst (linje 260):
```
"Antal datapunkter der ligger uden for kontrolgrænserne. Disse punkter kan indikere særlige årsager til variation."
```

Opdatér til:
```
"Antal datapunkter der ligger uden for kontrolgrænserne. Disse punkter er stærke signaler om særlig variation. Kun relevant for kontroldiagrammer (I-/P-/U-/C-kort)."
```

- [ ] **Step 4: Tilføj info-ikon ved Udviklingsmål i `R/ui_app_ui.R`**

Find feltet for Udviklingsmål (`numericInput` med `target_value` eller lignende) og tilføj en tooltip:

```r
shiny::div(
  shiny::tags$label(
    "Udviklingsmål:",
    shiny::icon("circle-info", style = "font-size: 0.8em; opacity: 0.6; margin-left: 4px;") |>
      bslib::tooltip("En vandret linje der viser jeres målsætning. Påvirker ikke beregninger eller signaldetektion.")
  ),
  # eksisterende numericInput...
)
```

- [ ] **Step 5: Commit**

```bash
git add R/utils_spc_chart_ui_helpers.R R/ui_app_ui.R
git commit -m "fix: kvalitetssikr og ensret tooltip-tekster p\u00e5 Analys\u00e9r-siden"
```

---

### Task 7: Tilføj info-ikoner (tooltips) på Eksportér-siden

**Files:**
- Modify: `R/mod_export_ui.R:177-181` (tilføj tooltip ved Datadefinition)
- Modify: `R/mod_export_ui.R:193-197` (tilføj tooltip ved Analyse af processen)

- [ ] **Step 1: Tilføj info-ikon ved Datadefinition i `R/mod_export_ui.R`**

Erstat label-teksten `"Datadefinition:"` med:

```r
shiny::tagList(
  "Datadefinition:",
  shiny::icon("circle-info", style = "font-size: 0.8em; opacity: 0.6; margin-left: 4px;") |>
    bslib::tooltip(
      "Beskriv hvad indikatoren m\u00e5ler og hvordan data er opgjort. Fx: \u201cAndel patienter m\u00f8dt til ambulant aftale (m\u00f8dt/tilkaldt), opgjort m\u00e5nedligt.\u201d"
    )
)
```

- [ ] **Step 2: Tilføj info-ikon ved Analyse af processen i `R/mod_export_ui.R`**

Erstat label-teksten `"Analyse af processen:"` med:

```r
shiny::tagList(
  "Analyse af processen:",
  shiny::icon("circle-info", style = "font-size: 0.8em; opacity: 0.6; margin-left: 4px;") |>
    bslib::tooltip(
      "Beskriv hvad diagrammet viser \u2014 er processen stabil? Er der signaler? Hvad kan forklare eventuelle udsving?"
    )
)
```

- [ ] **Step 3: Commit**

```bash
git add R/mod_export_ui.R
git commit -m "feat: tilf\u00f8j info-ikoner ved Datadefinition og Analyse p\u00e5 Eksport\u00e9r-siden"
```

---

### Task 8: Manuel verifikation og final commit

**Files:**
- Ingen nye filer

- [ ] **Step 1: Start appen lokalt og verificér**

Run: `Rscript -e "biSPCharts::run_app()"`

Tjek:
1. Velkomstsiden viser "Ny her?" links under "Kom i gang"
2. Klik på "Sådan bruger du appen" navigerer til den nye side
3. Klik på "Lær om SPC" navigerer til SPC-teorisiden
4. "Lær om SPC" indeholder IKKE sektion 6 (app-vejledning)
5. Navbar har begge nye tabs synlige
6. Analysér-siden har "Hjælp til dette trin" panel der folder ud
7. Eksportér-siden har "Hjælp til dette trin" panel der folder ud
8. Tooltips virker på value boxes, Udviklingsmål, Datadefinition, Analyse
9. Tooltip-tekster er korrekte og ensrettede

- [ ] **Step 2: Kør `devtools::document()` og tjek for advarsler**

Run: `Rscript -e "devtools::document()"`

- [ ] **Step 3: Kør eksisterende tests**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`

- [ ] **Step 4: Final commit hvis der er yderligere ændringer**

```bash
git add -A
git commit -m "chore: final verifikation af hj\u00e6lp-informationsarkitektur"
```
