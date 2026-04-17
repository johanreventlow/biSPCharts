# Refactor Test Suite — Fase 1 "Audit-verifikation" Design

**Dato:** 2026-04-17
**Issue:** #203 (test-suite drift, publish-gate blokeret)
**OpenSpec change:** `refactor-test-suite-phase1` (planlagt)
**Status:** Design godkendt, afventer implementations-plan
**Foregående:** `2026-04-17-test-audit-design.md` + audit-kørsel i `dev/audit-output/test-audit.json`

---

## Baggrund

Test-audit blev kørt 2026-04-17 og producerede strukturerede data om alle 124
testfiler (kategorier, fejl-statistik, manglende funktioner). Under brainstorming
af oprydning opdagede vi at audit-classifier's heuristik `n_test_blocks < 3 → stub`
systematisk misklassificerer værdifulde policy-tests (fx `test-namespace-integrity.R`,
`test-logging-debug-cat.R`, `test-dependency-namespace.R`) som stubs. Alle 9
"stubs" viste sig ved manuel inspektion at være aktive tests — policy-guards,
legacy-constant-tilgængelighed, eller reelle unit-tests der kun har 1-2
`test_that()`-blokke.

Lignende observation: de 2 "skipped-all" filer er bevidste E2E-gates
(`skip_on_ci()` + `skip_if_not_installed("shinytest2")`), ikke obsolete.

Den planlagte menneskelæsbare markdown-rapport
(`docs/superpowers/specs/2026-04-17-test-audit-report.md`) blev aldrig genereret
— vi har kun `test-audit.json`.

Uden en manuelt verificeret ground truth risikerer senere faser at slette
værdifulde tests (fx policy-guards der ligner stubs) eller merge'e uforenelige
test-typer (fx unit-tests og E2E-tests i samme fil).

---

## Formål

Producér et vedligeholdt, manuelt verificeret klassifikationsgrundlag for alle
124 testfiler — som fundament for Fase 2 (konsolidering), Fase 3 (fix) og
Fase 4 (standarder) i den kommende `refactor-test-suite`-arbejdsstrøm.

**Eksplicitte ikke-mål:**

- Ingen testfiler slettes, ændres eller flyttes
- Ingen `@audit-classification`-headers indsættes i testfiler
- Ingen testfejl fikses
- Ingen konsolidering udføres
- Audit-classifier-koden (`dev/audit_tests.R`) ændres ikke
- Fase 2, 3 og 4 i `refactor-test-suite` brainstormes separat efter Fase 1

---

## Afgrænsning ift. relaterede arbejder

| Arbejde | Relation til Fase 1 |
|---|---|
| `unblock-publish-test-gate` (Change 1) | Parallel. Fikser 4 `broken-missing-fn` filer + fjerner `--skip-tests`-flag. Fase 1 re-kører audit som første step, så seneste state reflekteres uanset Change 1-status. |
| `refactor-code-quality` Phase 1 (eksisterende) | Arkiveres i forbindelse med denne proposal (overhalet af audit-data: 124 filer, ikke 146; kun 9 reelle stubs, ikke 13-18). |
| `refactor-code-quality` Phase 2-4 (R-fil-split, config) | Uafhængig. Fortsætter parallelt uden afhængighed til Fase 1. |
| `refactor-test-suite` Fase 2-4 | Afhængig af Fase 1's output — YAML-manifest og rapport bruges som input til konsolidering, fix og standarder. |

---

## Arkitektur

Tre sekventielle steps i én branch, orkestreret via to scripts:

```
Step 1: Re-audit             Step 2: Auto-klassifikation        Step 3: Manuel review + output
─────────────────────       ────────────────────────────       ──────────────────────────────
Rscript dev/audit_tests.R   Rscript dev/classify_tests.R        Editor-drevet YAML-review +
→ ny test-audit.json         → starter-manifest.yaml             markdown-rapport-generering
(frisk data ved Fase 1      (heuristik baseret på filnavn       (alle 124 får type,
branching)                  + stderr-mønstre + indhold)         77 problematiske får handling)
```

**Valg: Separate scripts fremfor ét monoskript**
`dev/audit_tests.R` eksisterer allerede og producerer input-data.
`dev/classify_tests.R` tager JSON-output og producerer starter-YAML. Separation
tillader re-kørsel af klassifikation uden at re-køre 5-minutters audit.

**Valg: YAML fremfor JSON/CSV for manifest**
Human-editable (124 filer skal reviewes manuelt). Kommentarer tilladt.
Hierarkisk struktur matcher pr-fil-metadata. `yaml::read_yaml()` roundtripper
rent i R.

**Valg: Ingen `@audit-classification`-headers i testfiler (YAGNI)**
Vi ved ikke om manifestet faktisk konsulteres af fremtidige audits. YAML-manifest
er mindst invasiv første iteration; headers kan tilføjes i Fase 4 hvis de viser
sig nødvendige.

**Valg: `reviewed: false` som eksplicit default**
Auto-klassifikation sætter aldrig `reviewed: true`. Mennesket skal eksplicit
bekræfte hver entry. Dette sikrer at starter-YAML ikke utilsigtet markeres som
ground truth.

---

## Komponenter

### `dev/classify_tests.R` (nyt script, ~100-150 LOC)

**CLI-flag:**

- `--input=<path>` — default `dev/audit-output/test-audit.json`
- `--output=<path>` — default `dev/audit-output/test-classification.yaml`
- `--validate` — kør kun validering mod eksisterende manifest
- `--render-report` — generér markdown-rapport fra manifest + audit-JSON
- `--report-output=<path>` — default `docs/superpowers/specs/2026-04-17-test-audit-report.md`

**Funktioner:**

- `auto_classify(audit_json_path, tests_dir)` → list af fil-entries med foreslået
  `type` + `handling`
- `load_existing_manifest(path)` → returnerer eksisterende manifest eller `NULL`
- `merge_with_existing(auto, existing)` → respekterer `reviewed: true`; auto-felter
  overskriver kun `reviewed: false` entries
- `validate_manifest(manifest, tests_dir)` → konsistens-check (se Validering nedenfor)
- `render_report(manifest_path, audit_json_path, output_path)` → genererer markdown

### `dev/audit/README.md` (opdateret)

Tilføj sektion: "Fra audit til klassifikation" med workflow:

1. Kør `dev/audit_tests.R`
2. Kør `dev/classify_tests.R` (auto-klassifikation)
3. Review YAML manuelt
4. Kør `dev/classify_tests.R --validate`
5. Kør `dev/classify_tests.R --render-report`

### Auto-klassifikations-heuristik

**Type-dimension** (prioriteret, første match vinder):

| Trigger | Type |
|---|---|
| `skip_on_ci()` eller `shinytest2` eller `AppDriver$new` i filen | `e2e` |
| Filnavn matcher `benchmark|performance` | `benchmark` |
| Filnavn matcher `snapshot` eller fil indeholder `expect_snapshot` | `snapshot` |
| Filnavn matcher `namespace|integrity|policy|guard|dependency` eller filindhold tester `list.files(R/...)` | `policy-guard` |
| Filnavn matcher `mod-|integration|e2e-|workflow` | `integration` |
| Fil har `create_test_fixture|fixture_path|test_path\(".*\.(csv|rds|xlsx)"` | `fixture-based` |
| Default | `unit` |

**Handling-dimension** (baseret på audit-kategori):

| Audit-kategori | Foreslået handling |
|---|---|
| `green` | `keep` |
| `green-partial` hvor fail/total < 50% | `fix-in-phase-3` |
| `green-partial` hvor fail/total ≥ 50% | `needs-triage` |
| `stub` | `needs-triage` (vi ved nu de ofte er værdifulde) |
| `skipped-all` | `keep` (bevidst gated) |
| `broken-missing-fn` | `blocked-by-change-1` |

**Alle entries får initialt `reviewed: false`.**

---

## Data flow

**Input:**

- `dev/audit-output/test-audit.json` (regenereret som step 1 i Fase 1)
- `tests/testthat/*.R` (kildefiler for indholds-heuristik)

**Output:**

- `dev/audit-output/test-classification.yaml` (YAML-manifest, 124 entries)
- `docs/superpowers/specs/2026-04-17-test-audit-report.md` (menneskelæsbar rapport)

**Ingen ændringer til:**

- `tests/testthat/*.R`
- `R/*.R`
- `dev/audit_tests.R`
- `openspec/changes/refactor-code-quality/*`

---

## YAML-manifest-format

Fil: `dev/audit-output/test-classification.yaml`.

```yaml
# Test Classification Manifest
# Generated: 2026-04-17
# Audit source: dev/audit-output/test-audit.json
# Purpose: Ground truth for test-file classification, driving Change 2 phases 2-4
#
# Fields:
#   audit_category: read-only reference (sync'd fra test-audit.json)
#   type:           policy-guard | unit | integration | e2e | benchmark | snapshot | fixture-based
#   handling:       keep | fix-in-phase-3 | merge-in-phase-2 | archive | rewrite | blocked-by-change-1 | needs-triage
#                   NB: `needs-triage` er en auto-klassifikations-placeholder.
#                   Ikke tilladt når reviewed: true — mennesket skal konvertere til endelig handling.
#   merge_with:     (optional) liste af filnavne denne fil skal merges med
#   rationale:      (påkrævet når handling ≠ keep) kort begrundelse for valgt handling
#   reviewed:       bool (default false fra auto-klassifikation; sæt true når type OG handling er verificeret)
#   reviewer:       github-username (når reviewed: true)
#   reviewed_date:  ISO date (når reviewed: true)

metadata:
  total_files: 124
  audit_run: "2026-04-17T13:21:25+0200"
  manifest_schema_version: "1.0"
  review_status:
    reviewed: 0
    unreviewed: 124
    needs_triage: 77

files:
  - file: test-namespace-integrity.R
    audit_category: stub
    type: policy-guard
    handling: keep
    rationale: "Guard mod NAMESPACE-eksport af simple ord. Misklassificeret som stub pga. 1 test_that-block."
    reviewed: true
    reviewer: johanreventlow
    reviewed_date: 2026-04-17

  - file: test-parse-danish-target-unit-conversion.R
    audit_category: green-partial
    type: unit
    handling: fix-in-phase-3
    rationale: "65/73 fejl mod normalize_axis_value; API har skiftet efter validation-rewrite."
    reviewed: true
    reviewer: johanreventlow
    reviewed_date: 2026-04-17

  - file: test-autodetect-core.R
    audit_category: green
    type: unit
    handling: merge-in-phase-2
    merge_with:
      - test-autodetect-unified-comprehensive.R
    rationale: "Overlap med unified-comprehensive; bevar unik edge-case coverage ved merge."
    reviewed: true
    reviewer: johanreventlow
    reviewed_date: 2026-04-17

  - file: test-e2e-user-workflows.R
    audit_category: skipped-all
    type: e2e
    handling: keep
    rationale: "Bevidst skip_on_ci(); kører lokalt med shinytest2."
    reviewed: true
    reviewer: johanreventlow
    reviewed_date: 2026-04-17

  # ... 120 filer mere
```

**Design-beslutninger:**

1. **`audit_category` er read-only reference** til audit-JSON — point-in-time-data,
   ikke beslutning. Ved re-audit synces dette felt fra ny JSON.
2. **`reviewed: false` default fra auto-klassifikation** — eksplicit opt-in til
   ground truth.
3. **`merge_with` er valgfri + symmetrisk** — hvis A har `merge_with: [B]`, skal
   B's entry også reflektere det. Valideres af `validate_manifest()`.
4. **Schema-version** for fremtidig bagudkompatibilitet.
5. **Intet `priority`-felt** — handling-kategorien implicerer rækkefølgen
   (`blocked-by-change-1` først, så `archive`, så `merge-in-phase-2`, så
   `fix-in-phase-3`).

---

## Markdown-rapport-struktur

Fil: `docs/superpowers/specs/2026-04-17-test-audit-report.md`. Genereret via
`dev/classify_tests.R --render-report`.

Sektioner:

1. **Header** — dato, biSPCharts-version, R-version, audit-timestamp, total kørselstid
2. **Executive summary** — kategori-tabel (fra audit-JSON) + type-tabel (fra manifest) + top-5 stderr-mønstre
3. **Kritiske fund** — dokumentér classifier-limitationer og deres implikationer
4. **Pr-fil klassifikations-tabel** — fuld tabel med kategori + type + handling + rationale, sorteret efter handling
5. **Handling-oversigt** (beslutningsgrundlag for senere faser):
   - Blocked by Change 1 (4 filer)
   - Arkiveres i Fase 2 (X filer med rationale)
   - Merges i Fase 2 (Y filer, Z merge-grupper)
   - Fixes i Fase 3 (N filer, M fejl, top-mønstre)
   - Rewrites i Fase 3 (få filer hvor fix-scope > gevinst)
   - Keep as-is (resterende filer)
6. **Top-10 fejlmønstre** — input til batched fix-strategi i Fase 3
7. **Foreslået sekvens for Fase 2-4** — kort anbefaling, ikke implementations-plan
8. **Audit-classifier-limitationer** — dokumenteret for fremtidig forbedring
9. **Appendix** — fuld audit-kategori-tabel med fil-lister og fejl-statistik

---

## Fejlhåndtering

| Scenario | Adfærd |
|---|---|
| `test-audit.json` mangler | Abort med klar fejl: "Kør `dev/audit_tests.R` først" |
| YAML-syntaxfejl ved load | Abort med linje-nummer |
| Ukendt `type` eller `handling` værdi | `validate` fejler med liste af ugyldige entries |
| Asymmetrisk `merge_with` | `validate` fejler med konkret eksempel |
| Fil i `tests/testthat/` mangler i manifest | `validate` fejler med liste af manglende filer |
| Entry for fil der ikke længere eksisterer | `validate` fejler med liste af forældede entries |
| `reviewed: true` uden `rationale`/`reviewer`/`reviewed_date` | `validate` fejler per entry |
| Re-kørsel af `classify_tests.R` på eksisterende manifest | Bevar `reviewed: true` entries; opdatér kun `audit_category` fra frisk JSON; auto-klassificer nye filer |

**Ingen retry-logik.** Validation er enten pass eller fail. Ved fejl: læs besked, ret manifest, re-validér.

---

## Validering

`dev/classify_tests.R --validate` tjekker:

| Check | Fejl ved |
|---|---|
| Schema-compliance | Ukendt `type` eller `handling` værdi |
| Ingen placeholder-handling | `reviewed: true` med `handling: needs-triage` |
| Symmetrisk `merge_with` | A har `merge_with: [B]`, men B mangler entry eller mangler `merge_with: [A]` |
| `merge_with` kun ved merge-handling | `merge_with` udfyldt på entry med `handling ≠ merge-in-phase-2` |
| Audit-kategori-konsistens | `audit_category` i manifest matcher ikke JSON |
| Manglende rationale | `handling ≠ keep` uden `rationale` |
| Manglende reviewer-metadata | `reviewed: true` uden `reviewer` eller `reviewed_date` |
| Alle filer dækket | Filer i `tests/testthat/*.R` der mangler i manifest |
| Ingen forældede entries | Entries for filer der ikke længere eksisterer |

**Ingen unit-tests i `tests/testthat/`** for `dev/classify_tests.R` — det er
dev-tooling uden for publish-gate. Inline validering + manuel smoke-test på
real data er tilstrækkelig.

---

## Accept-kriterier for Fase 1 færdig

- [ ] `test-audit.json` regenereret med frisk `run_timestamp` (step 1)
- [ ] `dev/classify_tests.R` eksisterer og er funktionsdygtig
- [ ] `test-classification.yaml` indeholder entry for alle 124 filer
- [ ] Alle 124 har `type` udfyldt (alle 7 værdier mulige: policy-guard/unit/integration/e2e/benchmark/snapshot/fixture-based)
- [ ] Alle 124 har `handling` udfyldt (ingen `needs-triage` placeholder tilbage)
- [ ] Alle 124 har `reviewed: true` + `reviewer` + `reviewed_date`
- [ ] Alle filer med `handling ≠ keep` har `rationale` (forventet ~77 filer)
- [ ] Ingen asymmetriske `merge_with`-relationer
- [ ] `Rscript dev/classify_tests.R --validate` exit 0
- [ ] `docs/superpowers/specs/2026-04-17-test-audit-report.md` genereret uden warnings
- [ ] Rapporten reviewet af maintainer (sanity-check)
- [ ] `refactor-code-quality` Phase 1 arkiveret i OpenSpec (overhalet)

---

## Performance & varighed

| Step | Tid |
|---|---|
| Skriv `dev/classify_tests.R` | 3-4 t |
| Step 1: Re-audit (`dev/audit_tests.R`) | 5 min |
| Step 2: Auto-klassifikation | 2 min |
| Step 3a: Bekræft type for 47 grønne filer (auto-klassifikation stort set korrekt; spot-check + `reviewed: true`) | 30-45 min |
| Step 3b: Review type + vælg handling + skriv rationale for 77 problematiske | 4-5 t |
| Step 4: Render rapport | 5 min |
| Manual rapport-review + iteration | 30-60 min |
| **Total** | **8-11 t** |

---

## Afhængigheder

**Pakker (bekræftet eksisterende):**

- `yaml` (manifest read/write) — eksisterer i biSPCharts Imports
- `jsonlite` (audit-JSON load) — eksisterer
- `testthat`, `pkgload` — eksisterer

Ingen nye runtime-dependencies.

---

## Deliverables

1. `dev/classify_tests.R` — nyt script (~100-150 LOC)
2. `dev/audit-output/test-audit.json` — regenereret
3. `dev/audit-output/test-classification.yaml` — genereret + manuelt reviewed
4. `docs/superpowers/specs/2026-04-17-test-audit-report.md` — genereret
5. `dev/audit/README.md` — opdateret med klassifikations-workflow
6. `openspec/changes/archive/refactor-code-quality-phase1/` — arkiveret (overhalet)

---

## Risici & modforanstaltninger

| Risiko | Sandsynlighed | Impact | Modforanstaltning |
|---|---|---|---|
| Auto-klassifikation har for mange false positives → manuel review bliver lang | Medium | Medium | Start med 20 auto-klassificerede filer, justér heuristik før fuld kørsel |
| YAML-manifestet drifter fra virkeligheden efter Fase 2-4 | Høj langsigtet | Lav akut | Fase 2-4-specs inkluderer manifest-opdatering i deres tasks; validér før merge |
| Manuel reviewer-uenighed om handling-kategori | Lav | Lav | `rationale`-feltet tvinger begrundelse; alle beslutninger reversible i senere faser |
| Fase 1 bliver "analyse paralysis" uden handlingsudbytte | Medium | Medium | Time-boxing: max 11 t; deliverables frem for perfektion; sektion 7 i rapporten dokumenterer åbne spørgsmål |
| Re-audit ændrer kategorier mellem Change 1 og Fase 1 | Høj | Lav | `audit_category` i manifest er pr-audit-snapshot; audit `run_timestamp` noteres i manifest + rapport |
| `classify_tests.R`'s auto-klassifikation overskriver manuelt reviewed entries | Lav | Høj | `merge_with_existing()` respekterer `reviewed: true`; smoke-test eksplicit |

---

## Åbne spørgsmål (dokumenteres i rapporten, løses ikke i Fase 1)

1. Skal audit-classifier's `n_test_blocks < 3`-heuristik erstattes med
   manifest-baseret klassifikation? → Fase 4 (standarder)
2. Skal der være en CI-check der validerer at nye testfiler har manifest-entry?
   → Fase 4 (standarder)
3. Hvilke af de 62 green-partial filer deler fejl-årsag og kan fixes batched?
   → Fase 3 (fix)
4. Hvor stort overlap er der mellem grønne filer (merge-kandidater)?
   → Fase 2 (konsolidering)
5. Skal `dev/audit_tests.R` opdateres med bedre classifier-heuristik baseret på
   manifest-ground-truth? → Separat proposal, sandsynligvis efter Fase 4

---

## Næste skridt

Efter Fase 1 er færdig og rapport + manifest er committed:

1. Skriv OpenSpec-proposal `refactor-test-suite-phase1` med tasks.md baseret på
   denne spec (invoker `superpowers:writing-plans` skill)
2. Implementér på separat branch `feat/refactor-test-suite-phase1`
3. Brainstorm Fase 2 (konsolidering) med manifestet som input
4. Brainstorm Fase 3 (fix) med top-10 fejlmønstre som input
5. Brainstorm Fase 4 (standarder) når Fase 2-3 er afsluttet

---

## Relation til eksisterende arbejde

- **`unblock-publish-test-gate` (Change 1):** Parallel. Fase 1 re-kører audit som
  første step for at reflektere seneste state uanset Change 1-status.
- **`refactor-code-quality` Phase 1:** Arkiveres (overhalet af audit-data — kun 9
  reelle stubs vs. planlagt 13-18 sletninger; 124 filer vs. 146; merge-planen var
  baseret på forældede tal).
- **`refactor-code-quality` Phase 2-4:** Uafhængig. Fortsætter parallelt.
- **`2026-04-17-test-audit-design.md`:** Foregående spec der definerede selve audit-scriptet.
- **Commit 834445d:** `test-anhoej-rules.R` permanent-skip med rationale — etablerer
  præcedens for type=`unit` + handling=`keep` med skip-guards.
- **Commit 20b4724:** `--skip-tests`-flaget — fjernes i Change 1, ikke Fase 1.
