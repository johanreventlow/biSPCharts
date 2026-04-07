# Wizard Navbar Design

## Formål

Omdanne biSPCharts's navbar til en nummereret wizard-flow inspireret af Datawrapper, så brugeren guides igennem upload → analyse → eksport som et progressivt flow.

## Trin og gates

| Trin | Label | Ikon | Gate |
|------|-------|------|------|
| 1 | Upload | upload | Altid tilgængelig |
| 2 | Analysér | chart-line | Data loaded (app_state$data$current_data ikke NULL) |
| 3 | Eksportér | file-export | Plot renderet |

**Navigationsregler:**
- Tilbage er altid frit (3→1, 2→1, 3→2)
- Fremad kræver gate-opfyldelse
- Når gate opfyldes, unlockes næste trin automatisk
- Auto-navigation til trin 2 efter upload

## Visuel stil

Tab-labels vises med nummeret cirkel-badge foran teksten via CSS `::before` pseudo-element. Hvert nav-link har `data-step` attribut.

| Tilstand | Cirkel | Tekst | Cursor |
|----------|--------|-------|--------|
| Aktiv | Filled primary | Bold | pointer |
| Unlocked | Outlined primary | Normal | pointer |
| Locked | Grå outline | Grå, opacity 0.5 | not-allowed |

## Teknisk implementation

### 1. app_ui.R

Tilføj `data-step` attributter til hvert `nav_panel` via `shiny::tagAppendAttributes()`. Tilføj CSS for nummercirkler og locked-state styling.

### 2. inst/app/www/wizard-nav.js (nyt)

- Lyt efter custom Shiny messages: `wizard-unlock-step`, `wizard-lock-step`
- Tilføj/fjern `.wizard-locked` class på nav-links
- Intercept klik på låste tabs via `event.preventDefault()`

### 3. Server-side gate-logik

I eksisterende observers:
- Data loaded → `session$sendCustomMessage("wizard-unlock-step", 2)`
- Data fjernet (ny session) → lock trin 2+3
- Plot renderet → unlock trin 3
- Plot forsvundet → lock trin 3

### 4. Auto-navigation

Når data uploades: `bslib::nav_select()` skifter til trin 2.

## Afgrænsning

- Ingen nye R-dependencies
- Ingen progress-bar eller streger mellem trin
- Bygger på eksisterende bslib::page_navbar() struktur
