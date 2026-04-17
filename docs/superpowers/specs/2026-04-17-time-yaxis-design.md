# Design: Bedre tidshåndtering på y-aksen

**Dato:** 2026-04-17
**Status:** Design godkendt — klar til implementation-plan
**Relaterede filer:** `R/utils_y_axis_formatting.R`, `R/utils_label_formatting.R`, `R/utils_y_axis_model.R`, `R/config_spc_config.R`

---

## Problem

Når en bruger vælger at y-aksen viser **tid**, håndterer biSPCharts skaleringen og formateringen dårligt:

1. **P1 — Ugly tick-labels** *(vigtigst)*: Ticks placeres ved ggplot2-defaults som fx `73`, `146`, `219` minutter i stedet for naturlige tids-intervaller (`60`, `120`, `180` eller `1t`, `2t`, `3t`).
2. **P2 — Forvirrende enhedsvalg**: Enhedsvalget mellem minutter/timer/dage baseres på `max_value` alene (breakpoints 60 og 1440), hvilket giver besynderlige labels som `0,8541667 timer` (≈ 51 minutter) eller `1,0 dage` når `24 timer` ville være klarere.
3. **P3 — Upræcis rounding**: `nsmall = 1` er **minimum** decimaler, ikke maximum, så værdier som `0,8541667 timer` slipper igennem med 7 decimaler. Selv når rounding virker, føles `1,5 timer` mindre præcist end `1t 30m`.
4. **P4 — Ingen måde at angive input-enhed**: Koden antager altid at y-værdier er i minutter. Hvis data er i timer eller dage, bliver aksen faktor-60 eller faktor-1440 forkert.

Prioritet: **P1 > P2 > P3 > P4**.

---

## Mål

- Y-aksens ticks placeres ved tids-naturlige intervaller (15m, 30m, 1t, 2t, 4t, 6t, 12t, 1d, 2d, 7d) der matcher den valgte input-enhed.
- Labels formateres som komposit (`1t 30m`, `45m`, `2d 4t`) — kun ikke-nul komponenter, maks 2 komponenter, ingen decimaler.
- Brugeren kan eksplicit vælge input-enhed (`Tid (minutter)`, `Tid (timer)`, `Tid (dage)`) — intet gætteri.
- HH:MM-strenge og `hms`/`difftime`-objekter auto-parses uafhængigt af valgt input-enhed.
- Eksisterende gemte sessions migreres stille og konsistent.
- Ren separation af parsing, enhedsvalg, tick-generering og label-formatering — hver med egne unit tests.

### Non-goals

- Fuld sekund-support i akse-labels (`1t 30m 15s`): sekunder rundes til nærmeste minut ved indlæsning.
- Dansk varighedssyntaks som input (`"1t 30m"`): ikke i scope — kan tilføjes senere.
- Dato-differencer beregnet fra to kolonner: ikke i scope.
- Uger/måneder/år som ekstra enheder: ikke i scope. Meget store værdier vises som mange dage (fx `365d`).
- Komposit med 3+ komponenter (`2d 4t 15m`): begrænses til 2 komponenter for læsbarhed.

---

## Principper

1. **Én kanonisk enhed, mange inputs**: Alt konverteres til **minutter** (som `double`) ved indlæsning. Formaterings- og tick-lag arbejder kun i minutter.
2. **Ren separation**: Parsing ↔ enhedsvalg ↔ tick-generering ↔ label-formatering er adskilte ansvar.
3. **Komposit labels er default**: `1t 30m`, `45m`, `2d 4t`. Maks 2 komponenter. Ingen decimaler på aksen; datapunkt-labels må være mere præcise.
4. **Eksplicit input-enhed**: Brugeren vælger i UI; systemet gætter ikke.
5. **Backwards compatibility i Fase 1**: Alle API'er holder samme signaturer. Kun output-strenge ændrer sig.

---

## Overordnet struktur

Leveres i **to faser** (inkrementelt B-spor — jf. valg under brainstorming):

### Fase 1 — Bugfix (isoleret, lander først)

Retter **P1** (tids-naturlige tick-breaks) og **P3** (rounding/for-mange-decimaler) i den eksisterende `"time"`-enhed.

- Ingen UI-ændringer.
- Ingen datamodel-ændringer.
- Ingen localStorage-bump.
- Antagelsen "input er minutter" bevares.
- Komposit label-format indføres her — kan gøres uden at udvide enheds-valget.

### Fase 2 — Nye enheder og migration

Tilføjer `Tid (minutter)`, `Tid (timer)`, `Tid (dage)` som eksplicitte y-enheder; løser **P2** og **P4**.

- UI-dropdown udvides; legacy `"time"` fjernes fra UI.
- Parsing-lag håndterer numeric + enhed, HH:MM, `hms`, `difftime`.
- Silent forward-migration af gemte sessions.
- T-kort-defaults opdateres (`"t"` → `Tid (dage)`).
- Intern klassifikation bruger familiecheck (`is_time_unit()`) i stedet for exact match.

---

## Fase 1 — Detaljer

### Tick-break algoritme (P1)

**Kandidat-intervaller i minutter** (tids-naturlige):

```
1m, 2m, 5m, 10m, 15m, 20m, 30m,
60m (=1t), 120m (=2t), 180m (=3t), 240m (=4t), 360m (=6t), 720m (=12t),
1440m (=1d), 2880m (=2d), 10080m (=7d), 43200m (=30d)
```

**Valg-logik:** Givet data-range `[ymin, ymax]`, vælg det **største interval** fra listen der stadig giver mindst `target_n` ticks (default 5). Begge ender snappes med `floor()` til grid-multipla:

```r
start <- floor(y_min / interval) * interval
end <- floor(y_max / interval) * interval
breaks <- seq(start, end, by = interval)
```

Kriteriet "største interval med ≥ target_n ticks" vælger naturligt grovere intervaller når data-range stiger (færre ticks af større enhed), og finere intervaller når data er tæt (flere ticks af mindre enhed). Det undgår overfyldte akser uden at kræve et eksplicit maksimum.

`end` snappes med `floor()` (ikke `ceiling()`) for at undgå "ekstra tom plads" på toppen af aksen. Ggplot2 udvider selv aksen med `expansion(mult = c(.25, .25))` så sidste datapunkt stadig er synligt over sidste tick.

**Eksempler:**

| Range | Valgt interval | Ticks |
|---|---|---|
| 0–120 min | 30m | `0, 30m, 60m, 90m, 120m` |
| 15–185 min | 30m | `0, 30m, 60m, 90m, 120m, 150m, 180m` |
| 45–155 min | 30m | `30m, 60m, 90m, 120m, 150m` |
| 0–480 min (=0–8t) | 120m | `0, 2t, 4t, 6t, 8t` |
| 0–7200 min (=0–5d) | 1440m | `0, 1d, 2d, 3d, 4d, 5d` |

**Fallback:** Hvis ingen kandidat giver ≥ `target_n` ticks (meget smal range), brug det mindste interval der giver mindst 2 ticks. Hvis intet virker, brug første kandidat. Log fallback-hændelser.

**Integration:** Implementér som `time_breaks(y_values, target_n = 5L)` funktion brugt i `scale_y_continuous(breaks = ...)`.

### Komposit label-format (P3)

**Algoritme** (input: minutter som `double`, maks 2 komponenter):

1. `V_int <- round(V)` (afrund til hele minutter FØRST — forhindrer overflow i sub-komponenter som ellers kunne give `60m` i stedet for `1t` når fx `V = 59,7`)
2. `d <- V_int %/% 1440` (hele dage)
3. `rem <- V_int %% 1440`
4. `t <- rem %/% 60` (hele timer)
5. `m <- rem %% 60` (hele minutter)
6. Komponér ikke-nul dele, maks 2 komponenter:
   - `d > 0, t > 0` → `"Xd Yt"` (minutter ignoreres ved dage-skala)
   - `d > 0, t = 0` → `"Xd"`
   - `d = 0, t > 0, m > 0` → `"Xt Ym"`
   - `d = 0, t > 0, m = 0` → `"Xt"`
   - `d = 0, t = 0, m > 0` → `"Xm"`
   - `d = 0, t = 0, m = 0` → `"0m"`

**Negative værdier:** `V < 0` → præfix med `-`, absolut værdi formateres som ovenfor.

**Rounding-fix:** Step 1 runder til heltal minutter før komponentopdeling. Det eliminerer `0,8541667 timer`-bugget i komposit-form: sub-minut-decimaler forsvinder helt fra akse-labels, og overflow-scenarier (59,7 min → `1t` ikke `60m`) håndteres korrekt.

**Eksempler:**

| Input (min) | Output |
|---|---|
| 90 | `1t 30m` |
| 45 | `45m` |
| 51 | `51m` *(ikke `0,8541667 timer`)* |
| 3660 | `2d 13t` |
| 60 | `1t` |
| 1440 | `1d` |
| 0 | `0m` |
| -30 | `-30m` |

### Implementation — filer

**Ny fil:** `R/utils_time_formatting.R`
- `format_time_composite(minutes, max_components = 2L)` → karakter
- `time_breaks(y_values, target_n = 5L)` → numeric vektor (brud i minutter)

**Ændrede filer:**
- `R/utils_y_axis_formatting.R::format_y_axis_time()` — bruger de to nye funktioner, erstatter `max_minutes`-switch + `nsmall = 1`-rounding.
- `R/utils_label_formatting.R::format_y_value()` (gren for `y_unit == "time"`) — bruger `format_time_composite()`. `y_range`-parameteren bliver irrelevant for time-enheden.

**Ingen ændringer til:** `config_spc_config.R`, UI, state management, localStorage.

### Backwards compatibility (Fase 1)

Fase 1 er ren intern refaktor af tekst-output. Alle API-signaturer holder. Eksisterende sessions fortsætter med pænere labels.

---

## Fase 2 — Detaljer

### UI-ændringer

**`config_spc_config.R::Y_AXIS_UI_TYPES_DA`** udvides:

```r
Y_AXIS_UI_TYPES_DA <- list(
  "Tal"              = "count",
  "Procent (%)"      = "percent",
  "Rate"             = "rate",
  "Tid (minutter)"   = "time_minutes",
  "Tid (timer)"      = "time_hours",
  "Tid (dage)"       = "time_days"
)
```

Legacy `"time"` fjernes fra UI, men beholder et kodemæssigt alias (`"time"` → `"time_minutes"`) via migration (se nedenfor).

### Parsing-lag (ny fil: `R/utils_time_parsing.R`)

Én funktion `parse_time_to_minutes(x, input_unit)` der håndterer alle inputtyper:

| Input-type | Eksempel | Output (min) |
|---|---|---|
| Numeric + `time_minutes` | `90` | `90` |
| Numeric + `time_hours` | `1.5` | `90` |
| Numeric + `time_days` | `0.0625` | `90` |
| `hms::hms()` | `hms(90*60)` | `as.numeric(x, units = "mins")` |
| `difftime` | `as.difftime(90, units = "mins")` | `as.numeric(x, units = "mins")` |
| HH:MM-streng | `"01:30"` | `90` |
| HH:MM:SS-streng | `"01:30:15"` | `90` *(sekunder rundes væk ved indlæsning)* |
| NA / ugyldig | `"N/A"` | `NA_real_` + log advarsel |

**Prioritetsregel:**
1. Hvis kolonnen er `hms`/`difftime` → brug objekt-type, ignorér `input_unit`.
2. Hvis kolonnen er tekst der matcher HH:MM[:SS] → parse til minutter.
3. Ellers numerisk → skalér med `input_unit`.

**Sekunder:** Parse sekunder væk ved indlæsning. Intern repræsentation er `double` minutter, men komposit-format runder til hele minutter. Sekund-støj undgås ikke behandles som first-class data.

### Integration med eksisterende lag

**`R/utils_y_axis_model.R`:**
- Ny helper `is_time_unit(ui_type)` → `ui_type %in% c("time_minutes", "time_hours", "time_days")`.
- `determine_internal_class()` — erstat `ui == "time"` med `is_time_unit(ui)` (mapper stadig til `TIME_BETWEEN`).
- `chart_type_to_ui_type("t")` returnerer `"time_days"` (var `"time"`).
- Ny funktion `default_time_unit_for_chart(chart_type)` (returnerer `"time_days"` for t-kort; udbyggelig når flere kort-typer tilføjes).

**`R/utils_y_axis_formatting.R::format_y_axis_time()`:**
- Tilføjer `input_unit` parameter til tick-filtrering (C-strategien fra brainstorming).
- Kandidat-intervallerne markeres med hvilke input-enheder de er naturlige i:
  - `time_minutes`: hele listen (1m → 30d)
  - `time_hours`: 30m (=0,5t), 60m, 120m, 240m, 360m, 720m, 1440m, 2880m, 10080m, 43200m
  - `time_days`: 720m (=0,5d), 1440m, 2880m, 10080m, 43200m
- Filtrér kandidatlisten, vælg interval der giver 4–7 ticks. Hvis intet passer → fall back til ufiltreret liste med log-besked.

**Data-parsing pipeline:** Parsing sker **én gang, tidligt** — enten i `fct_spc_bfh_facade.R` før data sendes til BFHcharts, eller i en prepare-step i `fct_spc_plot_generation.R`. Endelig placering afgøres under implementation-plan. Princip: alt nedstrøms arbejder i kanoniske minutter.

### Migration af gemte sessions

**LocalStorage:**
- `LOCAL_STORAGE_SCHEMA_VERSION`: `"2.0"` → `"3.0"`.
- Ved indlæsning af `schema_version = "2.0"`: map `y_axis_unit = "time"` → `"time_minutes"` (silent forward-migration), opdater version internt.
- Ingen bruger-prompt. Data går ikke tabt.
- Rationale: `"time" → "time_minutes"` er semantisk korrekt givet at koden i dag antager minutter. Bruger kan altid skifte til timer/dage bagefter.

**Pins (cloud-save):** Samme migration-logik ved indlæsning.

### Auto-detection af default time-enhed

Når auto-detect identificerer en tids-kolonne: **altid default til `Tid (minutter)`**. Ingen heuristisk gæt baseret på værdi-range. Forudsigeligt; bruger kan skifte i dropdownen.

*Undtagelse:* Hvis kolonnen er `hms`/`difftime` kan vi evt. udlede default-enhed fra objektets units-attribut senere — ikke i scope for denne change.

### Nye og ændrede filer (Fase 2)

**Nye:**
- `R/utils_time_parsing.R`
- `tests/testthat/test-time-parsing.R`
- `tests/testthat/test-local-storage-time-migration.R`

**Ændrede:**
- `R/config_spc_config.R` (`Y_AXIS_UI_TYPES_DA`, evt. `Y_AXIS_UNITS_DA`)
- `R/utils_y_axis_model.R` (`is_time_unit`, `default_time_unit_for_chart`, `determine_internal_class`, `chart_type_to_ui_type`)
- `R/utils_y_axis_formatting.R` (`format_y_axis_time(input_unit)`)
- `R/utils_label_formatting.R` (accepterer nye `time_*` enheder)
- `R/fct_spc_bfh_facade.R` (parsing pipeline)
- `R/utils_local_storage.R` (migration ved indlæsning, version bump)
- `R/utils_analytics_pins.R` (migration ved indlæsning)

**Ingen ændring:** `R/fct_spc_plot_generation.R` ud over at data nu kommer ind i kanoniske minutter (ingen logikændring).

---

## Testing

### Enhedstests

**`test-time-formatting.R` (Fase 1):**
- `format_time_composite()`: 0, 1m, 59m, 60m (=1t), 90m (=1t 30m), 1439m, 1440m (=1d), 3660m (=2d 13t), negative værdier, NA, sub-minut (0,25m → 0m), overflow-edge-cases (59,7m → `1t` ikke `60m`; 1439,7m → `1d` ikke `24t`; 60,4m → `1t`).
- `time_breaks()`: Range [0, 120] → 30m/5 ticks; [15, 185] → snap til 30m-grid; [0, 480] → 2t-interval; tom/NA/konstant → fallback.
- **Regressions-test:** input 51 minutter → `"51m"` (ikke `"0,8541667 timer"`).

**`test-time-parsing.R` (Fase 2):**
- Numeric + hver af de tre `input_unit` værdier.
- `hms::hms()` og `as.difftime()` med forskellige enheder.
- HH:MM-strenge: `"01:30"`, `"00:45"`, `"25:15"` (>24t valid), `"1:5"` (enkelt-cifre), `"invalid"` (NA).
- HH:MM:SS-strenge: sekunder rundes væk.
- Blandede kolonner: numerisk med enkelt tekst-værdi → NA for tekst, log advarsel.

**`test-y-axis-formatting.R` (udvidet):**
- `apply_y_axis_formatting()` med `y_axis_unit = "time_minutes"` giver samme output som `"time"` før refaktoreringen.
- Tick-filtrering: `time_hours` input → intervaller som 30m/60m/120m, ikke 15m.

**`test-y-axis-model.R` (udvidet):**
- `is_time_unit()` returnerer TRUE for alle tre nye værdier + `"time"` legacy-alias.
- `chart_type_to_ui_type("t")` returnerer `"time_days"`.
- `determine_internal_class("time_hours", ...)` returnerer `TIME_BETWEEN`.

### Integrationstests

**`test-local-storage-time-migration.R`:**
- Gem session med `schema_version = "2.0"` og `y_axis_unit = "time"` → indlæs → verificér `y_axis_unit = "time_minutes"` og `schema_version = "3.0"`.
- Gem med ukendt version → hard reset (eksisterende adfærd bevares).

### Manuel/shinytest2 (valgfrit)

- Upload dataset med tid i minutter → plot viser komposit-labels på akse.
- Skift y-enhed fra minutter → timer → dage → verificér labels opdaterer korrekt.
- T-kort med default `Tid (dage)` → verificér 1d, 2d, 7d-ticks.

### Coverage-mål

- Kritiske paths (parsing, formatting, migration): 100%.
- Samlet projekt-coverage må ikke falde (nuværende ≥90%).

---

## Risici og edge cases

### Risici

1. **Komposit-format på CL/UCL/LCL-labels kan overfylde plottet** hvis linjerne ligger tæt. Mitigering: label-truncation ved overlap (eksisterende BFHcharts-adfærd bør dække dette — verificeres visuelt).
2. **Tick-filtrering kan give færre end 4 ticks** for meget smalle ranges i `time_hours`/`time_days`. Mitigering: fallback til ufiltreret kandidatliste med log-besked.
3. **HH:MM-parsing kan kollidere med auto-detect** af x-akse tidskolonner (fx hvis en kolonne hedder `tid_foedsel`). Mitigering: HH:MM-parse kun når y-kolonne er **eksplicit** markeret med `Tid (...)`-enhed — ikke som del af auto-detect-heuristik.

### Edge cases der skal dækkes i tests

- Negative tider (fx negative kontrolgrænser for t-kort med lav CL).
- NA-værdier i y-kolonnen.
- Enkelt-punkts-dataset (range = 0).
- Meget store værdier (>1 år = >525.600m) → vises som mange dage (fx `365d`); måneder/år ikke i scope.
- Meget små værdier (<1m) efter sekund-afrunding → runder til `0m`.

---

## Leveringsrækkefølge

1. **PR 1 — Fase 1 (bugfix)**: `utils_time_formatting.R` + opdater `format_y_axis_time()` + `format_y_value()`. Unit tests. **Lander hurtigt**; synlig forbedring for alle brugere uden breaking changes.
2. **PR 2 — Fase 2a (parsing + model)**: `utils_time_parsing.R` + `is_time_unit()` + expand `Y_AXIS_UI_TYPES_DA`. Intern refaktor; ingen UI-ændring.
3. **PR 3 — Fase 2b (UI + migration)**: Dropdown-opdatering, localStorage-schema-bump, silent migration, t-kort default. Ender med fuld P4-løsning.

---

## Sammenfatning af nøglevalg

| Beslutning | Valg | Rationale |
|---|---|---|
| Scope v1 | A+B+C+E (min/t/d + HH:MM + hms) | Dækker klinisk data; D (dansk varighedssyntaks) og F (dato-differencer) parkeret |
| Label-format | `1t 30m`-komposit | Præcist, ingen decimal-støj, skalerer til minutter/timer/dage |
| Datapunkt-labels | Må være mere præcise end akse | CL/UCL kan vise minutter hvor akse viser timer |
| Input-enhed | Eksplicit via dropdown | Ingen gæt; forudsigelig |
| Tick-intervaller | Tids-naturlige, filtreret af input-enhed | Ingen `17m`-ticks når bruger har valgt timer |
| Migration | Silent forward (`"time"` → `"time_minutes"`) | Ingen datatab; matcher nuværende antagelse |
| Sekunder | Rundes væk ved indlæsning | 99 % klinisk data kræver ikke sekund-præcision |
| Auto-detect default | Altid `Tid (minutter)` | Ingen heuristisk gæt; forudsigeligt |
| Leveringsmodel | Inkrementelt (Fase 1 først) | P1+P3 lander hurtigt som bugs; P2+P4 kræver mere testing |

---

## Åbne spørgsmål til implementation-plan

- Præcis placering af parsing-laget: `fct_spc_bfh_facade.R` eller en prepare-step i `fct_spc_plot_generation.R`?
- Skal `Y_AXIS_UNITS_DA` (mapping fra runtime-kode til dansk label) også udvides, eller er det kun `Y_AXIS_UI_TYPES_DA` der bruges i den nye dropdown?
- Skal ai-improvement-suggestions (`fct_ai_improvement_suggestions.R`) modtage den nye `input_unit` som del af context, så prompts kan beskrive data korrekt? (Lav-risiko, kan udsættes.)
