# Refactor Test Suite — Fase 2 "Konsolidering" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reducér test-suite fra 121 til 100-110 filer gennem archive/merge/rewrite af identificerede overlap og høj-fejl-filer. Etablér clean baseline for Fase 3.

**Architecture:** 4 trin (Analyse → Archive → Merge → Rewrite) med 1 USER-STOP efter analyse. Subagent-drevet execution med per-operation-regler. Manifest (`test-classification.yaml`) synces efter hver destruktiv operation.

**Tech Stack:** R 4.5.2, `testthat`, `yaml`/`jsonlite` (manifest I/O), `pkgload` (load_all for R/-inspektion), Fase 1-tooling (`dev/classify_tests.R --validate` + `--render-report`).

**Source Spec:** `docs/superpowers/specs/2026-04-17-refactor-test-suite-phase2-design.md`

---

## Forudsætninger

- Master HEAD er `348b3b7` (merge: Change 1)
- `dev/audit-output/test-classification.yaml` findes med 121 reviewed entries
- `dev/audit_tests.R` + `dev/classify_tests.R` fungerer
- Fase 1's dev-tests passerer (83 tests)

## File Structure

### Create (midlertidige)

- `dev/audit-output/phase2-analysis-report.md` — checkpoint-rapport (slettes i Trin 6)

### Modify (eksisterende, destruktive)

- `tests/testthat/test-*.R` — archive (slet), merge (slet kildes + overskriv canonical), rewrite (overskriv indhold)
- `dev/audit-output/test-classification.yaml` — sync efter hver destruktiv operation
- `dev/audit-output/test-audit.json` — regenerér efter alle operationer
- `docs/superpowers/specs/2026-04-17-test-audit-report.md` — re-render

### Modify (dokumentation)

- `NEWS.md` — entry for Fase 2 konsolidering

### Ingen ændringer til

- `R/*.R` (undtagen hvis rewrite afslører blocker-bug → separat proposal)
- `NAMESPACE`
- `dev/classify_tests.R` + helpers (Fase 1 leverancer)
- `dev/audit_tests.R`

---

## Task 1: Setup impl-branch og worktree

**Purpose:** Ny branch fra master for isoleret Fase 2-arbejde.

**Files:**
- Branch: `feat/refactor-test-suite-phase2` fra master
- Worktree: `.worktrees/refactor-test-suite-phase2`

- [ ] **Step 1: Verificér master state**

```bash
cd /Users/johanreventlow/R/biSPCharts
git checkout master
git log --oneline -3
```

Expected: HEAD er `348b3b7` (merge: Change 1) eller nyere.

- [ ] **Step 2: Opret branch + worktree**

```bash
git worktree add .worktrees/refactor-test-suite-phase2 -b feat/refactor-test-suite-phase2 master
cd .worktrees/refactor-test-suite-phase2
```

- [ ] **Step 3: Verificér clean baseline**

```bash
Rscript dev/classify_tests.R --validate
```

Expected: `✓ Manifest er valid (121 filer).`

```bash
Rscript dev/tests/run_tests.R 2>&1 | tail -3
```

Expected: Alle tests PASS (~83 tests).

- [ ] **Step 4: Commit baseline-check**

Ingen ændringer her; verifikation kun. Fortsæt til Task 2.

---

## Task 2: Analyse-trin — Archive-kandidat-scan

**Purpose:** Identificér filer der kvalificerer til arkivering via ≥2 af 4 kriterier.

**Files:**
- Create: `dev/audit-output/phase2-analysis-report.md`

**Kriterier (≥2 påkrævet per fil):**
1. Tester fjernet feature (git-forensics bekræfter)
2. Tester migreret funktionalitet (flyttet til BFHcharts/BFHtheme/BFHllm/Ragnar)
3. Fuldt duplikeret med bedre alternativ
4. Legacy-fil (`test-phase*.R`, `test-fase*.R`, `test-sprint*.R`)

- [ ] **Step 1: Initialiser rapport-fil**

Opret `dev/audit-output/phase2-analysis-report.md`:

```markdown
# Fase 2 Analyse-rapport

**Dato:** 2026-04-17
**Purpose:** Grundlag for archive/merge/rewrite-beslutninger i Fase 2

---

## 1. Archive-kandidater

_(Fyldes ud i Task 2)_

## 2. Merge-kluster-verifikation

_(Fyldes ud i Task 3)_

## 3. Rewrite-hybrid-auto-downgrade

_(Fyldes ud i Task 4)_

## 4. Net-effekt

_(Fyldes ud i Task 5)_
```

- [ ] **Step 2: Scan for legacy-filnavne**

```bash
cd /Users/johanreventlow/R/biSPCharts/.worktrees/refactor-test-suite-phase2
ls tests/testthat/ | grep -E '(test-phase|test-fase|test-sprint)' || echo "INGEN legacy-filnavne"
```

Noter resultatet i Archive-sektionen.

- [ ] **Step 3: Scan for duplikerede tema-grupper**

For hver grøn-kategori fil, sammenlign med andre grønne filer i samme kluster (filnavn-prefix):

```bash
# Find filer med test_that der er næsten identiske (navnemæssigt)
for cluster_prefix in autodetect cache event spc qic plot; do
  echo "=== Kluster: $cluster_prefix ==="
  grep -l "^test_that" tests/testthat/test-${cluster_prefix}*.R 2>/dev/null | while read f; do
    count=$(grep -c "^test_that" "$f")
    echo "  $f ($count tests)"
  done
done
```

Kandidater til duplikeret: filer hvor >50% af `test_that`-navne overlapper.

- [ ] **Step 4: Git-forensics for migreret funktionalitet**

For hver fil der potentielt tester BFHcharts/BFHtheme-funktionalitet direkte:

```bash
# Identificér importør-mønster
grep -l "BFHcharts::\|BFHtheme::\|BFHllm::" tests/testthat/test-*.R | while read f; do
  echo "  $f (importerer ekstern pakke direkte)"
done
```

Disse kan være archive-kandidater hvis biSPCharts ikke længere skal teste ekstern pakke-logik direkte.

- [ ] **Step 5: Syntetisér Archive-kandidat-liste**

Opdatér `phase2-analysis-report.md` sektion "1. Archive-kandidater":

```markdown
## 1. Archive-kandidater

| Fil | Matched kriterier | Foreslået handling | Begrundelse |
|---|---|---|---|
| (udfyld) | (1,3) | archive | fx "test-phase2-backup.R: legacy-filnavn + duplikeret af test-autodetect.R" |
| (udfyld) | (2) | BEHOLD | "kun 1 match — for risikabelt" |
```

**Krav:** For hver archive-foreslået fil skal rationale nævne præcise linjer/commits fra git-forensics.

- [ ] **Step 6: Commit (intet endnu slettet)**

```bash
git add dev/audit-output/phase2-analysis-report.md
git commit -m "analyse(tests): archive-kandidater identificeret (#203)"
```

---

## Task 3: Analyse-trin — Merge-kluster-verifikation

**Purpose:** Verificér de 7 filnavn-klustre mod 3 merge-kriterier (tema + <500 LOC + type-match).

**Files:**
- Modify: `dev/audit-output/phase2-analysis-report.md`

**Forventede klustre (fra spec):**

| Cluster | Filer | Forventet udfald |
|---|---|---|
| y-axis-* | 4 | Merge → 1 |
| critical-fixes-* | 3 | Behold separat (3 forskellige concerns) |
| event-system-* | 2 | Merge → 1 |
| file-operations-* | 2 | Verificér |
| label-placement-* | 2 | Merge → 1 |
| mod-spc-* | 2 | Verificér |
| plot-generation-* | 2 | Behold separat (benchmark + unit) |

- [ ] **Step 1: Tema-verifikation per kluster**

For hver kluster, analyser test_that-navne:

```bash
cluster_prefix="y-axis"
for f in tests/testthat/test-${cluster_prefix}*.R; do
  echo "=== $f ==="
  grep "^test_that" "$f" | head -10
done
```

Sammenlign: Er alle test_that-navne på samme concern? Eller spænder de over forskellige domæner?

Gentag for alle 7 klustre. Noter resultater.

- [ ] **Step 2: LOC-check per merged resultat**

Summér LOC for hver kluster:

```bash
for cluster in y-axis event-system label-placement file-operations mod-spc; do
  total=0
  for f in tests/testthat/test-${cluster}*.R; do
    loc=$(wc -l < "$f")
    total=$((total + loc))
  done
  echo "$cluster: ~$total LOC (merge-kandidat: $([ $total -lt 500 ] && echo JA || echo NEJ - for stor))"
done
```

Hvis LOC ≥ 500: kluster kan ikke merges (kriterium 3).

- [ ] **Step 3: Type-check per kluster**

```bash
Rscript -e '
m <- yaml::read_yaml("dev/audit-output/test-classification.yaml")
clusters <- list(
  "y-axis" = "y-axis",
  "critical-fixes" = "critical-fixes",
  "event-system" = "event-system",
  "file-operations" = "file-operations",
  "label-placement" = "label-placement",
  "mod-spc" = "mod-spc",
  "plot-generation" = "plot-generation"
)
for (cl_name in names(clusters)) {
  prefix <- clusters[[cl_name]]
  cluster_entries <- Filter(function(e) grepl(paste0("^test-", prefix), e$file), m$files)
  types <- unique(vapply(cluster_entries, `[[`, character(1), "type"))
  cat(sprintf("  %-20s types: %s\n", cl_name, paste(types, collapse=", ")))
}
'
```

Output viser type-fordeling per kluster. Hvis mere end én type: ikke merge.

- [ ] **Step 4: Identificér canonical-fil per mergeable kluster**

Regel: Mest omfattende fil (højeste test_that-count) beholder navn. Kildes slettes.

```bash
for f in tests/testthat/test-y-axis*.R; do
  count=$(grep -c "^test_that" "$f")
  echo "$count $f"
done | sort -rn
```

Første linje i output = canonical-fil.

- [ ] **Step 5: Opdatér Merge-sektion i rapport**

```markdown
## 2. Merge-kluster-verifikation

| Cluster | Tema OK? | LOC OK? | Type OK? | Handling | Canonical | Kildes |
|---|---|---|---|---|---|---|
| y-axis (4) | (ja/nej) | (ja/nej) | (ja/nej) | MERGE/BEHOLD | test-y-axis-scaling-overhaul.R | test-y-axis-formatting.R, test-y-axis-mapping.R, test-y-axis-model.R |
| ... | | | | | | |
```

**Krav:** For hver MERGE-beslutning, angiv canonical + liste af kildes. For hver BEHOLD, angiv konkret begrundelse.

- [ ] **Step 6: Commit**

```bash
git add dev/audit-output/phase2-analysis-report.md
git commit -m "analyse(tests): merge-kluster-verifikation udført (#203)"
```

---

## Task 4: Analyse-trin — Rewrite-hybrid-auto-downgrade

**Purpose:** For de 17 rewrite-kandidater, vurdér size-kategori og auto-downgrade hvor muligt.

**Files:**
- Modify: `dev/audit-output/phase2-analysis-report.md`

- [ ] **Step 1: Hent rewrite-liste med test-counts**

```bash
Rscript -e '
m <- yaml::read_yaml("dev/audit-output/test-classification.yaml")
d <- jsonlite::fromJSON("dev/audit-output/test-audit.json", simplifyVector = FALSE)
audit_by_file <- setNames(d$files, vapply(d$files, function(f) f$file, character(1)))
rewrites <- Filter(function(e) e$handling == "rewrite", m$files)
for (e in rewrites) {
  a <- audit_by_file[[e$file]]
  total_tests <- (a$n_pass %||% 0) + (a$n_fail %||% 0)
  size <- if (total_tests <= 3) "lille"
          else if (total_tests <= 15) "mellem"
          else "stor"
  cat(sprintf("  %-55s %2d tests (%s)\n", e$file, total_tests, size))
}
' 2>&1
```

- [ ] **Step 2: Identificér auto-downgrade-kandidater**

**Auto-downgrade-regler:**
- **Lille (1-3 tests) + 100% fail + matcher merge-kluster** → merge ind i kluster-canonical
- **Lille (1-3 tests) + 100% fail + solo** → arkivér (lav værdi)
- **Mellem (4-15 tests)** → salvage-first rewrite
- **Stor (>15 tests)** → klassisk TDD-rewrite

Kør per rewrite-fil:

```bash
Rscript -e '
m <- yaml::read_yaml("dev/audit-output/test-classification.yaml")
d <- jsonlite::fromJSON("dev/audit-output/test-audit.json", simplifyVector = FALSE)
audit_by_file <- setNames(d$files, vapply(d$files, function(f) f$file, character(1)))
rewrites <- Filter(function(e) e$handling == "rewrite", m$files)

# Cluster-matcher
cluster_prefixes <- c("y-axis", "critical-fixes", "event-system",
                     "file-operations", "label-placement", "mod-spc", "plot-generation")
is_cluster_member <- function(file, prefixes) {
  any(vapply(prefixes, function(p) grepl(paste0("^test-", p), file), logical(1)))
}

for (e in rewrites) {
  a <- audit_by_file[[e$file]]
  n_pass <- a$n_pass %||% 0
  n_fail <- a$n_fail %||% 0
  total <- n_pass + n_fail
  fail_pct <- if (total > 0) 100 * n_fail / total else 0

  size <- if (total <= 3) "lille"
          else if (total <= 15) "mellem"
          else "stor"

  in_cluster <- is_cluster_member(e$file, cluster_prefixes)

  decision <- if (size == "lille" && fail_pct >= 100 && in_cluster) {
    "AUTO-DOWNGRADE: merge ind i kluster"
  } else if (size == "lille" && fail_pct >= 100) {
    "AUTO-DOWNGRADE: arkivér (solo lav-værdi)"
  } else if (size == "mellem") {
    "REWRITE: salvage-first"
  } else {
    "REWRITE: klassisk TDD"
  }

  cat(sprintf("  %-55s %s\n", e$file, decision))
}
' 2>&1
```

- [ ] **Step 3: Opdatér Rewrite-sektion i rapport**

```markdown
## 3. Rewrite-hybrid-auto-downgrade

| Fil | Tests | Size | Handling | Plan |
|---|---|---|---|---|
| test-label-placement-bounds.R | 1 | lille | MERGE ind i label-placement-canonical | n/a |
| test-parse-danish-target-unit-conversion.R | 73 | stor | REWRITE (TDD) | Studér R/utils_parse*.R |
| ... | | | | |

**Auto-downgrade-resultat:** X filer (fx 7) nedjusteret fra rewrite. Y filer (fx 10) forbliver egentlige rewrites.
```

- [ ] **Step 4: For TDD-rewrite-filer: identificér R-kildefiler**

For hver "stor" rewrite-kandidat, find den R-fil der testes:

```bash
Rscript -e '
rewrites_big <- c("test-parse-danish-target-unit-conversion.R", "test-utils-state-accessors.R")
# Tilpas liste baseret på Step 2-output

for (f in rewrites_big) {
  base <- sub("^test-", "", f)
  base <- sub("\\.R$", "", base)
  # Forsøg at finde matchende R-fil
  r_matches <- list.files("R", pattern = paste0("^(utils_)?", base, "\\.R$"), full.names = TRUE)
  if (length(r_matches) == 0) {
    # Alternativ søgning
    r_matches <- list.files("R", pattern = gsub("-", ".*", base), full.names = TRUE)
  }
  cat(sprintf("%s:\n", f))
  for (r in r_matches) cat(sprintf("  kan teste: %s\n", r))
}
'
```

Tilføj til rapport: hvilke R-filer skal studeres for hver TDD-rewrite.

- [ ] **Step 5: Commit**

```bash
git add dev/audit-output/phase2-analysis-report.md
git commit -m "analyse(tests): rewrite-hybrid-auto-downgrade vurderet (#203)"
```

---

## Task 5: Analyse-trin — Net-effekt + CHECKPOINT

**Purpose:** Syntetisér total effekt og stop for bruger-review.

**Files:**
- Modify: `dev/audit-output/phase2-analysis-report.md`

- [ ] **Step 1: Beregn net-effekt**

Udregn forventet fil-reduktion baseret på Tasks 2-4:

```
Baseline: 121 filer
- Archive:     -N filer
- Merged away: -M filer (kildes i klustre, ikke canonical)
- Auto-downgrade (merge): -K filer (dækkes af ovenstående)
- Auto-downgrade (archive): -L filer (dækkes af ovenstående)
= Slutresultat: ~100-110 filer
```

- [ ] **Step 2: Opdatér Net-effekt-sektion**

```markdown
## 4. Net-effekt

**Baseline:** 121 filer

| Operation | Antal påvirkede filer | Antal slettede filer |
|---|---|---|
| Archive (direkte) | (udfyld) | (udfyld) |
| Merge (kildes slettes, canonical bevares) | (udfyld) | (udfyld) |
| Auto-downgrade → merge | (udfyld) | (udfyld) |
| Auto-downgrade → archive | (udfyld) | (udfyld) |
| Rewrite (samme fil, nyt indhold) | (udfyld) | 0 |
| **Total** | **X** | **Y** |

**Slutresultat:** 121 - Y = ~(udfyld) filer

**Forventet reduktion:** ~10-20 filer (spec-mål: 100-110)
```

- [ ] **Step 3: STOP — Rapportér til parent**

Rapportér til parent-agent (mig):
- `phase2-analysis-report.md` er komplet
- Net-effekt-tal
- Eventuelle tvivlstilfælde der kræver bruger-beslutning

**CHECKPOINT:** Vent på bruger-godkendelse før du fortsætter til Task 6+.

---

## Task 6: Archive-trin

**Purpose:** Slet bruger-godkendte archive-kandidater.

**Files:**
- Delete: `tests/testthat/test-*.R` (varies, fra Task 2 resultat)
- Modify: `dev/audit-output/test-classification.yaml` (efter alle sletninger)

**For hver archive-kandidat godkendt af bruger:**

- [ ] **Step 1: Slet filen**

```bash
cd /Users/johanreventlow/R/biSPCharts/.worktrees/refactor-test-suite-phase2
git rm tests/testthat/test-<fil>.R
```

- [ ] **Step 2: Atomisk commit**

```bash
git commit -m "test: arkivér test-<fil>.R — <kriterier> (#203)"
```

Commit-besked-mønster:
```
test: arkivér test-X.R — feature fjernet + legacy (#203)

Git-forensics viser at Y-funktion blev slettet i commit <sha>.
Legacy-filnavn indikerer forældet fase-struktur.
Kriterier matched: 1 (fjernet feature) + 4 (legacy)
```

- [ ] **Step 3: Gentag for alle archive-kandidater**

Én commit pr. fil (atomisk, lette at revert).

- [ ] **Step 4: Opdatér manifest**

```bash
Rscript -e '
m <- yaml::read_yaml("dev/audit-output/test-classification.yaml")
archived <- c(
  # Liste af arkiverede filer (fra Task 2)
  "test-<fil1>.R", "test-<fil2>.R"
)
m$files <- Filter(function(e) !(e$file %in% archived), m$files)
reviewed_n <- sum(vapply(m$files, function(e) isTRUE(e$reviewed), logical(1)))
m$metadata$total_files <- length(m$files)
m$metadata$review_status$reviewed <- reviewed_n
m$metadata$review_status$unreviewed <- length(m$files) - reviewed_n

header <- readLines("dev/audit-output/test-classification.yaml", n = 16)
body <- yaml::as.yaml(m, indent = 2, indent.mapping.sequence = TRUE)
writeLines(c(header, body), "dev/audit-output/test-classification.yaml")
cat("Manifest synket. Filer:", length(m$files), "\n")
'
```

- [ ] **Step 5: Validér manifest**

```bash
Rscript dev/classify_tests.R --validate
```

Expected: `✓ Manifest er valid (X filer)` (X = 121 - arkiverede antal).

- [ ] **Step 6: Commit manifest-sync**

```bash
git add dev/audit-output/test-classification.yaml
git commit -m "chore(classify): sync manifest efter archive-trin (#203)"
```

---

## Task 7: Merge-trin

**Purpose:** Konsolidér bruger-godkendte klustre til canonical-filer.

**Files:**
- Modify: `tests/testthat/test-<canonical>.R` (overskriv med merged indhold)
- Delete: `tests/testthat/test-<kilde>*.R` (andre kluster-filer)
- Modify: `dev/audit-output/test-classification.yaml`

**For hver mergeable kluster (fra Task 3 godkendt af bruger):**

- [ ] **Step 1: Åbn canonical + kilde-filer**

```bash
cd /Users/johanreventlow/R/biSPCharts/.worktrees/refactor-test-suite-phase2
cat tests/testthat/test-<canonical>.R  # noter eksisterende tests
for src in test-<kilde1>.R test-<kilde2>.R; do
  echo "=== $src ==="
  cat tests/testthat/$src
done
```

- [ ] **Step 2: Skriv merged canonical-fil**

Overskriv canonical-fil med sektions-kommentarer. Eksempel-template:

```r
# tests/testthat/test-<canonical>.R
# Merged Fase 2: <kilde1>.R + <kilde2>.R -> <canonical>.R
# Se NEWS.md for rationale.

library(testthat)

# ===== <SEKTION 1: fra <canonical> oprindeligt> =====

test_that("oprindelig test 1", {
  # ...
})

# ===== <SEKTION 2: fra <kilde1>.R> =====

test_that("test fra kilde1", {
  # ...
})

# ===== <SEKTION 3: fra <kilde2>.R> =====

test_that("test fra kilde2", {
  # ...
})
```

**Regler:**
- Drop duplikerede assertion-sets (hvis 2 filer tester samme ting med samme assertion)
- Behold unikke tests fra hver kilde
- Tilføj klar sektion-header hvor tests kommer fra

- [ ] **Step 3: Verificér canonical-fil**

```bash
Rscript -e "pkgload::load_all(); testthat::test_file('tests/testthat/test-<canonical>.R')" 2>&1 | tail -10
```

Expected: Fil kører (tests kan fejle hvis de var fejlende før merge — det er OK, vi ændrer ikke assertion-logik her).

- [ ] **Step 4: Slet kilde-filer**

```bash
git rm tests/testthat/test-<kilde1>.R tests/testthat/test-<kilde2>.R
```

- [ ] **Step 5: Atomisk commit per kluster**

```bash
git add tests/testthat/test-<canonical>.R
git commit -m "test: merge <kluster>-testfiler til <canonical> (#203)

Konsolideret <kilde1>.R + <kilde2>.R ind i <canonical>.R.
Sektion-kommentarer bevarer oprindelse.
Kriterier opfyldt: tema-sammenhæng + <LOC> LOC + type <type>."
```

- [ ] **Step 6: Gentag for alle mergeable klustre**

- [ ] **Step 7: Opdatér manifest efter alle merges**

```bash
Rscript -e '
m <- yaml::read_yaml("dev/audit-output/test-classification.yaml")
# Fjern merged kildes
removed <- c(
  # Liste af slettede kildes
  "test-<kilde1>.R", "test-<kilde2>.R"
)
m$files <- Filter(function(e) !(e$file %in% removed), m$files)

# Opdatér canonical-entry med udvidet rationale
for (i in seq_along(m$files)) {
  if (m$files[[i]]$file == "test-<canonical>.R") {
    m$files[[i]]$rationale <- paste(
      m$files[[i]]$rationale %||% "",
      "[Fase 2: merged <kilde1>.R + <kilde2>.R ind]",
      sep = " "
    )
  }
}

m$metadata$total_files <- length(m$files)
reviewed_n <- sum(vapply(m$files, function(e) isTRUE(e$reviewed), logical(1)))
m$metadata$review_status$reviewed <- reviewed_n
m$metadata$review_status$unreviewed <- length(m$files) - reviewed_n

header <- readLines("dev/audit-output/test-classification.yaml", n = 16)
body <- yaml::as.yaml(m, indent = 2, indent.mapping.sequence = TRUE)
writeLines(c(header, body), "dev/audit-output/test-classification.yaml")
cat("Filer:", length(m$files), "\n")
'
```

- [ ] **Step 8: Validér + commit manifest-sync**

```bash
Rscript dev/classify_tests.R --validate
git add dev/audit-output/test-classification.yaml
git commit -m "chore(classify): sync manifest efter merge-trin (#203)"
```

---

## Task 8: Rewrite-trin (Hybrid)

**Purpose:** Genskriv egentlige rewrite-kandidater baseret på size-kategori.

**Files:**
- Modify: `tests/testthat/test-<rewrite-fil>.R` (per fil)
- Modify: `dev/audit-output/test-classification.yaml` (efter alle rewrites)

### Task 8a: Klassisk TDD-rewrite (store filer, >15 tests)

For hver stor rewrite-kandidat:

- [ ] **Step 1: Identificér R-kildefil(er)**

```bash
# Eksempel for test-parse-danish-target-unit-conversion.R
ls R/ | grep -E "parse|target|unit" | head -5
```

Noter: hvilke R-funktioner tester filen.

- [ ] **Step 2: Læs R-kildefilens public API**

```bash
Rscript -e '
pkgload::load_all(quiet = TRUE)
# Eksempel: hvad eksporteres fra parse-modulet?
# Justér fn-navne baseret på faktisk fil
exports <- getNamespaceExports("biSPCharts")
relevant <- grep("parse|normalize_axis", exports, value = TRUE)
for (fn in relevant) {
  cat(sprintf("\n=== %s ===\n", fn))
  if (exists(fn)) print(args(get(fn)))
}
'
```

- [ ] **Step 3: Delete eksisterende test-fil-indhold**

```bash
> tests/testthat/test-<fil>.R
```

(Eller overskriv med template.)

- [ ] **Step 4: Skriv tests først**

Skriv tests for hvert public API-punkt. Eksempel-template:

```r
# tests/testthat/test-<fil>.R
# Rewrite Fase 2: TDD mod nuværende R/-API

library(testthat)

test_that("<funktion> håndterer normal input korrekt", {
  result <- <funktion>(<normal_input>)
  expect_equal(result, <expected>)
})

test_that("<funktion> håndterer edge case X", {
  expect_equal(<funktion>(<edge_input>), <expected_edge>)
})

test_that("<funktion> fejler meningsfuldt på invalid input", {
  expect_error(<funktion>(<bad_input>), "<expected_error_pattern>")
})
```

- [ ] **Step 5: Kør tests**

```bash
Rscript -e "pkgload::load_all(); testthat::test_file('tests/testthat/test-<fil>.R')" 2>&1 | tail -10
```

- [ ] **Step 6: For FAIL'ende tests: vurdér**

- Hvis test er forkert skrevet → fix test
- Hvis R afslører bug → SKIP med TODO + log til rapport:
  ```r
  test_that("<funktion> behaves correctly on X", {
    skip("TODO Fase 3: R-bug afsløret — <beskrivelse> (#203-followup)")
    expect_equal(...)
  })
  ```

- [ ] **Step 7: Atomisk commit**

```bash
git add tests/testthat/test-<fil>.R
git commit -m "test: rewrite test-<fil>.R mod nuværende R-API (#203)

TDD-rewrite fra scratch baseret på R/<kildefil>.R public API.
N tests skrevet, M skipped pga. afslørede R-bugs (se rapport)."
```

### Task 8b: Salvage-first-rewrite (mellem-filer, 4-15 tests)

For hver mellem-rewrite-kandidat:

- [ ] **Step 1: Kør filen, identificér failing tests**

```bash
Rscript -e "pkgload::load_all(); testthat::test_file('tests/testthat/test-<fil>.R')" 2>&1 | grep -E "FAIL|Error" | head
```

- [ ] **Step 2: For hver failing test:**
  - Undersøg R/-kildekode: hvad er korrekt forventet output?
  - Fix assertion hvis testet adfærd er korrekt defineret
  - SKIP med TODO hvis afslører R-bug

- [ ] **Step 3: Re-kør tests**

```bash
Rscript -e "pkgload::load_all(); testthat::test_file('tests/testthat/test-<fil>.R')" 2>&1 | tail -5
```

Expected: Alle tests PASS (eller SKIP med TODO).

- [ ] **Step 4: Atomisk commit**

```bash
git add tests/testthat/test-<fil>.R
git commit -m "test: salvage-rewrite test-<fil>.R (#203)

Fixede N failing assertions mod nuværende R-API.
M tests skipped med TODO pga. R-bugs (se rapport)."
```

### Task 8c: Manifest-sync efter alle rewrites

- [ ] **Step 1: Opdatér manifest**

For hver rewritet fil: skift handling fra "rewrite" til "keep" (hvis alle tests nu PASS) eller "fix-in-phase-3" (hvis tests stadig har SKIP med TODO).

```bash
Rscript -e '
m <- yaml::read_yaml("dev/audit-output/test-classification.yaml")

rewritten_keep <- c(  # Filer hvor alle tests nu passer
  "test-<fil1>.R"
)
rewritten_skip <- c(  # Filer hvor nogle tests er skipped (R-bugs)
  "test-<fil2>.R"
)

for (i in seq_along(m$files)) {
  f <- m$files[[i]]$file
  if (f %in% rewritten_keep) {
    m$files[[i]]$handling <- "keep"
    m$files[[i]]$rationale <- paste(
      m$files[[i]]$rationale, "[Fase 2: rewritet, nu grøn.]", sep=" "
    )
  } else if (f %in% rewritten_skip) {
    m$files[[i]]$handling <- "fix-in-phase-3"
    m$files[[i]]$rationale <- paste(
      m$files[[i]]$rationale, "[Fase 2: rewritet, SKIP med TODO for R-bugs.]", sep=" "
    )
  }
}

reviewed_n <- sum(vapply(m$files, function(e) isTRUE(e$reviewed), logical(1)))
m$metadata$review_status$reviewed <- reviewed_n

header <- readLines("dev/audit-output/test-classification.yaml", n = 16)
body <- yaml::as.yaml(m, indent = 2, indent.mapping.sequence = TRUE)
writeLines(c(header, body), "dev/audit-output/test-classification.yaml")
'
```

- [ ] **Step 2: Validér + commit**

```bash
Rscript dev/classify_tests.R --validate
git add dev/audit-output/test-classification.yaml
git commit -m "chore(classify): sync manifest efter rewrite-trin (#203)"
```

---

## Task 9: Verifikation og finalisering

**Purpose:** Regenerér audit, validér alt, render rapport.

- [ ] **Step 1: Regenerér audit**

```bash
cd /Users/johanreventlow/R/biSPCharts/.worktrees/refactor-test-suite-phase2
Rscript dev/audit_tests.R --timeout=60 2>&1 | tail -10
```

Expected:
- Total filer reduceret (fra 121 til ~100-110)
- `broken-missing-fn = 0` (ingen regression)
- Fail-count reduceret eller stabil (mål: <200 fra 302)

- [ ] **Step 2: Validér manifest**

```bash
Rscript dev/classify_tests.R --validate
```

Expected: `✓ Manifest er valid (X filer).`

- [ ] **Step 3: Re-render rapport**

```bash
Rscript dev/classify_tests.R --render-report
```

- [ ] **Step 4: Kør dev-tests**

```bash
Rscript dev/tests/run_tests.R 2>&1 | tail -5
```

Expected: Alle ~83 tests PASS.

- [ ] **Step 5: Commit audit + rapport-sync**

```bash
git add dev/audit-output/test-audit.json \
        docs/superpowers/specs/2026-04-17-test-audit-report.md
git commit -m "chore(audit): sync audit + rapport efter Fase 2 (#203)"
```

---

## Task 10: Dokumentation (NEWS + slet phase2-analysis-report.md)

- [ ] **Step 1: Skriv NEWS-entry**

Åbn `NEWS.md`. Tilføj øverst (eller udvid eksisterende development-entry):

```markdown
# biSPCharts 0.2.0-dev (development)

## Interne ændringer

* **Test-suite konsolidering (#203, Fase 2):** Reducerede test-suite fra 121
  filer til X filer gennem archive, merge og rewrite.
  - **Arkiveret N filer:** [liste med kort rationale pr. fil]
  - **Merged M klustre:** fx y-axis-* konsolideret til test-y-axis-scaling-overhaul.R
  - **Rewritten K filer:** mod nuværende R/-API (TDD eller salvage)
* Fail-count reduceret fra 302 til Z.
* Manifest `dev/audit-output/test-classification.yaml` synket.

## Bemærkninger

* **R-bugs afsløret under rewrite:** L tests skipped med TODO-marker til Fase 3
  follow-up. Se kommit-beskeder for detaljer.
```

**Krav:** Udfyld faktiske tal baseret på Task 9's audit-output.

- [ ] **Step 2: Slet midlertidig analyse-rapport**

```bash
git rm dev/audit-output/phase2-analysis-report.md
```

- [ ] **Step 3: Commit dokumentation**

```bash
git add NEWS.md
git commit -m "docs(news): Fase 2 konsolidering (#203)"
```

---

## Task 11: Final verifikation + rapportér status

- [ ] **Step 1: Endelig check**

```bash
cd /Users/johanreventlow/R/biSPCharts/.worktrees/refactor-test-suite-phase2
Rscript dev/classify_tests.R --validate
Rscript dev/tests/run_tests.R 2>&1 | tail -3
Rscript dev/audit_tests.R --timeout=60 2>&1 | tail -5
```

- [ ] **Step 2: Verificér alle accept-kriterier**

- [ ] Analyse-rapport produceret og bruger-reviewet (ja — checkpoint i Task 5)
- [ ] Archive-kandidater har ≥2 matched kriterier (ja — verificeret i Task 2)
- [ ] Merged filer opfylder alle 3 kriterier (ja — Task 3)
- [ ] Rewrite følger hybrid (ja — Task 8)
- [ ] Manifest synket (ja — Tasks 6.6, 7.8, 8c)
- [ ] Total file-count reduceret (verificér: <121)
- [ ] `broken-missing-fn = 0` (verificér i audit-output)
- [ ] Fail-count reduceret eller stabil (verificér)
- [ ] NEWS-entry skrevet (ja — Task 10)
- [ ] OpenSpec change klar til arkivering

- [ ] **Step 3: Git log review**

```bash
git log --oneline master..HEAD
```

Expected: ~15-25 commits (setup + analyse × 3 + archive × N + merge × M + rewrite × K + sync × flere + docs).

- [ ] **Step 4: Rapportér til parent**

- **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED
- **File-count:** 121 → X
- **Fail-count:** 302 → Y
- **Operations:** N archived, M merged, K rewritten, L R-bugs logged til Fase 3
- **Kommit-SHAs:** antal + siste SHA
- **Ready for push/merge:** JA (afventer bruger-godkendelse)

**STOP — Push og merge er bruger-ansvar.**

---

## Accept-kriterier (samlet)

- [ ] Analyse-rapport produceret og reviewet af bruger
- [ ] Alle archive-kandidater opfylder ≥2 af 4 kriterier
- [ ] Alle merged filer opfylder alle 3 merge-kriterier (tema + <500 LOC + type-match)
- [ ] Alle rewrite-filer følger hybrid-approach efter size
- [ ] Manifest synket efter hver destruktive operation (valid efter hver)
- [ ] Total file-count reduceret (forventet: 121 → 100-110)
- [ ] `broken-missing-fn = 0` (ingen regression)
- [ ] Fail-count reduceret eller stabil (rewrite mål: <200 fails fra 302)
- [ ] NEWS-entry skrevet
- [ ] OpenSpec change klar til arkivering
