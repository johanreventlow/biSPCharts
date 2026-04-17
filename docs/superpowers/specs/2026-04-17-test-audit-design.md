# Test Audit Design

**Dato:** 2026-04-17
**Issue:** #203 (test-suite drift, publish-gate blokeret)
**Status:** Design godkendt, afventer implementations-plan

---

## Baggrund

biSPCharts' test-suite er i drift: ~200+ tests fejler fordi de kalder R-funktioner der
ikke længere eksisterer. Problemet stammer fra tidligere refaktoreringer hvor tests ikke
blev opdateret parallelt med `R/`-ændringer. Resultatet er at
`devtools::test(stop_on_failure = TRUE)` blokerer publish-workflowet til Posit Connect
Cloud, og et `--skip-tests`-flag er indført som midlertidig nødløsning (anti-pattern).

Der eksisterer også en aktiv OpenSpec-change `refactor-code-quality` med Phase 1
(test-konsolidering 146 → ~100 filer). Dennes grundantagelse er at alle 1196+ tests
består — hvilket ikke holder i virkeligheden. Før vi beslutter scope for test-oprydning
(minimal reparation, moderat konsolidering, eller omfattende revision), har vi brug for
et faktuelt beslutningsgrundlag.

**Denne spec beskriver ikke selve oprydningen — kun en audit der genererer data til at
beslutte oprydningens scope.**

---

## Formål

Producér et reproducerbart, maskinlæsbart og menneskelæsbart beslutningsgrundlag der
kategoriserer alle 124 testfiler i `tests/testthat/` efter deres reelle status, så
projektets maintainer kan træffe informeret scope-beslutning for det efterfølgende
refactoring-arbejde (#203).

**Eksplicitte ikke-mål:**
- Reparere brækkede tests
- Slette eller konsolidere filer
- Beslutte arkitektur for fremtidig test-struktur
- Erstatte eller opdatere `refactor-code-quality`-specen

---

## Arkitektur

Ét genkørbart R-script i `dev/audit_tests.R` med tre sekventielle faser:

```
Fase 1: Statisk analyse           Fase 2: Dynamisk kørsel            Fase 3: Rapport
───────────────────────          ────────────────────────           ─────────────────
Scan tests/testthat/*.R           Kør hver fil isoleret via          Merge statisk + dynamisk
Parse funktionskald               callr::r(test_file)                 data
Sammenlign mod R/-exports         Fang stdout/stderr/exit code        Klassificér pr. fil
Tæl test_that/skip/LOC            Parse testthat-summary              Generér MD + JSON
Detektér deprecation-markers      Håndtér timeout (60s)               Udskriv summary til konsol
```

**Valg: Subproces-isolation via `callr`**
Hver testfil køres i egen R-subproces. Årsag: én fil der crasher R-processen påvirker
ikke resten. `helper.R` loades automatisk af `testthat` inde i subprocessen, så biSPCharts
pkg-state er konsistent pr. kørsel.

**Valg: Statisk + dynamisk analyse kombineret**
Statisk analyse alene kan ikke fortælle om en test *faktisk* kører grønt (logik-fejl,
timing, assertion-fejl). Dynamisk kørsel alene fanger ikke mønstre som stub-filer (0
tests), deprecation-markers, eller top-10 manglende funktioner på tværs af filer. Vi
har brug for begge.

---

## Komponenter

### `dev/audit_tests.R` (hovedscript)

Orkestrering: parse CLI-args, kør de tre faser sekventielt, skriv output.

**CLI-flag (valgfri):**
- `--filter=<regex>` — kør kun audit på matchende filnavne (for hurtig iteration)
- `--output-dir=<path>` — override default `dev/audit-output/`
- `--timeout=<seconds>` — override default 60s pr. testfil

### `dev/audit/static_analysis.R` (Fase 1-helpers)

Funktioner:
- `scan_test_files(dir)` → liste af filstier
- `extract_function_calls(file)` → character vector af kaldte funktionsnavne (via `utils::getParseData`)
- `list_r_exports()` → character vector af eksisterende funktioner i `R/` (via `pkgload::load_all()` + `ls(envir = asNamespace("biSPCharts"))`)
- `count_test_blocks(file)` → antal aktive (ikke-udkommenterede) `test_that()`/`it()`-blokke
- `detect_deprecation_marker(file)` → TRUE/FALSE (regex: `^#\s*DEPRECATED`)

### `dev/audit/dynamic_runner.R` (Fase 2-helpers)

Funktioner:
- `run_test_file_isolated(file, timeout)` → list med `exit_code`, `stdout`, `stderr`, `elapsed_s`, `testthat_summary`
- `parse_testthat_output(stdout)` → list med `n_pass`, `n_fail`, `n_skip`, `failed_tests[]`
- `extract_missing_functions(stderr)` → character vector af funktionsnavne fra `could not find function "X"`-mønstre
- `detect_api_drift(stderr)` → TRUE/FALSE (regex: `unused argument`, `argument .* is missing`)

### `dev/audit/classifier.R` (Fase 3-helpers)

Funktion:
- `classify_file(static_data, dynamic_data)` → character (én af 7 kategorier)

Prioriteret klassifikation (første match vinder):
1. `stub` — `n_test_blocks < 3`
2. `skipped-all` — subproces kører, men `n_pass == 0 && n_fail == 0 && n_skip > 0`
3. `broken-missing-fn` — `exit_code != 0 && length(missing_functions) > 0`
4. `broken-api-drift` — `exit_code != 0 && detect_api_drift == TRUE`
5. `broken-other` — `exit_code != 0` (alle andre årsager: timeout, parse-fejl, uventet exit)
6. `green-partial` — `exit_code == 0 && n_fail > 0`
7. `green` — `exit_code == 0 && n_fail == 0`

### `dev/audit/reporter.R` (Fase 3-helpers)

Funktioner:
- `write_json_report(results, path)` → skriv maskinlæsbar rapport
- `write_markdown_report(results, path)` → skriv menneskelæsbar rapport
- `print_console_summary(results)` → kort oversigt til stdout efter kørsel

---

## Data flow

**Input:**
- `tests/testthat/*.R` (124 filer forventet)
- `R/*.R` (loaded via `pkgload::load_all()` før audit starter)

**Intermediate (in-memory tibble):**
Én række pr. testfil med kolonner:

| Felt | Type | Kilde |
|------|------|-------|
| `file` | chr | Fase 1 |
| `loc` | int | Fase 1 |
| `last_modified` | POSIXct | Fase 1 |
| `n_test_blocks` | int | Fase 1 |
| `has_deprecation_marker` | lgl | Fase 1 |
| `function_calls` | list(chr) | Fase 1 |
| `missing_functions_static` | list(chr) | Fase 1 (diff mod R/-exports) |
| `exit_code` | int | Fase 2 |
| `elapsed_s` | dbl | Fase 2 |
| `n_pass` | int | Fase 2 |
| `n_fail` | int | Fase 2 |
| `n_skip` | int | Fase 2 |
| `missing_functions_runtime` | list(chr) | Fase 2 |
| `api_drift_detected` | lgl | Fase 2 |
| `stderr_snippet` | chr | Fase 2 (første 500 tegn) |
| `category` | chr | Fase 3 |

**Output:**
- `dev/audit-output/test-audit.json` — maskinlæsbar
- `docs/superpowers/specs/2026-04-17-test-audit-report.md` — menneskelæsbar

---

## Output-format

### JSON-struktur

```json
{
  "run_timestamp": "2026-04-17T14:23:00+02:00",
  "biSPCharts_version": "0.2.0",
  "r_version": "4.5.2",
  "total_files": 124,
  "total_elapsed_s": 187.4,
  "summary": {
    "green": 60,
    "green-partial": 10,
    "broken-missing-fn": 35,
    "broken-api-drift": 8,
    "broken-other": 5,
    "stub": 3,
    "skipped-all": 3
  },
  "top_missing_functions": [
    {"fn": "detect_columns_with_cache", "n_files": 12, "files": ["test-...", "..."]},
    {"fn": "apply_metadata_update", "n_files": 8, "files": ["..."]}
  ],
  "files": [
    {
      "file": "test-utils_validation_guards.R",
      "category": "broken-missing-fn",
      "loc": 234,
      "n_test_blocks": 15,
      "n_pass": 0,
      "n_fail": 0,
      "n_skip": 0,
      "exit_code": 1,
      "elapsed_s": 2.1,
      "missing_functions": ["validate_data_or_return", "appears_date"],
      "has_deprecation_marker": false,
      "stderr_snippet": "Error: could not find function ..."
    }
  ]
}
```

### Markdown-rapport

**Sektioner (i rækkefølge):**

1. **Header** — dato, biSPCharts-version, R-version, total kørselstid
2. **Executive summary** — tabel (kategori × antal × procent af total)
3. **Top-10 manglende R-funktioner** — prioriteret liste med antal kaldende filer
4. **Fil-liste pr. kategori** (i prioriteret rækkefølge: broken-missing-fn først)
   - For hver fil: navn, LOC, n_tests, stderr-snippet (hvor relevant)
5. **Forslag til scope-beslutning** — kort anbefaling baseret på fordelingen
   - Hvis >80 filer er green → minimal reparation foreslås
   - Hvis >40 filer har broken-missing-fn med samme top-5 funktioner → batched OpenSpec-proposals foreslås
   - Hvis >20 filer er stub/skipped-all → inkludér oprydning i scope

**Rapporten er dokumentation, ikke en plan** — beslutningen træffes af maintaineren efter review.

---

## Fejlhåndtering

| Scenario | Adfærd |
|----------|--------|
| Subproces timeout (>60s) | Marker `broken-other`, note: "timeout efter 60s" |
| Parse-fejl i testfil | Marker `broken-other`, stderr-snippet inkluderet |
| `pkgload::load_all()` fejler | Abort med klar fejl — audit kan ikke køre uden pkg-state |
| `helper.R` fejler i subproces | Første testfil fejler synligt; script fortsætter med øvrige filer men markerer første som `broken-other` |
| Ingen testfiler fundet | Abort med klar fejl |
| Eksisterende output overskrives | Advarsel til konsol, skriv alligevel (idempotent genkørsel) |
| CI-skip-guards der kun aktiveres i CI-miljø | Detektér via regex på skip-betingelser; lokal baseline kan afvige fra CI — dokumentér i rapport-header |

**Ingen retry-logik** — auditten er ren datafangst. Ved fejl: læs stderr, ret, genkør.

---

## Testing af selve auditten

**Unit-tests** (`tests/testthat/test-audit-classifier.R`):
- `classify_file()` med syntetisk input for hver af de 7 kategorier
- `extract_missing_functions()` med realistiske stderr-eksempler
- `detect_api_drift()` med positive og negative matches
- `count_test_blocks()` der ignorerer udkommenterede blokke

**Smoke-test** (manuel, én gang før fuld kørsel):
- Kør auditten på 3 kendte filer: én green (`test-config_chart_types.R`), én broken (`test-utils_validation_guards.R`), én stub
- Verificér output matcher forventet kategori

**Manuel verifikation efter første fulde kørsel:**
- Spot-check 5 tilfældige filer fra hver kategori
- Verificér at top-10 missing functions matcher grep på tværs af tests

---

## Performance & varighed

**Estimater:**
- Scripting: 3-4 timer
- Første fulde kørsel: 2-3 timer (124 filer × ~1-2s hver, nogle timeouts)
- Rapport-læsning/verifikation: 30-45 min

**Bottleneck:** `callr`-subproces-oprettelse er dyr (~1s pr. fil = ~2 min overhead). Acceptabelt for one-shot audit; ikke optimeret for CI-brug.

---

## Afhængigheder

**Pakker (nye eller bekræftet eksisterende):**
- `callr` (subproces-kørsel) — standard R-pakke
- `jsonlite` (JSON-output) — eksisterer i biSPCharts Imports
- `pkgload` (load_all) — eksisterer i dev-afhængigheder
- `testthat` (test-kørsel) — eksisterer

Ingen nye runtime-dependencies til biSPCharts.

---

## Deliverables

1. `dev/audit_tests.R` — hovedscript
2. `dev/audit/static_analysis.R`, `dynamic_runner.R`, `classifier.R`, `reporter.R` — moduler
3. `tests/testthat/test-audit-classifier.R` — unit-tests
4. `dev/audit-output/test-audit.json` — rapport (genereret)
5. `docs/superpowers/specs/2026-04-17-test-audit-report.md` — rapport (genereret)

---

## Næste skridt

Efter auditten er kørt og rapporten gennemgået:
1. Ny brainstorm-runde med reelle data om skadeomfang
2. Beslut scope: minimal / moderat / omfattende
3. Skriv spec for det valgte scope
4. Koordinér med `refactor-code-quality`-changen (erstatte Phase 1? parallelt spor?)
5. Implementér i batches via OpenSpec-proposals

---

## Relation til eksisterende arbejde

- **`refactor-code-quality` (openspec/changes/)** — Phase 1 (test-konsolidering) skal
  revideres på baggrund af audit-data. Phase 2-4 (R-fil-split, config) berøres ikke af
  denne audit.
- **Commit 834445d** — `test-anhoej-rules.R` skipped tests (allerede håndteret,
  dokumenterer præcedens for permanent-skip med rationale).
- **Commit 20b4724** — `--skip-tests`-flag (skal fjernes når #203 er lukket).
