# SPCify Wizard Workflow — Design Specification

**Dato:** 2026-03-21
**Status:** Approved (spec review passed)
**Inspiration:** [Datawrapper](https://www.datawrapper.de) step-by-step chart creation workflow

---

## 1. Motivation

SPCify's nuværende UI viser alt samtidigt på én fane: data-tabel, kolonne-mapping, chart-type, preview og konfiguration. Det kan føles overvældende, særligt for klinikere og sygeplejersker der sjældent arbejder med SPC. Datawrapper's guidede wizard-flow demonstrerer at en trinvis tilgang reducerer kognitiv belastning markant, samtidig med at erfarne brugere stadig kan arbejde effektivt.

### Mål

- Reducere kognitiv belastning for nye/sjældne brugere
- Bevare effektivitet for erfarne kvalitetskoordinatorer
- Skabe en professionel, polished oplevelse på niveau med Datawrapper
- Forenkle den mentale model: ét klart formål per trin

### Målgruppe

- **Primær:** Klinikere og sygeplejersker der sjældent laver SPC (behov for guidance)
- **Sekundær:** Kvalitetskoordinatorer der laver SPC regelmæssigt (behov for effektivitet)
- Systemet skal håndtere begge brugertyper via fri navigation

---

## 2. Overordnet Arkitektur

### Erstatning, ikke udvidelse

Den nye wizard **erstatter helt** det nuværende layout. Der bygges ikke en parallel "power mode" eller valgfri wizard-tilgang. Hele UI'et omstruktureres til 4-trins wizard.

### Teknisk tilgang: Hybrid (bslib + custom CSS)

- **Foundation:** `bslib::navset_bar()` for wizard-trin
- **Wizard-look:** Custom CSS der styler bslib-tabs til at ligne wizard-steps med numre, checkmarks og farvekodning
- **Sub-tabs:** Nested `bslib::navset_tab()` i Trin 3
- **Sidebar layout:** `bslib::layout_sidebar(sidebar(), ...)` med sidebar til venstre i Trin 3
- **Validation feedback:** CSS classes via `shinyjs::addClass()` for trin-status

**Begrundelse:** Hybrid-tilgangen giver bslib's stabile fundament med wizard-æstetik via CSS. Det er markant enklere at bygge og vedligeholde end en fuld custom wizard, men ser mere professionelt ud end rå tabs.

### Namespace-strategi (input IDs)

Wizard-modulerne (`mod_wizard_*`) fungerer primært som **UI-layout containere**. For at undgå at bryde de 88+ eksisterende server-side referencer til inputs som `input$chart_type`, `input$x_column` osv., anvendes følgende strategi:

- **Form-inputs defineres på top-level scope** (uden module namespace), ikke inde i modulernes `ns()`. Wizard-modulerne wrapper og organiserer UI-elementer, men input IDs forbliver uændrede.
- **Alternativt** kan inputs defineres i moduler, men med en explicit mapping-layer der kobler namespaced IDs til `app_state` via observere i modulernes server-funktioner. Den eksisterende server-kode læser fra `app_state`, ikke direkte fra `input$`.
- **Endelig beslutning** træffes under implementeringsplanlægning efter en spike der tester begge tilgange med bslib's `navset_bar()`.

**Konsekvens:** Server-filer (`app_server_main.R`, `utils_server_event_listeners.R` m.fl.) skal muligvis tilpasses afhængigt af den valgte strategi. Dette er den største tekniske risiko ved refaktoreringen.

### Navigation

- **Fri navigation** — alle trin er tilgængelige fra start via klikbare step-indicators
- **Visuel status-indikation** per trin:
  - Grå cirkel + grå tekst: trin ikke besøgt/udfyldt
  - Blå cirkel + fed tekst + glow: aktivt trin
  - Grøn cirkel + checkmark: trin gennemført/valideret
  - Rød/orange indikator: trin har valideringsfejl
- **Forbindelseslinjer** mellem trin viser progress visuelt

---

## 3. Trin-for-trin Design

### Trin 1: Upload

**Formål:** Brugeren vælger hvordan data kommer ind i systemet.

**Layout:** To store, klikbare kort centreret på siden.

| Kort | Handling | Beskrivelse |
|------|----------|-------------|
| **Upload datafil** | Åbner file picker | CSV eller Excel (.xlsx). Drag-and-drop support. |
| **Start med blankt datasæt** | Opretter standard-tabel | Tomme standardkolonner klar til manuel indtastning. |

**Designprincipper:**
- Minimal kognitiv belastning — kun én beslutning
- Stor, tydelig visuel adskillelse mellem de to valgmuligheder
- "ELLER" divider mellem kortene
- Kort beskrivende tekst under hver mulighed

**Brugeren ledes automatisk videre til Trin 2** når fil er uploadet eller blankt datasæt er valgt, men kan frit navigere tilbage.

---

### Trin 2: Data

**Formål:** Brugeren verificerer, redigerer og mapper sine data.

**Layout:** Vertikal stack med tre sektioner.

#### Sektion A: Kolonne-mapping

Horisontalt layout med dropdown-selektorer:

| Felt | Beskrivelse | Påkrævet |
|------|-------------|----------|
| X-akse (Tid) | Tids-/observationskolonne | Ja |
| Y-akse (Værdi) | Måleværdi-kolonne | Ja |
| N (Nævner) | Stikprøvestørrelse/nævner | Kun for P/U charts |
| Kommentar (Noter) | Annotationskolonne | Nej |
| Skift (Opdel proces) | Kolonne/række for procesfaseskift | Nej |
| Frys (Fastfrys niveau) | Kolonne/række for baseline-frysning | Nej |

**Skift og Frys** er placeret i Trin 2 (ikke Trin 3) fordi de knytter sig til specifikke rækker i datasættet. Brugeren skal kunne se tabellen mens de angiver dem. Interaktionsmekanismen forbliver som i dag: **kolonne-mapping via dropdown-selektorer** (selectizeInput). Der introduceres ikke ny row-klik funktionalitet.

#### Sektion B: Handlingsknapper

- **Auto-detektér kolonner** (primær knap): Kører heuristisk kolonnedetektering og præ-udfylder mapping
- **Angiv manuelt** (sekundær knap): Viser/skjuler manuelle mapping-dropdowns

Auto-detection er en eksplicit handling — kører ikke automatisk. Dette er en **adfærdsændring** fra det nuværende system, hvor auto-detection kan trigges automatisk via event-bus ved data upload. I wizard-flowet skal event-listeneren i `utils_server_event_listeners.R` justeres så auto-detection kun kører ved eksplicit brugerhandling.

#### Sektion C: Redigerbar datatabel

- Excel-lignende tabel (eksisterende excelR-komponent)
- Farvekodede kolonnehoveder der indikerer datatype (tekst vs. numerisk)
- Inline redigering af celler
- Tilføj/fjern rækker og kolonner
- Statuslinje med antal rækker, kolonner

---

### Trin 3: Analyse

**Formål:** Brugeren konfigurerer sit SPC-chart og ser resultatet live.

**Sub-tabs:** To tabs inden i Trin 3.

#### Sub-tab: Diagram

**Layout:** To-kolonne layout med venstre panel (konfiguration) og højre panel (preview).

**Venstre panel (ca. 280px, fast bredde):**

| Felt | Type | Beskrivelse |
|------|------|-------------|
| Diagramtype | Dropdown | 9 chart-typer (run, i, mr, p, pp, u, up, c, g) |
| Y-akse enhed | Dropdown | Tal, Procent (%), Rate, Tid mellem hændelser |
| Udviklingsmål | Tekstfelt | Numerisk mål, evt. med operator (fx ">=90%", "<25") |
| Evt. baseline | Tekstfelt | Valgfri fast centrallinje |

**Højre panel (resten af bredden):**

- **SPC Chart Preview** (plotOutput): Live-opdaterer ved ændringer i venstre panel. Renderet via BFHcharts.
- **Anhøj Rules Value Boxes** (under chart'et): Kompakt horisontal række med:
  - Serielængde (med grænseværdi)
  - Antal kryds (med forventet interval)
  - Signal-indikator (normal/advarsel)
  - Farvekodning: grøn = ok, orange/rød = signal fundet

#### Sub-tab: Detaljer

**Layout:** Samme to-kolonne layout som Diagram-tab. Chart preview + Anhøj boxes vises i højre side her også, så brugeren kan se effekten af metadata-ændringer live (fx titel vises i chart).

**Venstre panel:**

| Felt | Type | Beskrivelse |
|------|------|-------------|
| Titel på indikator | Tekstfelt | Kort, beskrivende titel |
| Afdeling / Afsnit | Tekstfelt | Organisatorisk enhed (fri tekst erstatter nuværende radio-button vælger) |
| Datadefinition | Textarea | Hvad måles og hvordan |
| Udviklingsmål (beskrivelse) | Textarea | Fri tekst om målet |

**Metadata som single source of truth:** Disse felter er den **autoritative kilde** for metadata. Trin 4 (Eksport) læser metadata herfra — eksport-modulet har ikke egne duplikerede metadata-felter. De eksisterende metadata-felter i `mod_export_ui.R` fjernes og erstattes med read-only visning af data fra Trin 3.

---

### Trin 4: Eksport

**Formål:** Brugeren eksporterer sit færdige chart.

**Layout:** To-kolonne layout (format-valg til venstre, live preview til højre).

**Venstre panel:**

| Element | Beskrivelse |
|---------|-------------|
| Format-vælger | PDF / PNG / PowerPoint som klikbare kort |
| Format-specifikke indstillinger | PDF: inkluderer metadata. PNG: størrelses-preset + DPI |
| AI-forbedringsforslag (PDF) | Knap til at generere AI suggestion via BFHllm |
| Download-knap | Prominent, fuld bredde |

**Højre panel:**
- Live preview af eksport-output
- Opdaterer baseret på valgt format
- Viser advarsel hvis chart ikke er klar

---

## 4. Wizard Step Indicator

### Visuelt design

Horisontal progress-bar øverst på siden med fire klikbare cirkler forbundet af linjer:

```
  (✓)———(✓)———(●3)———(○4)
Upload   Data   Analyse  Eksport
```

### States

| State | Cirkel | Tekst | Linje til næste |
|-------|--------|-------|-----------------|
| Gennemført | Grøn med ✓ | Grøn, normal weight | Grøn |
| Aktiv | Blå, lidt større, glow | Blå, fed | — |
| Ubesøgt | Grå outline | Grå, lys | Grå |
| Fejl/mangler | Orange/rød outline | Orange | — |

### Implementation

- CSS styling af bslib `navset_bar()` tabs
- `shinyjs::addClass()`/`removeClass()` for dynamiske states
- Validation-status beregnes reaktivt baseret på tilgængelig data

---

## 5. Validering og State Management

### Per-trin validering

| Trin | Valideret når |
|------|--------------|
| 1. Upload | Data er tilgængelig (fil uploadet eller blankt valgt) |
| 2. Data | X og Y kolonner er mappet, mindst én datarække |
| 3. Analyse | Chart-type er valgt (altid opfyldt — har default) |
| 4. Eksport | Ingen validering nødvendig |

### State-ændringer ved tilbagenavigation

Når brugeren ændrer noget i Trin 1 eller 2 (nyt datasæt, ny kolonne-mapping):
- Chart i Trin 3 opdateres automatisk (eksisterende event-bus arkitektur)
- Eksport i Trin 4 reflekterer ændringer
- Anhøj rules genberegnes

### Bevarelse af eksisterende arkitektur

- **Event-bus** (`app_state$events`): Bevares uændret
- **State management** (`app_state$data`, `app_state$columns` osv.): Bevares
- **Emit API** (`create_emit_api()`): Bevares
- **Observer priorities**: Bevares

Wizard-refaktoreringen er primært en **UI-omstrukturering**. Backend-logik, state management og event-flow bevares. Dog kræves tilpasninger i: (1) `app_server_main.R` for at kalde nye modul-servere, (2) `utils_server_event_listeners.R` for auto-detection adfærdsændring, og (3) potentielt server-filer afhængigt af namespace-strategi (se sektion 2).

### Anbefalet spike før implementation

En teknisk spike bør gennemføres tidligt for at validere:
1. At `bslib::navset_bar()` kan styles til wizard-look via CSS
2. Hvilken namespace-strategi (top-level vs. modul med mapping) der fungerer bedst
3. At excelR-tabellen fungerer korrekt i det nye layout

---

## 6. Responsive Design

### Desktop (>1200px)
- Step indicator i fuld bredde
- Trin 3: venstre panel 280px + preview resten

### Tablet (768-1200px)
- Step indicator komprimeret (kun tal, ingen tekst)
- Trin 3: venstre panel kollapser til top-sektion over preview

### Mobil (<768px)
- Step indicator som tal-række
- Alt stacker vertikalt
- Trin 3: konfiguration over preview

---

## 7. Modul-struktur (Golem)

### Nye/ændrede filer

| Fil | Ændring | Ansvar |
|-----|---------|--------|
| `R/app_ui.R` | **Omskrives** | Wizard-layout med `navset_bar()` |
| `R/app_server_main.R` | **Tilpasses** | Kalder nye wizard-modul servere |
| `R/mod_wizard_upload.R` | **Ny** | Trin 1: Upload/blank valg |
| `R/mod_wizard_data.R` | **Ny** | Trin 2: Verificering, mapping, tabel |
| `R/mod_wizard_analyse.R` | **Ny** | Trin 3: Chart config + preview + detaljer |
| `R/mod_export_ui.R` | **Tilpasses** | Trin 4: Fjern duplikerede metadata-felter, læs fra Trin 3 |
| `R/mod_export_server.R` | **Tilpasses** | Eksisterende logik, tilpasses wizard-context |
| `inst/app/www/wizard.css` | **Ny** | Custom CSS for step indicator og wizard-styling |
| `R/mod_spc_chart_ui.R` | **Tilpasses** | Chart preview bruges i Trin 3 |
| `R/mod_spc_chart_server.R` | **Tilpasses** | Server-logik uændret, UI-binding justeres |
| `R/utils_server_event_listeners.R` | **Tilpasses** | Auto-detection trigger ændres til eksplicit |
| `R/utils_event_context_handlers.R` | **Tilpasses** | `handle_load_context()` auto-trigger fjernes |

### Filer der udgår

| Fil/Komponent | Årsag |
|---------------|-------|
| Nuværende sidebar-layout i `app_ui.R` | Erstattes af wizard |
| "Start ny session" / "Upload datafil" knapper i sidebar | Erstattes af Trin 1 |
| `create_welcome_page()` i `app_ui.R` (aktuelt disabled) | Erstattes af Trin 1 |
| Duplikerede chart-settings i `create_plot_only_card()` | Konsolideres i Trin 3 |
| Duplikerede metadata-felter i `mod_export_ui.R` | Single source of truth i Trin 3 |

### Filer der bevares uændret

- `R/fct_*.R` — Al business logic
- `R/utils_*.R` — Alle utilities
- `R/config_*.R` — Al konfiguration
- `R/state_management.R` — State management
- `R/utils_event_system.R` — Event-bus
- `global.R` — App initialization

---

## 8. Migrationsrisici

| Risiko | Sandsynlighed | Konsekvens | Mitigation |
|--------|---------------|------------|------------|
| **Input namespace-kollision** | **Høj** | **Høj** | Spike for at teste namespace-strategi før implementation. Se sektion 2. |
| CSS-styling bryder ved bslib-opdatering | Middel | Lav-middel | Isoleret CSS, versioneret bslib dependency |
| Eksisterende event-bus passer ikke wizard-flow | Lav | Høj | Wizard er primært UI-only — event-bus er upåvirket |
| excelR-tabel opfører sig anderledes i ny layout | Lav | Middel | Test tidligt i spike |
| Chart preview i sidebar-layout performer dårligt | Lav | Middel | Debounce + eksisterende caching |
| Responsive design kræver mere arbejde end forventet | Middel | Lav | Desktop-first, responsive som follow-up |
| Duplikerede input IDs i nuværende kode | Middel | Middel | Konsolidér under migration — se "Filer der udgår" |

---

## 9. Udenfor Scope

Følgende er **eksplicit ikke** del af denne designændring:

- Nye chart-typer eller SPC-funktionalitet
- Ændringer i BFHcharts, BFHtheme eller Ragnar
- Ændringer i state management eller event-bus arkitektur
- Nye eksport-formater
- Ændringer i AI/LLM integration
- Backend/beregnings-logik
- Ny funktionalitet ud over workflow-omstrukturering

---

## 10. Successkriterier

| Kriterium | Måling |
|-----------|--------|
| Alle eksisterende funktioner virker i wizard | Alle tests passerer |
| Wizard-flow føles intuitiv for nye brugere | Manuel brugertest |
| Erfarne brugere kan navigere frit og hurtigt | Fri navigation fungerer |
| Chart preview opdaterer live | Visuel verifikation |
| Step indicator viser korrekt status | Visuel verifikation + tests |
| Responsive layout fungerer på tablet | Manuel test |
| Ingen performance-regression | Startup < 100ms, render < 1s |

---

## Appendix A: Sammenligning med Datawrapper

| Aspekt | Datawrapper | SPCify Wizard |
|--------|-------------|---------------|
| Antal trin | 4 | 4 |
| Trin 1 | Upload (paste/upload/link) | Upload fil eller blankt datasæt |
| Trin 2 | Check & Describe | Data: verificér, map, rediger, skift/frys |
| Trin 3 | Visualize (Refine/Annotate/Design) | Analyse (Diagram/Detaljer) |
| Trin 4 | Publish & Embed | Eksport (PDF/PNG/PPTX) |
| Navigation | Sekventiel med tilbage-knap | Fri navigation med status-indikation |
| Sub-tabs i trin 3 | Refine / Annotate / Design | Diagram / Detaljer |
| Chart preview | Højre side i trin 3 | Højre side i trin 3 (begge sub-tabs) |
| Teknologi | Custom web app (Vue.js) | Shiny/bslib med custom CSS |

---

## Appendix B: Nuværende vs. Ny Brugerflow

### Nuværende flow
```
[Sidebar: Upload] → [Analyse-fane: Alt på én gang] → [Eksport-fane]
                     (tabel + mapping + chart + config + preview)
```

### Ny flow
```
[Trin 1: Upload] → [Trin 2: Data] → [Trin 3: Analyse] → [Trin 4: Eksport]
                    (verificér,      (Diagram | Detaljer)  (PDF/PNG/PPTX
                     map, rediger,    config ↔ preview)     + AI + preview)
                     skift, frys)
```
