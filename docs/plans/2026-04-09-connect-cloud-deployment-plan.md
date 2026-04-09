# Connect Cloud Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prepare biSPCharts for deployment on Posit Connect Cloud via Git-backed deployment from GitHub.

**Architecture:** Clean up dev artifacts, make BFHllm optional (Suggests), add Remotes for GitHub packages, create production app.R entry point, push to GitHub and deploy from Connect Cloud UI.

**Tech Stack:** R, Golem/Shiny, Posit Connect Cloud, GitHub, rsconnect

**Design doc:** `docs/plans/2026-04-09-connect-cloud-deployment-design.md`

---

### Task 1: Delete development artifacts

**Files:**

Remove these directories and files entirely:

- `candidates_for_deletion/` (empty)
- `todo/MAJOR_VISUALIZATION_REFACTOR.md`
- `todo/README.md`
- `todo/spc_plot_modernization_plan.md`
- `todo/test-coverage.md`
- `todo/` (directory)
- `logs/` (87 shinylogs JSON files)
- `docs/archived/` (entire directory tree - 28+ files)
- `docs/plans/2026-03-24-paste-data-design.md`
- `docs/plans/2026-03-24-paste-data-plan.md`
- `docs/plans/2026-03-24-wizard-navbar-design.md`
- `docs/plans/2026-03-24-wizard-navbar-plan.md`
- `docs/superpowers/` (entire directory tree - 7 files)
- `AGENTS.md`
- `CODE_QUALITY_REVIEW.md`

**Step 1: Delete files**

```bash
# Directories
rm -rf candidates_for_deletion/
rm -rf todo/
rm -rf logs/
rm -rf docs/archived/
rm -rf docs/superpowers/

# Old plans (keep deployment docs)
rm docs/plans/2026-03-24-paste-data-design.md
rm docs/plans/2026-03-24-paste-data-plan.md
rm docs/plans/2026-03-24-wizard-navbar-design.md
rm docs/plans/2026-03-24-wizard-navbar-plan.md

# Root files
rm AGENTS.md
rm CODE_QUALITY_REVIEW.md
```

**Step 2: Verify deletions**

```bash
# These should all fail (not found)
ls candidates_for_deletion/ 2>&1 | head -1
ls todo/ 2>&1 | head -1
ls logs/ 2>&1 | head -1
ls docs/archived/ 2>&1 | head -1
ls docs/superpowers/ 2>&1 | head -1
ls AGENTS.md 2>&1 | head -1
```

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: fjern udviklings-artefakter før deployment

Sletter candidates_for_deletion/, todo/, logs/, docs/archived/,
docs/superpowers/, gamle plans, AGENTS.md og CODE_QUALITY_REVIEW.md.
Forberedelse til Posit Connect Cloud deployment."
```

---

### Task 2: Expand .Rbuildignore

**Files:**
- Modify: `.Rbuildignore`

**Step 1: Update .Rbuildignore**

Replace the entire file with:

```
^renv$
^renv\.lock$
^.*\.Rproj$
^\.Rproj\.user$
^data-raw$
^dev$
^docs$
^openspec$
^\.github$
^Makefile$
^_brand\.yml$
^global\.R$
^\.claude$
^\.superpowers$
^\.worktrees$
^CLAUDE\.md$
^GEMINI\.md$
^johans_notes_to_self\.md$
^ARCHITECTURE_ANALYSIS\.md$
^DEPENDENCY_AUDIT\.md$
^\.lintr$
^CHANGELOG\.md$
^\.Renviron\.example$
```

**Step 2: Commit**

```bash
git add .Rbuildignore
git commit -m "chore: udvid .Rbuildignore for production build

Ekskluderer dev/, docs/, openspec/, .github/, global.R og
andre udviklingsfiler fra package build."
```

---

### Task 3: Make BFHllm optional in DESCRIPTION

**Files:**
- Modify: `DESCRIPTION`

**Step 1: Move BFHllm from Imports to Suggests, add Remotes**

In DESCRIPTION, remove this line from Imports:
```
    BFHllm (>= 0.1.0),
```

Add it to Suggests (after existing entries):
```
    BFHllm (>= 0.1.0)
```

Add new Remotes field after Config/Notes line:
```
Remotes:
    johanreventlow/BFHcharts,
    johanreventlow/BFHtheme
```

**Step 2: Commit**

```bash
git add DESCRIPTION
git commit -m "chore: flyt BFHllm til Suggests, tilfoej Remotes

BFHllm er nu valgfri (AI-features). Remotes peger paa
BFHcharts og BFHtheme paa GitHub for Connect Cloud installation."
```

---

### Task 4: Add requireNamespace guards for BFHllm

**Files:**
- Modify: `R/utils_bfhllm_integration.R` (4 functions)

**Step 1: Guard is_bfhllm_available() (line 146-154)**

Replace:
```r
is_bfhllm_available <- function() {
  available <- BFHllm::bfhllm_chat_available()

  if (!available) {
    log_warn("BFHllm not available - check API key configuration", .context = "AI_SETUP")
  }

  return(available)
}
```

With:
```r
is_bfhllm_available <- function() {
  if (!requireNamespace("BFHllm", quietly = TRUE)) {
    return(FALSE)
  }

  available <- BFHllm::bfhllm_chat_available()

  if (!available) {
    log_warn("BFHllm not available - check API key configuration", .context = "AI_SETUP")
  }

  return(available)
}
```

**Step 2: Guard initialize_bfhllm() (line 114-137)**

Replace:
```r
initialize_bfhllm <- function(ai_config = NULL, rag_config = NULL) {
  # Get config if not provided
  if (is.null(ai_config)) {
    ai_config <- get_ai_config()
  }

  # Configure BFHllm with biSPCharts settings
  BFHllm::bfhllm_configure(
```

With:
```r
initialize_bfhllm <- function(ai_config = NULL, rag_config = NULL) {
  if (!requireNamespace("BFHllm", quietly = TRUE)) {
    log_info("BFHllm not installed - AI features disabled")
    return(invisible(NULL))
  }

  # Get config if not provided
  if (is.null(ai_config)) {
    ai_config <- get_ai_config()
  }

  # Configure BFHllm with biSPCharts settings
  BFHllm::bfhllm_configure(
```

**Step 3: Guard create_bfhllm_cache() (line 166-179)**

Replace:
```r
create_bfhllm_cache <- function(session) {
  # Get TTL from biSPCharts config (if exists, otherwise use BFHllm default)
  system_config <- get_system_config()
  ttl <- system_config$cache_ttl_seconds %||% 3600 # 1 hour default

  cache <- BFHllm::bfhllm_cache_shiny(session, ttl_seconds = ttl)
```

With:
```r
create_bfhllm_cache <- function(session) {
  if (!requireNamespace("BFHllm", quietly = TRUE)) {
    return(NULL)
  }

  # Get TTL from biSPCharts config (if exists, otherwise use BFHllm default)
  system_config <- get_system_config()
  ttl <- system_config$cache_ttl_seconds %||% 3600 # 1 hour default

  cache <- BFHllm::bfhllm_cache_shiny(session, ttl_seconds = ttl)
```

**Step 4: Guard generate_bfhllm_suggestion() (line 194-235)**

Replace:
```r
generate_bfhllm_suggestion <- function(spc_result, context, session, max_chars = NULL) {
  # Get max_chars from config if not specified
  if (is.null(max_chars)) {
```

With:
```r
generate_bfhllm_suggestion <- function(spc_result, context, session, max_chars = NULL) {
  if (!requireNamespace("BFHllm", quietly = TRUE)) {
    log_info("BFHllm not installed - skipping AI suggestion")
    return(NULL)
  }

  # Get max_chars from config if not specified
  if (is.null(max_chars)) {
```

**Step 5: Commit**

```bash
git add R/utils_bfhllm_integration.R
git commit -m "feat: goer BFHllm valgfri med requireNamespace guards

Alle fire BFHllm-wrapper funktioner tjekker nu om pakken er
installeret foer brug. Returnerer NULL/FALSE gracefully hvis
BFHllm ikke er tilgaengelig."
```

---

### Task 5: Create production app.R and dev/run_dev.R

**Files:**
- Move: `app.R` -> `dev/run_dev.R`
- Create: `app.R` (new, production)

**Step 1: Copy current app.R to dev/run_dev.R**

Create `dev/run_dev.R` with the current content of `app.R`, but update the header comment:

```r
# dev/run_dev.R
# Development entry point for SPC App
# Brug: source("dev/run_dev.R") fra RStudio eller terminal
#
# Denne fil indlaeser sibling-pakker (BFHtheme, BFHcharts, BFHllm)
# fra kildekode saa vi altid tester nyeste version under udvikling.
#
# For production: Se app.R (brugt af Posit Connect Cloud)

# ==============================================================================
# DEBUG CONTEXT FILTERING - Reduce token usage when debugging
# ==============================================================================
# (... rest of current app.R content unchanged ...)
```

**Step 2: Create new production app.R**

```r
# app.R
# Production entry point for Posit Connect Cloud
# For lokal udvikling: brug source("dev/run_dev.R")
library(biSPCharts)
biSPCharts::run_app()
```

**Step 3: Commit**

```bash
git add app.R dev/run_dev.R
git commit -m "chore: adskil production og development entry points

app.R er nu production-klar (3 linjer) til Connect Cloud.
dev/run_dev.R indeholder dev-loading af sibling-pakker."
```

---

### Task 6: Verify locally

**Step 1: Test at pakken kan installeres**

```bash
'/c/Program Files/R/R-4.5.2/bin/Rscript.exe' -e "devtools::install(dependencies = FALSE)"
```

Expected: Installation succeeds.

**Step 2: Test at production app.R loader korrekt**

```bash
'/c/Program Files/R/R-4.5.2/bin/Rscript.exe' -e "library(biSPCharts); cat('OK\n')"
```

Expected: Prints "OK" without errors.

**Step 3: Test at dev workflow stadig virker**

```bash
'/c/Program Files/R/R-4.5.2/bin/Rscript.exe' -e "source('dev/run_dev.R')" &
# Lad appen starte, verificer i browser, luk med Ctrl+C
```

Expected: App starts with sibling package loading messages.

**Step 4: Test at BFHllm graceful degradation virker**

```bash
'/c/Program Files/R/R-4.5.2/bin/Rscript.exe' -e "
  library(biSPCharts)
  cat('is_bfhllm_available:', is_bfhllm_available(), '\n')
"
```

Expected: Returns TRUE (if BFHllm installed) or FALSE (if not) - no error.

---

### Task 7: Push to GitHub

**Step 1: Verify all changes**

```bash
git status
git log --oneline -5
```

**Step 2: Push**

(Venter paa bruger-instruktion)

```bash
git push origin master
```

---

### Task 8: Deploy from Connect Cloud

**[MANUELT TRIN]** Udfoeres af bruger i Connect Cloud UI:

1. Gaa til Posit Connect Cloud
2. "New Content" -> "From Git Repository"
3. Vaelg `johanreventlow/biSPCharts`
4. Branch: `master`
5. Entry point: `app.R`
6. Klik "Deploy"
7. Vent paa build (Connect Cloud installerer dependencies fra DESCRIPTION + Remotes)
8. Verificer at appen kører og kan modtage data-upload
