# CI Setup Guide

Denne guide beskriver det CI-setup som blev pilot-implementeret på biSPCharts og hvordan det replikeres til sibling-pakkerne (BFHcharts, BFHllm, BFHtheme).

## Status

| Pakke | CI status | Type |
|-------|-----------|------|
| biSPCharts | ✅ Pilot (Issue #TBD) | Privat repo, Shiny app (golem) |
| BFHcharts | ⏳ Pending replikation | Public repo, R-pakke (upstream-vigtigst) |
| BFHllm | ⏳ Pending replikation | Public repo, R-pakke |
| BFHtheme | ⏳ Pending replikation | Public repo, R-pakke |

## Workflows i pilot

To workflows i `.github/workflows/`:

### `R-CMD-check.yaml`
- **Trigger:** push/PR til `master`, manuel via `workflow_dispatch`
- **Matrix:** `ubuntu-latest` + `windows-latest`, R release
- **Hvad:** `R CMD check --as-cran --no-manual` (matcher 9-trins pre-release checklist)
- **Køretid:** ~15-25 min per matrix-job (cached)

### `lint.yaml`
- **Trigger:** samme som R-CMD-check
- **Platform:** ubuntu-latest only
- **Hvad:** `lintr::lint_package()`
- **Køretid:** ~2-3 min (installerer ikke pakke-deps)

## Replikering til sibling-pakker

For hver sibling-pakke (BFHcharts, BFHllm, BFHtheme):

1. **Kopiér workflow-filer:**
   ```bash
   cd /Users/johanreventlow/R/<PACKAGE>
   mkdir -p .github/workflows
   cp /Users/johanreventlow/R/biSPCharts/.github/workflows/R-CMD-check.yaml .github/workflows/
   cp /Users/johanreventlow/R/biSPCharts/.github/workflows/lint.yaml .github/workflows/
   ```

2. **Tilpas workflows:**
   - **Fjern shinytest2-relaterede env-variabler** (`CI_SKIP_SHINYTEST2`, `GOOGLE_API_KEY`, `GEMINI_API_KEY`) — kun biSPCharts bruger dem
   - **Verificér default branch:** Tjek om pakken bruger `main` eller `master` og opdatér `branches:` listen
   - **Behold matrix:** Ubuntu + Windows er stadig fornuftigt (Region H Windows-prod for sibling-pakker)

3. **Verificér lokalt før push:**
   ```bash
   Rscript -e "devtools::check()"
   ```

4. **Push og verificér på GitHub:**
   ```bash
   git checkout -b feat/ci-setup
   git add .github/workflows/
   git commit -m "feat(ci): tilfoej R CMD check + lint workflows"
   git push -u origin feat/ci-setup
   # Aabn PR mod master/main, tjek at begge jobs er groenne
   ```

## Anbefalet rækkefølge

1. **BFHcharts først** (upstream — alle andre afhænger af det)
2. **BFHllm + BFHtheme** (kan ske parallelt efter BFHcharts)
3. **Cross-repo trigger** (efter alle 4 har CI):
   - I BFHcharts `.github/workflows/`: tilføj job der trigger biSPCharts via `repository_dispatch`
   - Kræver `BISPCHARTS_DISPATCH_TOKEN` secret med `repo` scope
   - Detaljer: se [GitHub Docs - repository_dispatch](https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event)

## Branch protection (manuel GitHub-setting)

Efter CI er grøn på master, aktivér branch protection for at blokere merge ved fejl:

1. GitHub repo → **Settings → Branches → Add rule**
2. Branch name pattern: `master`
3. ✅ Require status checks to pass before merging
   - Vælg: `R-CMD-check (ubuntu-latest, release)`, `R-CMD-check (windows-latest, release)`, `lint`
4. ✅ Require branches to be up to date
5. (Valgfrit) ✅ Require pull request review

## shinytest2-håndtering

biSPCharts har shinytest2-baserede tests der hænger i non-interaktive miljøer (chromote-bug). De er guarded med:

```r
# Top af test-fil
if (Sys.getenv("CI") != "true" && Sys.getenv("CI_SKIP_SHINYTEST2") != "true") {
  if (requireNamespace("shinytest2", quietly = TRUE)) {
    library(shinytest2)
  }
}

# Hver test_that()
test_that("...", {
  skip_if_not_installed("shinytest2")
  skip_on_ci()
  # ...
})
```

GitHub Actions sætter automatisk `CI=true` så `skip_on_ci()` virker out-of-the-box.

## Cost

- **Public repos** (BFHcharts, BFHllm, BFHtheme): Ubegrænset gratis CI-tid
- **Privat repo** (biSPCharts): 2000 min/måned gratis. Realistisk forbrug ~300-600 min/måned

## Næste evolutionstrin (out of scope for pilot)

- [ ] Coverage-rapport via `covr` + Codecov badge
- [ ] R-devel og oldrel matrix (kun release nu)
- [ ] macOS i matrix (10x dyrere — kun hvis private-quote presses)
- [ ] `repository_dispatch` cross-repo trigger
- [ ] Style check (`styler::style_pkg(dry = "on")` i CI)
- [ ] Scheduled nightly job med seneste GitHub-deps (proaktiv cross-repo regression)
