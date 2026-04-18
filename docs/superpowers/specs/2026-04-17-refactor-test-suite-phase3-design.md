# Refactor Test Suite — Fase 3 "Fix TODOs + betinget fix-in-phase-3" Design

**Dato:** 2026-04-17
**Issue:** #203 (test-suite drift, publish-gate blokeret)
**OpenSpec change:** `refactor-test-suite-phase3` (planlagt)
**Status:** Design godkendt, afventer implementations-plan
**Foregående:**
- `2026-04-17-refactor-test-suite-phase1-design.md` (klassifikations-manifest)
- `2026-04-17-refactor-test-suite-phase2-design.md` (konsolidering)
- Change 1 `unblock-publish-test-gate` (fjernede broken-missing-fn)

---

## Baggrund

Efter Fase 2 (konsolidering) står test-suite med:

- 113 filer (reduceret fra 121)
- 292 failures (reduceret fra 302 — mål om <200 ikke opnået)
- **~124 TODO-SKIPs i 11 filer** fra Fase 2's rewrites, tagget
  `TODO Fase 3: R-bug afsløret — ... (#203-followup)`
- **43 `fix-in-phase-3`-filer** — lav-fejl green-partial filer der skal repareres
- 1 `rewrite`-fil tilbage (håndteres som fix-in-phase-3)

TODOs er primært R-bugs afsløret under Fase 2-rewrites:
- Manglende getter-funktioner (API asymmetri)
- Funktioner ikke i NAMESPACE-eksport
- Bug i `parse_danish_target` null-guard og y_axis_unit-håndtering
- Ikke-eksisterende funktioner i state-accessors

Top-5 TODO-tunge filer:

| Fil | TODO-count |
|---|---|
| `test-utils-state-accessors.R` | 34 |
| `test-parse-danish-target-unit-conversion.R` | 22 |
| `test-performance-benchmarks.R` | 19 |
| `test-cache-reactive-lazy-evaluation.R` | 15 |
| `test-label-placement-core.R` | 9 |

---

## Formål

Reducér test-suite fail-count ved at adressere TODO-SKIPs og betinget reparere
fix-in-phase-3-filer. Mål: `fail-count < 200` (fra 292).

---

## Eksplicitte ikke-mål

- **Ingen ny `rewrite`-arbejde** (1 tilbage fra Fase 2 håndteres som fix-in-phase-3)
- **Ingen ændringer i `R/*.R`** udenfor bruger-godkendte kategori 1-fixes
- **Ingen breaking changes** i R's public API
- **Ingen `NAMESPACE`-ændringer der fjerner exports** (kun tilføjelser)
- **Ingen test-arkitektur-standards** (Fase 4's ansvar)
- **Ingen CI-gate-tilføjelser** (Fase 4's ansvar)

---

## Arkitektur

Ét design → ét OpenSpec-change → build ovenpå `feat/refactor-test-suite-phase2`
→ subagent-drevet med 1 USER-STOP efter kategorisering + N USER-STOPs for
kategori 1 fixes (pr styk).

```
Trin 1: Kategorisér TODOs (124 SKIPs i 11 filer)
        ↓
        [CHECKPOINT: bruger reviewer kategoriseringsrapport]
        ↓
Trin 2: Autonom fix (kategori 2 NAMESPACE + kategori 3 test-bug)
        ↓
Trin 3: [CHECKPOINTS: bruger godkender kategori 1 R-fixes pr styk]
        ↓
Trin 4: Re-audit + beslutning (fix-in-phase-3 nødvendig?)
        ↓
Trin 5: Betinget fix-in-phase-3 (hvis fail-count ≥ 200)
        ↓
Trin 6: Verifikation + NEWS + evt. ADR
```

**Valg: Kategori 1-fixes enkeltvis godkendt**
R-kode-ændringer har høj blast-radius. Hver ændring præsenteres som minimal
diff + rationale; bruger godkender/afviser per styk før subagent implementerer.

**Valg: Betinget fix-in-phase-3 (Trin 5)**
Hvis TODO-resolution alene reducerer fail-count under 200 → Trin 5 droppes.
Hvis ikke → batch-fix på de 43 filer.

**Valg: Samme branch som Fase 2**
Fase 3 bygger ovenpå `feat/refactor-test-suite-phase2`. Én samlet merge til
master når begge er done.

---

## Kategori-definition

For hver af de ~124 TODO-SKIPs klassificeres til én af tre kategorier:

### Kategori 1 — R-kode-ændring kræves

- Bug i eksisterende R-funktion (fx null-guard, logic-fejl)
- Ændret forventet adfærd
- Behov for ny funktion for at opfylde forventet API

**Eksempler fra current TODOs:**
- `parse_danish_target(NULL)` kaster fejl → tilføj null-guard
- `y_axis_unit` ignoreres i legacy wrapper → fix logik

**Handling:** Bruger-godkendelse per styk (se Trin 3).

### Kategori 2 — NAMESPACE-export

- Funktion eksisterer internt i `R/*.R`, men mangler `#' @export`
- Signatur er OK, adfærd er OK

**Eksempler:**
- `get_original_data()`, `is_table_updating()`, `get_autodetect_status()` —
  hvis de faktisk er defineret i R/-filer men ikke eksporteret

**Handling:** Autonom fix via roxygen + `devtools::document()`.

### Kategori 3 — test-bug

- Test kalder ikke-eksisterende API (forventet adfærd findes under andet navn)
- Assertion er forkert (tester aldrig-specifikation)
- Test forudsætter state ikke setup korrekt

**Eksempler:**
- Test kalder `calculate_ucl()` men funktionen hedder `compute_ucl()` → fix test
- Test forventer error der ikke længere kastes → opdater assertion

**Handling:** Autonom fix i testfil.

---

## Trin-for-trin-plan

### Trin 1: Kategorisér TODOs (~1-2 t)

**Output:** `dev/audit-output/phase3-categorization-report.md` (midlertidig)

**Metode per TODO:**

```bash
# 1. Ekstrahér fn-navn fra skip-besked
# 2. Tjek om fn findes i R/
grep -rn "^<fn_name> <-\|^<fn_name>=" R/*.R

# 3a. Hvis findes + ikke i NAMESPACE → kategori 2
grep "^export(<fn_name>)" NAMESPACE

# 3b. Hvis findes + eksporteret → sammenlign forventet vs faktisk adfærd
# Hvis mismatch → kategori 1 (R-bug)

# 3c. Hvis ikke findes → grep efter similar navn
# Hvis tilsvarende findes → kategori 3 (test kalder forkert navn)
# Hvis intet tilsvarende → kategori 1 (ny funktion behøves)
```

**Rapport-struktur:**

```markdown
# Phase 3 Kategoriserings-rapport

## Kategori 1 (R-kode-ændring kræves)

| TODO | Fil | Linje | Problem | Foreslået fix |
|---|---|---|---|---|
| parse_danish_target(NULL) | test-parse-danish-target.R | 45 | Null-guard mangler | Tilføj `if (is.null(value)) return(NULL)` |

## Kategori 2 (NAMESPACE-export)

| TODO | Fil | Linje | Funktion | Defineret i |
|---|---|---|---|---|
| get_original_data | test-utils-state-accessors.R | 12 | `get_original_data` | R/state_management.R |

## Kategori 3 (test-bug)

| TODO | Fil | Linje | Problem | Fix |
|---|---|---|---|---|
| calculate_ucl vs compute_ucl | test-X.R | 45 | Test kalder gammelt navn | Omdøb til compute_ucl |
```

### CHECKPOINT 1: Bruger reviewer kategorisering

Bruger gennemgår rapporten og:
- Bekræfter kategoriseringen
- Kan omklassificere specifikke TODOs hvis uenig
- Godkender at Trin 2 starter med autonom fix

### Trin 2: Autonom fix (kategori 2 + 3) (~1-2 t)

#### Kategori 2 (NAMESPACE-export)

**Per fn:**
1. Tilføj `#' @export` til roxygen-block
2. Kør `Rscript -e "devtools::document()"` → regenererer NAMESPACE
3. Fjern `skip()` fra den nu-passerende test
4. Verificér: `Rscript -e "pkgload::load_all(); testthat::test_file('...')"`
5. Commit atomisk: `feat(R): export <fn_name> for test access (#203)`

#### Kategori 3 (test-bug)

**Per test:**
1. Opdater assertion/call til match nuværende R-adfærd
2. Fjern `skip()` hvis testen nu passer
3. Commit: `test: fix assertion i test-X.R (#203)`

### Trin 3: Kategori 1 bruger-godkendelse (per styk) (~1-3 t)

Subagent forbereder **patch-proposal per R-fix**:

```
Kategori 1 fix #N af M:
Fil: R/utils_parse_danish_target.R
Funktion: parse_danish_target
Problem: <beskrivelse>
Foreslået fix:
--- diff ---

Afsløret af: <test-fil:linje>
Bruger-valg: [a] apply [s] skip [m] modify
```

Bruger svarer `a`/`s`/`m` per proposal. Kun godkendte fixes implementeres.

**Commit-mønster:** `fix(R): <fn_name> <kort-beskrivelse> (#203)`

### Trin 4: Re-audit + beslutning (~10 min)

```bash
Rscript dev/audit_tests.R --timeout=60
```

**Beslutningsregel:**
- `fail-count < 200` → **drop Trin 5**, gå til Trin 6
- `fail-count ≥ 200` → **udfør Trin 5**

### Trin 5: Betinget fix-in-phase-3 (~3-5 t hvis udføres)

Salvage-first-approach (som Fase 2 Task 8b):
1. Kør fil isoleret
2. For hver failing test: fix assertion eller SKIP med TODO
3. Atomisk commit per fil (eller batches af 3-5)
4. Manifest-sync efter alle

### Trin 6: Verifikation og dokumentation (~30 min)

1. Regenerér audit + validér manifest + render rapport
2. Kør `Rscript dev/tests/run_tests.R`
3. Kør `Rscript -e "devtools::check()"` — ingen nye WARNINGs
4. NEWS-entry udvider Fase 2-sektionen med Fase 3
5. ADR hvis R-ændringer er arkitektoniske
6. Slet `phase3-categorization-report.md`

---

## Fejlhåndtering

| Scenario | Adfærd |
|---|---|
| Kategori 1 bruger afviser alle fixes | Drop R-ændringer, dokumentér i NEWS som "R-bugs known, fix deferred" |
| Kategori 2 NAMESPACE-fix bryder andre tests | Revert, re-kategoriser til kategori 1 |
| Kategori 3 test-fix afslører at kategori 2 var for optimistisk | Re-kategorisér, rapportér |
| Trin 5 afslører R-bug ikke fanget i Trin 1 | SKIP med TODO, log "Fase 4 follow-up" |
| devtools::document() overskriver manuel NAMESPACE | Løs konflikt før commit |

---

## Validering

**Efter hver fase:**
```bash
Rscript dev/classify_tests.R --validate
Rscript dev/tests/run_tests.R
Rscript dev/audit_tests.R --timeout=60
```

**Slutverifikation:**

1. Alle kategori-2 og -3 TODOs resolved
2. Kategori-1 TODOs enten fixed (godkendt) eller bevaret med opdateret rationale
3. Fail-count reduceret (mål <200, accepteret <292)
4. Manifest valid
5. `devtools::check()` ingen nye WARNINGs
6. `devtools::document()` har regenereret NAMESPACE korrekt

---

## Estimat

| Trin | Tid |
|---|---|
| Trin 1: Kategorisering | 1-2 t |
| Trin 2: Kategori 2+3 auto-fix | 1-2 t |
| [CHECKPOINT: bruger godkender kategori 1] | 30-60 min (bruger) |
| Trin 3: Kategori 1 R-fixes | 1-3 t |
| Trin 4: Re-audit + beslutning | 10 min |
| Trin 5: Betinget fix-in-phase-3 | 3-5 t (hvis udføres) |
| Trin 6: Verifikation + NEWS | 30 min |
| **Total** | **6-12 t** |

---

## Accept-kriterier

- [ ] Kategoriseringsrapport produceret og bruger-reviewet
- [ ] Alle kategori 2 (NAMESPACE) fixes implementeret uden regression
- [ ] Alle kategori 3 (test-bug) fixes implementeret
- [ ] Kategori 1 fixes: bruger-godkendt per styk
- [ ] Re-audit viser fail-count reduceret
- [ ] Hvis <200 ikke nået: Trin 5 udført
- [ ] NAMESPACE valideret via `devtools::check()`
- [ ] NEWS-entry opdateret med Fase 3-oversigt
- [ ] ADR oprettet hvis R-API udvidet
- [ ] Manifest synket

---

## Risici & modforanstaltninger

| Risiko | Sandsynlighed | Impact | Modforanstaltning |
|---|---|---|---|
| Kategori 1 R-ændringer bryder andre tests | Medium | Høj | Fuld audit efter hver R-fix; revert ved regression |
| NAMESPACE-fix eksponerer dårlig API | Lav | Medium | Tjek roxygen-doc før export; flag utvurderet |
| TODO-rationale misvisende → forkert kategorisering | Medium | Medium | Bruger reviewer kategoriseringsrapport (checkpoint 1) |
| Fix-in-phase-3 kaskade (flere R-bugs) | Medium | Medium | SKIP med TODO, Fase 4 follow-up |
| Godkendelses-proces tager for lang tid | Medium | Lav | Batch-godkendelse mulig (grupper) |
| devtools::document() overskriver manuel NAMESPACE | Høj | Medium | Kør tidligt; løs konflikter |

---

## Åbne spørgsmål (dokumenteres, løses ikke i Fase 3)

1. CI-gate der forhindrer nye TODO-SKIPs uden issue-reference? → Fase 4
2. Fail-count monitorering over tid? → Fase 4
3. Hvis mange kategori 1 R-bugs: separat bug-fix-release? → Bruger beslutter

---

## Deliverables

| Artefakt | Status |
|---|---|
| `feat/refactor-test-suite-phase2`-branch (udvidet med Fase 3) | Arbejdsbranch |
| `dev/audit-output/phase3-categorization-report.md` | Midlertidig |
| Opdaterede testfiler | Modify (11 TODO-filer + evt. 43 fix-in-phase-3) |
| Evt. `R/*.R`-ændringer | Kun bruger-godkendte kategori 1 |
| `NAMESPACE` | Auto-genereret via `devtools::document()` |
| `test-classification.yaml` | Synket |
| `test-audit.json` | Regenereret |
| `NEWS.md` | Udvid Fase 2-sektionen |
| Evt. ADR | `docs/adr/ADR-NNN-*.md` |

**Ingen ændringer til:**
- `dev/classify_tests.R` + helpers (Fase 1 leverancer)
- `dev/audit_tests.R`
- Ikke-godkendte R-funktioner

---

## Relation til eksisterende arbejde

- **Fase 2** (`feat/refactor-test-suite-phase2`): Fase 3 bygger ovenpå, samlet merge til master
- **Fase 4** (brainstormes efter Fase 3): test-arkitektur-standards + CI-gates
- **Change 1** (merged til master): forudsætning (broken-missing-fn = 0)

---

## Næste skridt

Efter brugers godkendelse:
1. Invoker `superpowers:writing-plans` for implementations-plan
2. Implementation fortsætter på `feat/refactor-test-suite-phase2` (allerede i worktree)
3. Subagent-driven med Sonnet + checkpoints
4. Samlet merge Fase 2+3 til master efter review
