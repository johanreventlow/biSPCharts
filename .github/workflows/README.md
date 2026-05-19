# CI Workflow Hierarki

biSPCharts bruger fire lags CI/CD gates.

## Workflow overblik

| Workflow | Trigger | Blokerer PR? | Formål |
|----------|---------|--------------|--------|
| `R-CMD-check` (smoke) | Alle pushes/PRs | Ja (errors) | Hurtig strukturcheck — ingen tests, kun ERRORs blokerer |
| `R-CMD-check` (gate) | PRs→master + tags | Ja (warnings) | Fuld check med tests; WARNINGs blokerer |
| `R-CMD-check` (release-gate) | Push til master + tags + dispatch | Nej for PRs | Tarball-build + `--as-cran` + artifact-audit efter merge/release |
| `testthat` | PRs/push til master+develop | Ja | Fuld testthat-suite med `stop_on_failure = TRUE` |
| `skip-inventory` | PRs mod master+develop | Nej (kun TODO-stigning) | Tæller skip()-kategorier; fejler ved uberettiget TODO-stigning |
| `shinytest2` | Nightly 02:00 UTC + on-demand | Nej | Visuel regression (miljøfølsom, opt-in) |
| `lint` | Pushes/PRs | Ja | lintr-linting |
| `validate-manifest` | Pushes/PRs | Ja | Test-classification manifest + Posit Connect manifest-sync |
| `sibling-bump-poller` | Cron daglig 07:00 UTC + dispatch | Nej (auto-PR) | Polller sibling-pkg-tags (BFHcharts/BFHtheme/BFHllm/BFHchartsAssets) og opretter `chore(deps):` PR for PATCH/MINOR-bumps; issue for MAJOR-bumps (per VERSIONING §E) |

## Manifest-stale: detection vs auto-fix

`auto-regen-manifest` blev fjernet (PAT-afhængighed + platform-binary-drift mellem Linux runner og udvikler-env producerede falske diffs). Manifest-stale-detektion sker nu i 2 lag:

1. **Pre-push hook** (`dev/install_git_hooks.R`): blokerer push hvis DESCRIPTION-deps ændret uden manifest-update. Bypass: `SKIP_MANIFEST_SYNC=1 git push`.
2. **`validate-manifest` workflow** (server-side gate): blokerer PR-merge hvis manifest ude af sync.

Når `validate-manifest` fejler: kør `Rscript dev/publish_prepare.R install && Rscript dev/publish_prepare.R manifest` lokalt, commit + push.

## Gate-aktivering: afhængigheder

`R-CMD-check-gate` bruger `error-on: '"warning"'` på PRs til master.
`release-gate` kører ikke længere som almindelig PR-gate; den kører efter
merge til master, på tags og manuelt via `workflow_dispatch`. Disse gates
kræver at følgende specs er landet før release:

- `fix-dependency-namespace-guards`
- `cleanup-package-artifacts`
- `harden-csv-parse-error-reporting`

## Lokal opt-in: shinytest2

Shinytest2 kører IKKE automatisk ved push. Lokalt:

```bash
RUN_SHINYTEST2=1 Rscript -e 'testthat::test_file("tests/testthat/test-bfh-module-integration.R")'
```

CI: `gh workflow run shinytest2.yaml`

## Skip-inventory gate

Workflow fejler hvis `todo`-skip-antal øges på en PR uden label `allow-skip-increase`.
PR-kommentaren viser nu de nye TODO-skips som konkrete fil/linje-poster, ikke
kun total-deltaet.

Tilføj label hvis stigningen er intentionel:
```bash
gh pr edit <PR-nummer> --add-label "allow-skip-increase"
```

## Connect manifest gate

`validate-manifest` kører også:

```bash
Rscript dev/validate_connect_manifest.R manifest.json
```

Gate fejler hvis en GitHub-afhængighed i `DESCRIPTION`/`Remotes` mangler i
`manifest.json`, peger på et andet tag, eller har lavere version end
DESCRIPTION kræver. Standard-fix:

```bash
R_LIBS_USER=/tmp/bispcharts-r-lib Rscript dev/publish_prepare.R install
R_LIBS_USER=/tmp/bispcharts-r-lib Rscript dev/publish_prepare.R manifest
```
