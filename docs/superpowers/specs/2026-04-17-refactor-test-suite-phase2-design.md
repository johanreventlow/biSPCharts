# Refactor Test Suite — Fase 2 "Konsolidering" Design

**Dato:** 2026-04-17
**Issue:** #203 (test-suite drift, publish-gate blokeret)
**OpenSpec change:** `refactor-test-suite-phase2` (planlagt)
**Status:** Design godkendt, afventer implementations-plan
**Foregående:**
- `2026-04-17-refactor-test-suite-phase1-design.md` (klassifikations-manifest)
- Change 1 `unblock-publish-test-gate` (fjernede 4 broken-missing-fn filer)

---

## Baggrund

Efter Fase 1 (audit-verifikation) og Change 1 (unblock publish-gate) har
biSPCharts test-suite 121 filer klassificeret i
`dev/audit-output/test-classification.yaml`:

- **59 `keep`** — grønne + korrigerede stubs + skipped-all E2E-gates
- **45 `fix-in-phase-3`** — lav-fejl green-partial, reparerbar
- **17 `rewrite`** — høj-fejl green-partial (≥50% fail), genskrivning billigere end fix
- **0 `merge-in-phase-2`** og **0 `archive`** — ingen identificeret under konservativ Fase 1-review

Filnavn-kluster-analyse afslører 7 potentielle merge-klustre (17 filer):

| Cluster | Filer |
|---|---|
| y-axis-* | 4 |
| critical-fixes-* | 3 |
| event-system-* | 2 |
| file-operations-* | 2 |
| label-placement-* | 2 |
| mod-spc-* | 2 |
| plot-generation-* | 2 |

Desuden er der overlap mellem rewrite-kandidater og merge-kandidater (fx
`test-label-placement-bounds.R` og `test-label-placement-core.R` er **både**
rewrite- og merge-kandidater).

---

## Formål

Reducér test-suite's overflade ved tre destruktive operationer:

1. **Archive** forældede filer (feature fjernet/migreret eller duplikeret)
2. **Merge** overlappende klustre til canonical-filer
3. **Rewrite** høj-fejl-filer mod faktisk R/-kildekode

Output: clean baseline for Fase 3 (`fix-in-phase-3`-reparation).

---

## Eksplicitte ikke-mål

- **Ingen fejl-fix af `fix-in-phase-3`-filer** (Fase 3's ansvar)
- **Ingen test-arkitektur-standards** (Fase 4's ansvar)
- **Ingen ændringer i `R/*.R`** medmindre rewrite afslører blokerende bug —
  i så fald SKIP og log til Fase 3-follow-up
- **Ingen benchmark-merge/restrukturering** — benchmarks har egne kriterier
- **Ingen NAMESPACE-ændringer**

---

## Arkitektur

Ét design-dokument → ét OpenSpec-change → én branch
(`feat/refactor-test-suite-phase2`) fra master → én subagent-kørsel med
**1 checkpoint** efter Analyse-trin.

```
Analyse → [CHECKPOINT: bruger review af analyse-rapport]
        → Archive → Merge → Rewrite → Verifikation → Final rapport
```

**Valg: Checkpoint kun efter analyse**
Archive + merge + rewrite-trin er deterministiske nok efter analyse er udført.
Hvis unexpected issues opstår undervejs: subagent rapporterer BLOCKED.
Minimerer brugervenlig friction.

**Valg: Én branch brancheret fra master**
Master har nu Fase 1 + Change 1 merged. Fase 2 bygger ovenpå.

**Valg: Manifest som single source of truth**
`test-classification.yaml` opdateres efter hver destruktive operation.
Validator (`classify_tests.R --validate`) fanger inkonsistens.

---

## Trin-for-trin-plan

### Trin 1: Analyse (~1-1.5 t)

**Output:** `dev/audit-output/phase2-analysis-report.md` (midlertidig, slettes før merge)

#### 1a. Archive-kandidat-scan

Kriterier (en fil kvalificeres hvis **≥2** er matched):

1. **Tester fjernet feature** — git-forensics viser feature er permanent slettet
2. **Tester migreret funktionalitet** — feature flyttet til BFHcharts/BFHtheme/BFHllm/Ragnar
3. **Fuldt duplikeret** — 100% overlap med anden fil der er teknisk bedre
4. **Legacy-fil fra tidligere fase** — filnavn indikerer forældelse (fx `test-phase*.R`, `test-fase*.R`, `test-sprint*.R`)

**Scan-procedure per kandidat:**
```bash
# Feature-fjernelse
git log --all --source --follow -S '<feature_name>' -- 'R/*.R'

# Migreret?
git log --all --source --follow -S '<fn>' -- 'R/*.R' | grep -i "bfhcharts\|bfhtheme\|bfhllm\|ragnar"

# Legacy-filnavne
ls tests/testthat/ | grep -E '(test-phase|test-fase|test-sprint)'
```

**Tvivl:** Flag til bruger, ikke autonom beslutning.

#### 1b. Merge-kluster-verifikation

For hver af de 7 klustre: verificér at alle tre merge-kriterier er opfyldt:

1. **Tema-sammenhæng** — alle filer tester samme concern
2. **Filstørrelse-begrænsning** — resulterende fil < 500 LOC
3. **Type-kompatibilitet** — kun samme `type` (unit+unit, ikke unit+benchmark)

**Overlap-analyse per kluster:**
```bash
for f in tests/testthat/test-<prefix>-*.R; do
  grep -c "test_that" "$f"
  grep "test_that" "$f" | head -5
done
```

**Forventede udfald (baseret på filnavne — verificér!):**

| Cluster | Forventet | Bekræft ved |
|---|---|---|
| y-axis (4) | Merge → 1 | Tema OK, total LOC < 500, alle unit |
| critical-fixes (3) | **Behold separat** | Suffix `integration/regression/security` = 3 forskellige concerns |
| event-system (2) | Merge → 1 | `emit + observers` tæt relateret |
| file-operations (2) | Verificér | `tidyverse + ikke-tidyverse` — mulig merge |
| label-placement (2) | Merge → 1 | `bounds + core` tæt relateret |
| mod-spc (2) | Verificér | `comprehensive + integration` — mulig merge |
| plot-generation (2) | **Behold separat** | `performance` (benchmark) ≠ `plot-generation` (unit) |

#### 1c. Rewrite-hybrid-auto-downgrade

For hver af de 17 rewrite-kandidater, tæl test-blokke:

- **Lille (1-3 tests, høj fail)** — auto-downgrade til **archive** eller **merge**
- **Mellem (4-15 tests)** — salvage-first
- **Stor (>15 tests)** — klassisk TDD-rewrite

**Auto-downgrade-regel:**
- 1 test + 100% fail → arkivér (lav værdi)
- Matcher merge-kluster → merge ind i kluster-canonical

**Forventet auto-downgrade:**
- `test-label-placement-bounds.R` (1/1 fail) → merge (matcher label-placement-kluster)
- `test-label-placement-core.R` (1/1 fail) → merge (matcher label-placement-kluster)
- `test-y-axis-mapping.R` (3/3 fail) → merge (matcher y-axis-kluster)
- `test-y-axis-model.R` (3/3 fail) → merge (matcher y-axis-kluster)
- `test-constants-architecture.R` (1/1 fail) → verificér; arkivér hvis dead
- `test-label-height-estimation.R` (1/1 fail) → verificér
- `test-npc-mapper.R` (1/1 fail) → verificér

Dette reducerer sandsynligvis de 17 rewrites til 8-10 egentlige rewrites.

#### Analyse-rapport-struktur

Subagent producerer `dev/audit-output/phase2-analysis-report.md`:

1. **Archive-sektion** — tabel: fil × matched kriterier × foreslået handling
2. **Merge-sektion** — per kluster: overlap-verifikation, foreslået canonical-filnavn, liste af filer der merges, begrundelse hvis IKKE merge
3. **Rewrite-sektion** — per fil: størrelses-kategori, auto-downgrade-forslag, TDD-plan hvis rewrite
4. **Net-effekt** — forventet reduktion (fx "121 → 104, sparer 17")

### CHECKPOINT — USER-STOP

Bruger reviewer analyse-rapport og godkender/justerer forslag før subagent fortsætter til destruktive trin.

**Bruger-actions:**
- Accepter alle forslag → subagent fortsætter
- Justér specifikke forslag → subagent opdaterer og fortsætter
- Afvis hele pass → re-brainstorm

### Trin 2: Archive (~30-45 min)

**Per-fil-metodik:**
1. `git rm tests/testthat/test-X.R`
2. Commit atomisk: `test: arkivér test-X.R — <kriterier> (#203)`
3. Efter alle arkiveringer: opdatér manifest (fjern entries), sync counters

### Trin 3: Merge (~2-3 t)

**Per-kluster-metodik:**
1. Identificér canonical-fil (mest omfattende eller nyeste)
2. Åbn alle kluster-filer
3. Saml unikke test-blokke (drop duplikerede assertion-sets)
4. Skriv til canonical-fil med sektion-kommentarer:
   ```r
   # ===== Y-AXIS FORMATTING =====
   # (fra test-y-axis-formatting.R)
   ...

   # ===== Y-AXIS MAPPING =====
   # (fra test-y-axis-mapping.R)
   ...
   ```
5. `git rm` øvrige filer
6. Verificér canonical-fil: `Rscript -e "pkgload::load_all(); testthat::test_file('tests/testthat/test-<canonical>.R')"`
7. Commit: `test: merge <kluster>-testfiler til <canonical> (#203)`
8. Opdatér manifest (fjern merged, opdatér canonical med udvidet rationale)

### Trin 4: Rewrite (~3-4 t)

**Hybrid-approach efter size:**

#### TDD-approach (store filer, >15 tests)

1. Læs R/-kildefil(er)
2. Identificér public API (eksporterede funktioner)
3. Delete eksisterende test-fil-indhold
4. Skriv tests først for hvert public API-punkt
5. Kør tests; hvis FAIL afslører R-bug: SKIP med TODO
6. Commit: `test: rewrite test-X.R mod nuværende R-API (#203)`

#### Salvage-approach (mellem, 4-15 tests)

1. Kør fil, identificér failing tests
2. For hver: undersøg R/-kildekode, verificér forventet output
3. Fix assertion eller SKIP med TODO
4. Commit atomisk

#### Scope-protection

Hvis rewrite afslører faktisk R-bug:
- Subagent **logger** det i rapport
- SKIPper testen
- **Ingen R-ændringer i Fase 2** — deferres til separat proposal

### Trin 5: Verifikation og finalisering (~20 min)

1. Regenerér audit: `Rscript dev/audit_tests.R --timeout=60`
2. Validér manifest: `Rscript dev/classify_tests.R --validate`
3. Render rapport: `Rscript dev/classify_tests.R --render-report`
4. Kør dev-tests: `Rscript dev/tests/run_tests.R`
5. Commit audit + manifest-sync: `chore(audit): sync efter Fase 2-konsolidering (#203)`

### Trin 6: Dokumentation (~15 min)

**NEWS.md-entry:**

```markdown
# biSPCharts X.Y.Z-dev (development)

## Interne ændringer

* **Test-suite konsolidering (#203, Fase 2):** Reducerede test-suite fra 121 til
  ~100-110 filer gennem arkivering af obsolete filer, merge af overlappende
  klustre, og rewrite af høj-fejl-filer.
  - Arkiveret: N filer (fx test-X.R — tester fjernet feature)
  - Merged: M klustre konsolideret til canonical-filer
    (fx y-axis-* merged til test-y-axis.R)
  - Rewritten: K filer genskrevet mod nuværende R/-API
* Manifest: `dev/audit-output/test-classification.yaml` er synket med nye filtal.
* Fail-count reduceret fra 302 til <200 (forventet).
```

**OpenSpec-arkivering:**
```bash
openspec archive refactor-test-suite-phase2 --yes
```

---

## Fejlhåndtering

| Scenario | Adfærd |
|---|---|
| Merge producerer fil > 500 LOC | Stop, rapportér til bruger |
| Rewrite-fil har 0 matching R-funktioner | Flag som archive-kandidat, ikke rewrite |
| Tests stadig fejler efter rewrite | SKIP med TODO + log i rapport |
| Forensics tvivl om en fil | Flag til bruger, ikke autonom |
| Type-mismatch i kluster | Flag til bruger |
| Critical-fixes har skjult overlap trods forskellige suffix | Analyse scanner indhold, ikke kun filnavn |
| R-bug afsløret under rewrite | SKIP + log til Fase 3-follow-up |

---

## Validering

**Efter hver destruktive operation:**

```bash
Rscript dev/classify_tests.R --validate
Rscript dev/tests/run_tests.R
Rscript dev/audit_tests.R --timeout=60
```

**Slutverifikation:**

1. `broken-missing-fn = 0` (ingen regression fra Change 1)
2. Ingen ny kategori værre end før
3. Total fail-count reduceret eller stabil
4. Manifest valid med korrekt count
5. Ingen fil i `tests/testthat/` mangler manifest-entry

---

## Estimat

| Trin | Tid |
|---|---|
| Analyse + checkpoint-rapport | 1-1.5 t |
| [USER-STOP: review + accept] | ~15 min |
| Archive | 30-45 min |
| Merge | 2-3 t |
| Rewrite | 3-4 t |
| Final audit + manifest-sync + rapport-render | 20 min |
| Dokumentation (NEWS-entry) | 15 min |
| **Total** | **7-9 t** |

---

## Accept-kriterier

- [ ] Analyse-rapport produceret og bruger-reviewet
- [ ] Alle archive-kandidater opfylder ≥2 af 4 kriterier
- [ ] Alle merged filer opfylder alle 3 merge-kriterier (tema + <500 LOC + type-match)
- [ ] Alle rewrite-filer følger hybrid-approach efter size
- [ ] Manifest synket efter hver destruktive operation
- [ ] Total file-count reduceret (forventet: 121 → 100-110)
- [ ] `broken-missing-fn = 0` (ingen regression)
- [ ] Fail-count reduceret eller stabil (rewrite mål: <200 fails fra 302)
- [ ] NEWS-entry skrevet
- [ ] OpenSpec change klar til arkivering

---

## Risici & modforanstaltninger

| Risiko | Sandsynlighed | Impact | Modforanstaltning |
|---|---|---|---|
| Auto-downgrade mister meningsfuld test-dækning | Medium | Medium | 2+ kriterier krav; 1 match = flag til bruger |
| Merge giver fil > 500 LOC | Lav | Lav | Stop-and-report; bruger beslutter split |
| Rewrite afslører R-bug | Medium | Medium | SKIP + TODO; scope-protection |
| Type-mismatch i kluster | Lav | Lav | Type-check i analyse |
| Critical-fixes har skjult overlap | Lav | Lav | Analyse scanner indhold |
| Subagent for aggressiv ift. dead-code | Lav (lært af Fase 1) | Høj | Forensics + 2-kriterie-regel |
| Afslører behov for R-ændringer | Medium | Medium | Scope-protection; deferre til separat proposal |
| Klustre overlapper ikke som antaget | Medium | Lav | Checkpoint fanger dette |

---

## Åbne spørgsmål (dokumenteres, løses ikke i Fase 2)

1. Skal auto-downgrade-reglen være yderligere restriktiv? → Fase 4 (standarder)
2. Skal der være per-test-fil LOC-warning i CI? → Fase 4
3. Hvad med tests der tester BFHcharts-sibling-funktionalitet direkte? → Separat spec-diskussion

---

## Deliverables

| Artefakt | Status |
|---|---|
| `feat/refactor-test-suite-phase2`-branch fra master | Oprettes i implementation |
| `dev/audit-output/phase2-analysis-report.md` | Midlertidig, slettes før merge |
| Arkiverede filer (`git rm` commits) | Én commit pr. fil |
| Merged klustre (canonical + `git rm` kildes) | Én commit pr. kluster |
| Rewrite-output (erstatter filindhold) | Én commit pr. fil |
| `test-classification.yaml` synket | Efter hver destruktive operation |
| `test-audit.json` regenereret | Final |
| `2026-04-17-test-audit-report.md` re-renderet | Final |
| `NEWS.md`-entry | Final commit |
| OpenSpec archive | Efter merge |

**Ingen ændringer til:**
- `R/*.R` (undtaget hvis rewrite afslører bug, der isoleres i separat proposal)
- `dev/classify_tests.R` + helpers (Fase 1 leverancer)
- `dev/audit_tests.R` (audit-infrastruktur)

---

## Relation til eksisterende arbejde

- **Fase 1** (`2026-04-17-refactor-test-suite-phase1-design.md`) — producerede
  `test-classification.yaml`, grundlag for Fase 2-beslutninger
- **Change 1** (`unblock-publish-test-gate`) — fjernede 4 broken-missing-fn filer;
  ingen overlap med Fase 2
- **Fase 3** (brainstormes efter Fase 2) — håndterer resterende `fix-in-phase-3`
- **Fase 4** (brainstormes efter Fase 3) — test-arkitektur-standards + potentielt
  CI-gates mod regression af konsolideringen

---

## Næste skridt

Efter brugers godkendelse af denne spec:

1. Invoker `superpowers:writing-plans`-skill for at lave detaljeret
   implementations-plan (bite-sized tasks)
2. Opret worktree `.worktrees/refactor-test-suite-phase2` fra master
3. Implementér via subagent-driven development (Sonnet, med checkpoints)
4. Merge til master efter review
