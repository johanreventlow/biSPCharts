# Refactor Test Suite — Fase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adressér ~124 TODO-SKIPs fra Fase 2 og betinget reparer 43 fix-in-phase-3 filer for at nå fail-count <200.

**Architecture:** 8 trin med 2 checkpoints (efter kategorisering og efter kategori 1-proposals). Subagent-drevet med scope-protection: R-kode-ændringer kræver bruger-godkendelse pr styk.

**Tech Stack:** R 4.5.2, `testthat`, `pkgload`, `devtools` (document + check), Fase 1-tooling.

**Source Spec:** `docs/superpowers/specs/2026-04-17-refactor-test-suite-phase3-design.md`

---

## Forudsætninger

- Branch `feat/refactor-test-suite-phase2` findes (Fase 2 arbejde)
- Worktree `.worktrees/refactor-test-suite-phase2` aktiv
- Manifest siger 113 filer valid, 11 filer har TODO-markers
- 43 `fix-in-phase-3`-filer + 1 resterende `rewrite` = 44 potentielle Trin 5-kandidater

## File Structure

### Create (midlertidig)

- `dev/audit-output/phase3-categorization-report.md` — slettes i Trin 6

### Create (evt.)

- `docs/adr/ADR-NNN-*.md` — hvis kategori 1 R-ændringer er arkitektoniske

### Modify (testfiler)

- 11 filer med TODO-markers (fjern SKIPs der nu passer)
- Evt. 43 fix-in-phase-3-filer (salvage-fixes)

### Modify (R)

- Kun kategori 1-godkendte R-filer (bruger-per-styk-godkendelse)
- `NAMESPACE` (auto-regenereret via `devtools::document()`)

### Modify (manifest + rapport)

- `dev/audit-output/test-classification.yaml`
- `dev/audit-output/test-audit.json`
- `docs/superpowers/specs/2026-04-17-test-audit-report.md`
- `NEWS.md`

### Ingen ændringer til

- `dev/classify_tests.R` + helpers
- `dev/audit_tests.R`
- `R/*.R` uden kategori 1-godkendelse

---

## Task 1: Merge plan ind i impl-branch + baseline

**Purpose:** Få plan-filen ind i impl-branchen og verificér baseline.

- [ ] **Step 1: Merge design-branch ind i feat/refactor-test-suite-phase2**

```bash
cd /Users/johanreventlow/R/biSPCharts/.worktrees/refactor-test-suite-phase2
git merge docs/refactor-test-suite-phase3-design --no-ff \
  -m "merge: bring Fase 3 design + plan ind på impl-branch"
```

Expected: Clean merge, 2 nye filer tilføjet (design + plan).

- [ ] **Step 2: Verificér baseline**

```bash
Rscript dev/classify_tests.R --validate 2>&1 | tail -2
```

Expected: `✓ Manifest er valid (113 filer).`

```bash
Rscript -e "d <- jsonlite::fromJSON('dev/audit-output/test-audit.json', simplifyVector = FALSE); cat('Fails:', sum(sapply(d\$files, function(f) f\$n_fail %||% 0L)), '\n')" 2>&1
```

Expected: Noget nær 292 fails (baseline).

- [ ] **Step 3: Snapshot TODO-count per fil (for senere sammenligning)**

```bash
grep -c "TODO Fase 3" tests/testthat/*.R 2>/dev/null | grep -v ":0$" | sort -t: -k2 -rn > /tmp/phase3-todo-baseline.txt
cat /tmp/phase3-todo-baseline.txt
```

Expected: 11 filer med TODO-counts (total ~124).

---

## Task 2: Trin 1 — Kategorisering af TODOs

**Purpose:** Subagent klassificerer alle ~124 TODO-SKIPs til kategori 1/2/3.

**Files:**
- Create: `dev/audit-output/phase3-categorization-report.md`

- [ ] **Step 1: Dispatch kategoriserings-subagent (Sonnet)**

Subagent-instruktioner:

1. Læs `docs/superpowers/specs/2026-04-17-refactor-test-suite-phase3-design.md` (kategori-definitioner)
2. For hver TODO-SKIP i de 11 filer:
   - Ekstrahér fn-navn og problem-beskrivelse fra skip-besked
   - Tjek om fn findes: `grep -rn "^<fn> <-\\|^<fn>=" R/*.R`
   - Tjek NAMESPACE: `grep "^export(<fn>)" NAMESPACE`
   - Kategoriser:
     - findes + ikke eksporteret → **K2 (NAMESPACE)**
     - findes + eksporteret + adfærd-mismatch → **K1 (R-bug)**
     - ikke findes + tilsvarende navn → **K3 (test-bug)**
     - ikke findes + intet tilsvarende → **K1 (ny fn)**
3. Producer `phase3-categorization-report.md` med tabeller pr kategori

**Rapport-template:**

```markdown
# Phase 3 Kategoriserings-rapport

**Dato:** <YYYY-MM-DD>
**Total TODOs:** <N>
**Kategorifordeling:** K1: X | K2: Y | K3: Z

## Kategori 1 (R-kode-ændring kræves)

| # | Fil | Linje | TODO-navn | Problem | Foreslået R-fix |
|---|---|---|---|---|---|
| 1 | test-parse-danish.R | 45 | parse_danish_target null | `parse_danish_target(NULL)` kaster fejl | Tilføj `if (is.null(value)) return(NULL)` i `R/utils_parse_danish_target.R:12` |

## Kategori 2 (NAMESPACE-export)

| # | Fil | Linje | Funktion | Defineret i | Roxygen eksisterer |
|---|---|---|---|---|---|
| 1 | test-utils-state.R | 12 | `get_original_data` | `R/state_management.R:45` | JA |

## Kategori 3 (test-bug)

| # | Fil | Linje | Problem | Fix |
|---|---|---|---|---|
| 1 | test-X.R | 45 | Test kalder `calc_ucl`, korrekt navn er `compute_ucl` | Omdøb call |

## Tvivlstilfælde

(Filer hvor kategorisering er uklar — bruger-beslutning påkrævet)
```

- [ ] **Step 2: Subagent commit rapport**

```bash
git add dev/audit-output/phase3-categorization-report.md
git commit -m "analyse(phase3): kategoriser 124 TODO-SKIPs (#203)"
```

- [ ] **Step 3: Subagent rapportér til parent**

- Status: DONE / BLOCKED
- Kategorifordeling (K1: X, K2: Y, K3: Z)
- Tvivlstilfælde-count
- Commit-SHA

---

## CHECKPOINT 1: Bruger reviewer kategorisering

Bruger gennemgår rapport og:
- Bekræfter kategoriseringen
- Omklassificerer specifikke TODOs om nødvendigt (kan være del af next subagent's input)
- Godkender Trin 2 + 3 start

Hvis ændringer: subagent re-genererer rapport inden fortsat.

---

## Task 3: Trin 2 — Kategori 2 auto-fix (NAMESPACE-export)

**Purpose:** Tilføj `@export` til roxygen + regenerér NAMESPACE + un-skip passende tests.

**Files:**
- Modify: `R/<fil>.R` (tilføj `#' @export`)
- Modify: `NAMESPACE` (auto-regenereret)
- Modify: testfiler (fjern `skip()` der nu passer)

- [ ] **Step 1: Dispatch Kategori 2-subagent**

Subagent-instruktioner (per K2-entry i rapport):

1. Find R-kildefil og funktion
2. Lokalisér roxygen-block (hvis ingen: opret minimal block)
3. Tilføj `#' @export` over funktion
4. Kør `Rscript -e "devtools::document()"` → regenererer NAMESPACE
5. Verificér ingen nye WARNINGs: `Rscript -e "devtools::check()" 2>&1 | grep -E "WARNING|ERROR"`
6. Fjern `skip()` fra den relevante test + re-kør
7. Hvis test passer: commit atomisk
8. Hvis test stadig fejler: revert NAMESPACE-ændring, re-kategorisér som K1

**Commit-mønster per fn:**
```bash
git add R/<fil>.R NAMESPACE tests/testthat/test-<X>.R
git commit -m "feat(R): export <fn_name> for test access (#203)"
```

- [ ] **Step 2: Kør audit efter alle K2-fixes**

```bash
Rscript dev/audit_tests.R --timeout=60 2>&1 | tail -10
```

- [ ] **Step 3: Commit audit-regen**

```bash
git add dev/audit-output/test-audit.json
git commit -m "chore(audit): regenerér efter Kategori 2 NAMESPACE-fixes (#203)"
```

- [ ] **Step 4: Rapport til parent**

- Antal K2-fixes applied
- Antal K2→K1 re-kategoriseret
- Commit-SHAs

---

## Task 4: Trin 2 — Kategori 3 auto-fix (test-bugs)

**Purpose:** Opdater test-assertions til nuværende R-adfærd.

**Files:**
- Modify: 11 TODO-filer (evt. + resterende efter Task 3)

- [ ] **Step 1: Dispatch Kategori 3-subagent**

Subagent-instruktioner (per K3-entry):

1. Åbn test-fil + ret assertion/call til nuværende R-adfærd
2. Fjern `skip()` hvis nu passer
3. Commit atomisk

**Commit-mønster:**
```bash
git add tests/testthat/test-<X>.R
git commit -m "test: fix assertion i test-<X>.R (#203)"
```

- [ ] **Step 2: Rapport til parent**

- Antal K3-fixes applied
- Antal K3→K1 re-kategoriseret (hvis fix afslører R-bug)
- Commit-SHAs

---

## Task 5: Trin 3 — Forbered Kategori 1 patches

**Purpose:** Subagent forbereder patches for alle K1-R-fixes. Bruger gennemgår som batch.

**Files:**
- Read: `dev/audit-output/phase3-categorization-report.md`
- Produce: Patch-proposals i subagent-rapport (ikke committet)

- [ ] **Step 1: Dispatch Kategori 1 forberedelse-subagent**

Subagent-instruktioner:

For hver K1-entry i rapporten:
1. Læs R-kildefil
2. Foreslå minimal diff der fixer problemet
3. Kør `Rscript -e "pkgload::load_all(); testthat::test_file('<test-fil>')"` simuleret (hvis muligt) eller forklar hvorfor fix skulle virke
4. Samle patch-proposals i rapport med format:

```markdown
### K1 Fix #N: <fn_name> - <problem-kort>

**Fil:** `R/<fil>.R:<linje>`
**Problem:** <beskrivelse>
**Afsløret af:** `tests/testthat/test-<X>.R:<linje>`

**Foreslået diff:**
```diff
<minimal diff>
```

**Risiko-vurdering:**
- Brudflader: <andre filer der kan påvirkes>
- Backwards-kompatibel: ja/nej
- Public API-ændring: ja/nej

**Bruger-valg:** [ ] apply [ ] skip [ ] modify
```

- [ ] **Step 2: Subagent IKKE committer**

Rapport gives til bruger som tekstblok (ikke commit yet).

- [ ] **Step 3: Rapportér til parent med fuld patch-liste**

---

## CHECKPOINT 2: Bruger godkender Kategori 1 fixes per styk

Bruger svarer "apply/skip/modify" per fix. Output: liste af godkendte fixes.

---

## Task 6: Trin 3 — Implementér godkendte Kategori 1 fixes

**Purpose:** Applicér kun bruger-godkendte R-ændringer.

**Files:**
- Modify: R-filer (kun godkendte)
- Modify: `NAMESPACE` (hvis nye exports)

- [ ] **Step 1: Dispatch Kategori 1 implementering-subagent**

Subagent får listen af godkendte fixes. Per fix:

1. Anvend diff til R-fil
2. Hvis funktion er ny: tilføj `#' @export` + roxygen-doc
3. Kør `devtools::document()` hvis nødvendigt
4. Kør `pkgload::load_all()` + relevant testfil
5. Verificér test passer + `devtools::check()` ingen nye WARNINGs
6. Fjern `skip()` fra test
7. Atomisk commit

**Commit-mønster:**
```bash
git add R/<fil>.R NAMESPACE tests/testthat/test-<X>.R
git commit -m "fix(R): <fn_name> <kort-beskrivelse> (#203)"
```

- [ ] **Step 2: Hvis fix bryder andre tests: revert**

```bash
git revert <commit-SHA>
```

Rapportér til parent: fix rollback + hvorfor.

- [ ] **Step 3: Efter alle godkendte fixes, commit regen-audit**

```bash
Rscript dev/audit_tests.R --timeout=60
git add dev/audit-output/test-audit.json
git commit -m "chore(audit): regenerér efter Kategori 1 R-fixes (#203)"
```

- [ ] **Step 4: Rapportér til parent**

- Antal K1-fixes applied
- Antal reverts
- Commit-SHAs

---

## Task 7: Trin 4 — Re-audit + beslutning

**Purpose:** Beslut om Trin 5 (fix-in-phase-3) er nødvendig.

- [ ] **Step 1: Check fail-count**

```bash
Rscript -e '
d <- jsonlite::fromJSON("dev/audit-output/test-audit.json", simplifyVector = FALSE)
total_fail <- sum(sapply(d$files, function(f) f$n_fail %||% 0L))
cat("Fail-count:", total_fail, "\n")
cat("Reduction fra 292:", 292 - total_fail, "\n")
cat("Target <200:", if (total_fail < 200) "NÅET" else "IKKE NÅET (fortsæt Trin 5)", "\n")
' 2>&1
```

- [ ] **Step 2: Rapportér beslutning til parent**

- `fail-count < 200` → spring Task 8 over, gå til Task 9 (verifikation)
- `fail-count ≥ 200` → udfør Task 8 (fix-in-phase-3)

---

## Task 8: Trin 5 — Betinget fix-in-phase-3 (salvage på 43 filer)

**Purpose:** Kun hvis Task 7 viste `fail-count ≥ 200`.

**Files:**
- Modify: op til 43 testfiler + 1 rewrite-rest

- [ ] **Step 1: Identificér resterende fix-in-phase-3-filer**

```bash
Rscript -e '
m <- yaml::read_yaml("dev/audit-output/test-classification.yaml")
fixes <- Filter(function(e) e$handling %in% c("fix-in-phase-3", "rewrite"), m$files)
for (e in fixes) cat(e$file, "\n")
' 2>&1
```

- [ ] **Step 2: Dispatch Task 8-subagent (Sonnet)**

Subagent salvage-first per fil:

1. Kør fil isoleret: `Rscript -e "pkgload::load_all(); testthat::test_file('...')"`
2. For hver failing test:
   - Tjek R/-kildekode, verificér forventet output
   - Fix assertion ELLER SKIP med TODO-marker
3. Commit atomisk per fil ELLER per 3-5 filer-batch
4. Efter alle: sync manifest (flyt fra `fix-in-phase-3` til `keep`)

**Commit-mønster per batch:**
```bash
git add tests/testthat/test-<X>.R tests/testthat/test-<Y>.R
git commit -m "test: salvage-fix <område> (#203)"
```

- [ ] **Step 3: Manifest-sync + commit**

```bash
Rscript -e '
m <- yaml::read_yaml("dev/audit-output/test-classification.yaml")
d <- jsonlite::fromJSON("dev/audit-output/test-audit.json", simplifyVector = FALSE)
audit_cat <- setNames(vapply(d$files, function(f) f$category, character(1)),
                      vapply(d$files, function(f) f$file, character(1)))
for (i in seq_along(m$files)) {
  f <- m$files[[i]]$file
  if (m$files[[i]]$handling %in% c("fix-in-phase-3", "rewrite") &&
      !is.null(audit_cat[[f]]) && audit_cat[[f]] == "green") {
    m$files[[i]]$handling <- "keep"
    m$files[[i]]$rationale <- paste(
      m$files[[i]]$rationale %||% "",
      "[Fase 3: salvage-fixed]"
    )
  }
}
header <- readLines("dev/audit-output/test-classification.yaml", n = 16)
body <- yaml::as.yaml(m, indent = 2, indent.mapping.sequence = TRUE)
writeLines(c(header, body), "dev/audit-output/test-classification.yaml")
' 2>&1

Rscript dev/classify_tests.R --validate
git add dev/audit-output/test-classification.yaml
git commit -m "chore(classify): sync manifest efter Trin 5 fix-in-phase-3 (#203)"
```

---

## Task 9: Trin 6 — Verifikation + NEWS + ADR

**Purpose:** Finaliser, dokumentér, forbered til merge.

- [ ] **Step 1: Final audit + validering**

```bash
Rscript dev/audit_tests.R --timeout=60
Rscript dev/classify_tests.R --validate
Rscript dev/tests/run_tests.R 2>&1 | tail -5
```

- [ ] **Step 2: Re-render audit-rapport**

```bash
Rscript dev/classify_tests.R --render-report
```

- [ ] **Step 3: devtools::check() full**

```bash
Rscript -e "devtools::check()" 2>&1 | tail -20
```

Expected: Ingen nye WARNINGs ift. pre-Fase 3. Log eventuelle for parent-review.

- [ ] **Step 4: Commit audit + rapport**

```bash
git add dev/audit-output/test-audit.json \
        docs/superpowers/specs/2026-04-17-test-audit-report.md
git commit -m "chore(audit): sync audit + rapport efter Fase 3 (#203)"
```

- [ ] **Step 5: Udvid NEWS.md med Fase 3-sektion**

Åbn `NEWS.md`. Find `# biSPCharts 0.2.0-dev (development)` og tilføj under eksisterende Fase 2-sektion:

```markdown
## Interne ændringer (Fase 3 — TODO-resolution + betinget fix, #203)

* **Fail-count reduceret fra 292 til <X>** (target <200: <NÅET/IKKE NÅET>).
* **Kategori 1 (R-bugs) fixed:** <N> godkendte R-ændringer — se commits med prefix `fix(R):`.
* **Kategori 2 (NAMESPACE-exports):** <M> funktioner tilføjet til NAMESPACE — se commits `feat(R): export`.
* **Kategori 3 (test-bugs):** <K> assertions fixed — se commits `test: fix assertion`.
* **Trin 5 (fix-in-phase-3):** <udført / sprunget over>. <A filer salvage-fixed>.

## Bemærkninger (Fase 3)

* Evt. R-fixes der blev afvist af maintainer er dokumenteret som TODO-markers
  bevaret i tests med `#203-followup`-reference.
* Publish-gate status: <se fail-count; hvis <200 og devtools::test() passerer:
  GRØN, ellers: stadig blokeret>.
```

Udfyld faktiske tal fra Task 7 og Task 8.

- [ ] **Step 6: Hvis nye R-exports: overvej ADR**

Hvis K1-fixes tilføjede nye eksporterede funktioner (udvidet public API):

```bash
# Find næste ADR-nummer
ls docs/adr/ 2>/dev/null | tail -3
```

Opret `docs/adr/ADR-NNN-phase3-public-api-udvidelse.md` med ADR-template fra `DEVELOPMENT_PHILOSOPHY.md`.

Hvis ingen nye exports: spring over.

- [ ] **Step 7: Slet midlertidig kategoriseringsrapport**

```bash
git rm dev/audit-output/phase3-categorization-report.md
```

- [ ] **Step 8: Commit NEWS + ADR + rapport-sletning**

```bash
git add NEWS.md docs/adr/ 2>/dev/null
git commit -m "docs(news): Fase 3 TODO-resolution (#203)"
```

---

## Task 10: Final rapport + STOP

**Purpose:** Rapportér samlet Fase 2+3 status til bruger.

- [ ] **Step 1: Endelig sanity**

```bash
Rscript dev/classify_tests.R --validate
Rscript dev/tests/run_tests.R 2>&1 | tail -3
Rscript dev/audit_tests.R --timeout=60 2>&1 | tail -5
```

- [ ] **Step 2: Git-log sammenfatning**

```bash
echo "=== Fase 2+3 commits ==="
git log --oneline master..HEAD | wc -l
git log --oneline master..HEAD | head -40
```

- [ ] **Step 3: Rapportér til parent**

- **Status:** DONE / DONE_WITH_CONCERNS / BLOCKED
- **Fail-count:** 292 → <X> (target <200: NÅET / IKKE NÅET)
- **Kategori-breakdown:** K1: <A>/<N godkendt>, K2: <B>, K3: <C>
- **Trin 5 status:** udført / sprunget over
- **Total commits Fase 2+3:** antal + sidste SHA
- **Ready for user review/merge:** JA
- **Åbne items:** SKIPs bevaret, ADR-status, evt. WARNINGs fra devtools::check()

**STOP** — push/merge er bruger-ansvar.

---

## Accept-kriterier (samlet)

- [ ] Kategoriseringsrapport produceret og bruger-reviewet (Task 2, CHECKPOINT 1)
- [ ] Alle K2 NAMESPACE-fixes applied uden regression (Task 3)
- [ ] Alle K3 test-bug-fixes applied (Task 4)
- [ ] K1 patches forberedt og bruger-godkendt per styk (Task 5, CHECKPOINT 2, Task 6)
- [ ] Re-audit beslutning dokumenteret (Task 7)
- [ ] Hvis <200 ikke nået: Trin 5 udført (Task 8)
- [ ] NAMESPACE valideret via `devtools::check()` (Task 9 Step 3)
- [ ] NEWS-entry udvidet med Fase 3 (Task 9 Step 5)
- [ ] ADR oprettet hvis R-API udvidet (Task 9 Step 6)
- [ ] Manifest synket og valid (Task 9)
- [ ] Midlertidig kategoriseringsrapport slettet (Task 9 Step 7)
- [ ] Final rapport til bruger (Task 10)
