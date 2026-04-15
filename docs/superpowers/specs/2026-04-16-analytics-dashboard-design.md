# biSPCharts Analytics Dashboard — Design Spec

**Dato:** 2026-04-16
**Status:** Approved
**Scope:** Quarto Dashboard for visualisering af biSPCharts brugsdata
**Forudsaetning:** Analytics tracking i biSPCharts (implementeret 2026-04-15)

---

## Baggrund

biSPCharts indsamler anonymiseret brugsstatistik via shinylogs med GDPR cookie
consent. Data aggregeres og publiceres til Posit Connect Cloud via pins-pakken.
Der mangler et dashboard til at visualisere disse data for to maalgrupper:
hospitalsledelse (overblik) og udvikler/vedligeholder (teknisk indsigt).

### Constraints

- Intet budget — kun Posit Connect Cloud
- Data leveres via `pins::pin_read("spc-analytics-logs")`
- Daglig opdatering er tilstraekkeligt (ikke real-time)
- Dashboard er offentligt tilgaengeligt (ingen auth)
- Dansk sprog

---

## Tilgang

Statisk Quarto Dashboard (`format: dashboard`) rendered dagligt paa Connect
Cloud. Laeser pin-data, genererer ggplot2-grafer, publiceres som statisk HTML.
Ingen server-overhead.

---

## 1. Repository og Projektstruktur

**Nyt separat repository:** `biSPCharts-analytics`

```
biSPCharts-analytics/
  _quarto.yml              # Quarto config, dashboard format, BFH theme
  index.qmd                # Hoveddokument med begge faner
  R/
    data_load.R            # pin_read() + data-forberedelse
    kpi_calculations.R     # KPI-beregninger (sessions, unikke, completion)
    plot_overview.R        # ggplot2 grafer til Overblik-fane
    plot_technical.R       # ggplot2 grafer til Teknisk-fane
  renv.lock                # Reproducerbart miljo
  manifest.json            # Connect Cloud deploy
  .Renviron.example        # Template for CONNECT_SERVER, CONNECT_API_KEY
  CLAUDE.md                # Projektinstruktioner
```

**Dependencies:**
- quarto (format: dashboard)
- bslib (layout, value boxes)
- pins (laes data fra Connect Cloud)
- ggplot2 (grafer)
- dplyr, tidyr, lubridate (datatransformation)
- BFHtheme (hospital-branding, farver, fonts)
- scales (akse-formattering)

---

## 2. Data-flow

```
biSPCharts (Shiny app)
  -> shinylogs fanger: sessions, inputs, outputs, errors
  -> aggregate_and_pin_logs() samler alle 4 kategorier
  -> pins::pin_write("spc-analytics-logs", list(sessions, inputs, outputs, errors))

biSPCharts-analytics (Quarto Dashboard)
  -> pins::pin_read("spc-analytics-logs")
  -> R data-forberedelse (R/data_load.R)
  -> KPI-beregninger (R/kpi_calculations.R)
  -> ggplot2 grafer (R/plot_overview.R, R/plot_technical.R)
  -> Quarto render -> statisk HTML dashboard
  -> Publiceret paa Connect Cloud
```

### Pin-datastruktur

Pin'en indeholder en liste med fire data.frames:

| Tabel | Indhold | Noeglefelter |
|-------|---------|-------------|
| `sessions` | Session metadata | app, server_connected, server_disconnected, session_duration |
| `inputs` | Input-aendringer | session, name, value, timestamp |
| `outputs` | Output-renderings | session, name, timestamp |
| `errors` | Fejl | session, name, error, timestamp |

Client metadata (browser, OS, visitor_id) og performance-timing fanges som
inputs med navnene `analytics_client_metadata` og `analytics_performance`.

---

## 3. Layout

Quarto Dashboard med **to faner (tabs)**:
- **Overblik** — KPI'er og trends for hospitalsledelse
- **Teknisk** — Detaljeret feature-brug, fejl og performance for udvikler

---

## 4. Overblik-fane

### 6 KPI Value Boxes (oeverste raekke)

| KPI | Beregning | Farve |
|-----|-----------|-------|
| Sessions denne uge | Antal sessions i seneste 7 dage | BFH primary |
| Unikke besogende | Antal unikke visitor_id i seneste 7 dage | BFH info |
| Completion rate | Andel sessions med chart-rendering | Groen/roed afhaengig af % |
| Gns. session-varighed | Median session_duration i minutter | BFH secondary |
| Populaereste indikator | Mest brugte indikatornavnm (fra tekstfelter) | BFH accent |
| Trend | Aendring i sessions uge-over-uge (pil op/ned + %) | Groen hvis op, roed ned |

### 3 Grafer (under value boxes)

1. **Sessions over tid** — Linjegraf, daglige sessions, 30-dages vindue, 7-dages glidende gennemsnit
2. **Top 10 indikatorer** — Horisontal barchart, mest brugte indikatornavne
3. **Wizard completion funnel** — Barchart: Upload -> Analyser -> Eksport (antal sessions per step)

---

## 5. Teknisk fane

### 7 Visualiseringer

| # | Visualisering | Type | Beskrivelse |
|---|--------------|------|-------------|
| 1 | Feature-brug | Horisontal barchart | Chart-typer (run, p, c, u, i), eksport-formater, Skift/Frys brug |
| 2 | Wizard-flow funnel | Stacked barchart | Sessions per step med frafald i % |
| 3 | Fejl-oversigt | Tabel + linjegraf | Top fejltyper med frekvens, trend over 30 dage |
| 4 | Performance | Boxplot | Page load, chart render, upload tid — fordeling over 30 dage |
| 5 | Browser/OS | Donut chart | Fordeling af browsere og operativsystemer |
| 6 | Returning visitors | Stacked area chart | Nye vs. tilbagevendende besogende over tid |
| 7 | Tidsmoenstre | Heatmap | Ugedag x time (0-23), farveintensitet = antal sessions |

### Grid-layout

- **Raekke 1:** Feature-brug (bred) + Wizard funnel (smal)
- **Raekke 2:** Fejl-oversigt (halvt) + Performance (halvt)
- **Raekke 3:** Browser/OS (tredjedel) + Returning visitors (tredjedel) + Tidsmoenstre heatmap (tredjedel)

---

## 6. Styling

- **BFHtheme** for hospital-branding (farver, fonts)
- Quarto Dashboard tema baseret paa BFH farvepalette
- Dansk sprog i alle labels, akser, titler
- Responsivt layout (fungerer paa desktop og tablet)

---

## 7. Deploy og Scheduled Rendering

- Publish til Connect Cloud via `rsconnect::writeManifest()` + GitHub integration
- Scheduled rendering: dagligt (Connect Cloud scheduler)
- Manifest.json committed i repo for automatisk deploy

---

## 8. Noedvendige aendringer i biSPCharts

Tre mindre, bagudkompatible aendringer i biSPCharts-repositoriet:

### 8.1 Udvid pin-data (utils_analytics_pins.R)

Ny funktion `read_shinylogs_all(log_directory)` der laeser alle 4 kategorier
(sessions/, inputs/, outputs/, errors/) og returnerer en navngivet liste.

Opdater `aggregate_and_pin_logs()` til at kalde `read_shinylogs_all()` og
publicere listen (ikke kun sessions) via `pin_write()`.

### 8.2 Fjern input-filtre (utils_shinylogs_config.R)

Fjern `analytics_client_metadata` og `analytics_performance` fra
`exclude_input_regex` saa shinylogs fanger klient-metadata og performance-timing
som normale inputs.

### 8.3 Opdater manifest.json

Regenerer manifest efter kodeaendringer.

---

## 9. Risici og mitigering

| Risiko | Mitigering |
|--------|------------|
| Ingen data endnu (nyt system) | Dashboard viser "Ingen data tilgaengelig" gracefully |
| Pin ikke tilgaengelig | data_load.R returnerer tom data, dashboard viser placeholder |
| Connect Cloud scheduler fejler | Manuel render som fallback |
| shinylogs format aendres | Versioneret pin-data med schema check |
| BFHtheme ikke tilgaengelig paa Connect Cloud | Fallback til standard Quarto tema |
