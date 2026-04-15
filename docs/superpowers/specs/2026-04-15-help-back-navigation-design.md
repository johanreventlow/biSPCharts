# Kontekstuel tilbagenavigation på hjælpesider

**Dato:** 2026-04-15
**Status:** Godkendt
**Branch:** docs/help-information-architecture

## Problem

Når en bruger navigerer til "Lær om SPC" eller "Sådan bruger du appen" — særligt fra forsiden — er der ingen tydelig vej tilbage. Logo-klik virker men er ikke intuitivt. Det bryder flowet for nye brugere.

## Løsning

Tilføj et "← Tilbage" link øverst på begge hjælpesider. Linket navigerer kontekstuelt til den tab brugeren kom fra, tracket via en server-side `reactiveVal`.

## Arkitektur

### Approach: Server-side `previous_tab` tracking

En `reactiveVal` i `app_server_main.R` tracker den forrige tab. Når `input$main_navbar` ændres til en hjælpeside (`app_guide` eller `hjaelp`), gemmes den gamle tab-værdi. Denne `previous_tab` sendes som parameter til begge help-modulers server-funktioner.

### Komponenter

**1. Tab-tracking (`app_server_main.R`)**

- Ny `reactiveVal`: `previous_tab <- reactiveVal("start")`
- `observeEvent(input$main_navbar, ...)` der gemmer den forrige tab-værdi når destinationen er en hjælpeside
- `previous_tab` sendes til `mod_help_server()` og `mod_app_guide_server()` som parameter

**2. UI tilbagelink (`mod_help_ui.R` + `mod_app_guide_ui.R`)**

- Statisk `actionLink` med `id = ns("go_back")` placeret øverst i containeren, før `<h1>`
- Label: `icon("arrow-left")` + "Tilbage"
- Styling: Grå tekst, venstrestillet, `font-size: 0.9rem`, farve fra `get_hospital_colors()$ui_grey_dark`

**3. Server tilbagenavigation (`mod_help_server.R` + `mod_app_guide_server.R`)**

- `observeEvent(input$go_back, ...)` der:
  - Læser `previous_tab()` værdien
  - Navigerer med `bslib::nav_select("main_navbar", selected = previous_tab(), session = parent_session)`
  - Fjerner `wizard-nav-active` CSS-klassen hvis destination er `"start"`

### Data flow

```
User klikker "Lær om SPC" (fra forsiden)
  → observeEvent(input$main_navbar) i app_server_main
  → previous_tab("start") gemmes
  → mod_help_server modtager previous_tab som reactive
  → User ser "← Tilbage" link øverst på siden
  → User klikker tilbagelink
  → nav_select("start") + fjern wizard-nav-active
```

### Edge cases

- **Direkte navbar-klik til hjælp:** Trackes korrekt via `observeEvent(input$main_navbar)`
- **Hjælp → hjælp:** previous_tab peger på den første hjælpeside (korrekt)
- **Refresh/initial load:** `previous_tab` default er `"start"`, så linket virker altid
- **Wizard aktiv:** Hvis brugeren kom fra "Analysér", navigerer tilbagelinket til "Analysér" og wizard-nav forbliver aktiv

## Filer der ændres

| Fil | Ændring |
|---|---|
| `R/app_server_main.R` | Tilføj `previous_tab` reactiveVal + observer + send til moduler |
| `R/mod_help_ui.R` | Tilføj statisk `actionLink` øverst |
| `R/mod_help_server.R` | Tilføj `observeEvent` for back-navigation |
| `R/mod_app_guide_ui.R` | Tilføj statisk `actionLink` øverst |
| `R/mod_app_guide_server.R` | Tilføj/opdater server med back-navigation logik |

## Succeskriterier

- [ ] "← Tilbage" link synlig øverst på begge hjælpesider
- [ ] Fra forsiden → hjælp → tilbage → ender på forsiden (wizard-nav skjules)
- [ ] Fra Analysér → hjælp → tilbage → ender på Analysér (wizard-nav aktiv)
- [ ] Hjælp → hjælp → tilbage → ender på første hjælpeside
- [ ] Diskret grå styling der matcher appens design
- [ ] Ingen regressioner i eksisterende navigation
