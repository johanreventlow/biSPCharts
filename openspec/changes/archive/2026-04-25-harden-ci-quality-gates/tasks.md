## 1. R CMD check workflow (tests aktiveret)

- [x] 1.1 Fjern `--no-tests` fra `.github/workflows/R-CMD-check.yaml` step-args ELLER opret ny fast-smoke-workflow uden tests + gate-workflow med tests
      **Valg:** Behold smoke-job (--no-tests) + tilføj nyt `R-CMD-check-gate`-job med tests
- [x] 1.2 Skift `error-on: '"error"'` → `'"warning"'` på den obligatoriske gate-workflow (ikke nødvendigvis på develop-smoke)
      **Gate-job:** `error-on: '"warning"'`; smoke-job: fortsat `error-on: '"error"'`
- [ ] 1.3 Kør workflow lokalt + i branch for at verificere alle eksisterende warnings er ryddet (afhænger af #1+#3+#4 merged først)
      **BLOKKERET:** Afhænger af `fix-dependency-namespace-guards`, `cleanup-package-artifacts`, `harden-csv-parse-error-reporting`. Gate-job er implementeret; aktiveres fuldt ved merge af deps.

## 2. Release-gate tarball job

- [x] 2.1 Tilføj nyt job `release-gate` i R-CMD-check.yaml der kører `R CMD build .` + `R CMD check biSPCharts_*.tar.gz`
- [x] 2.2 Trigger: `pull_request` mod `master` + `push` af tags `v*`
- [x] 2.3 Strikt mode: `error-on: '"warning"'` + `--as-cran`
- [x] 2.4 Verificér at tarball ikke indeholder uønskede artefakter (check output) — tarball-audit step tilføjet

## 3. Testthat trigger på develop

- [x] 3.1 Udvid `.github/workflows/testthat.yaml` triggers: `push: [master, develop]` + `pull_request: [master, develop]`
- [x] 3.2 Verificér at workflow faktisk kører den fulde `tests/testthat/`-suite (ikke kun subset) — `test_dir` uden filter
- [x] 3.3 Stop_on_failure = TRUE

## 4. Skip-inventory

- [x] 4.1 Opret `dev/audit_test_skips.R`-script der scanner `tests/testthat/*.R` for `skip(...)`-kald og kategoriserer: `environment`, `todo`, `permanent`
- [x] 4.2 Output JSON + Markdown-rapport til `dev/audit-output/skip-inventory.{json,md}`
- [x] 4.3 Tilføj step i CI der kører scriptet og kommenterer på PR med delta (antal skips + hvilke der er tilføjet/fjernet siden target-branch) — `.github/workflows/skip-inventory.yaml`
- [x] 4.4 Fejl workflow hvis `todo`-skip-antal øges uden eksplicit label `allow-skip-increase` på PRen

## 5. Shinytest2 opt-in workflow

- [x] 5.1 Opret `.github/workflows/shinytest2.yaml` med trigger: `schedule` (nightly 02:00 UTC) + `workflow_dispatch`
- [x] 5.2 Setup Chrome/Chromium med fast version-pin (`browser-actions/setup-chrome@v1`)
- [x] 5.3 Kør `RUN_SHINYTEST2=1 Rscript -e 'testthat::test_dir("tests/testthat", filter = "shinytest2|bfh-module-integration")'`
- [x] 5.4 Upload screenshots + snapshot-diffs som workflow-artifacts
- [x] 5.5 Kommentér på open PRs hvis nightly fejler (issue-opret via gh)

## 6. .Rbuildignore + tarball audit

- [x] 6.1 Udvid `.Rbuildignore` til at ekskludere: `^\.DS_Store$`, `^\.\.Rcheck$`, `^Rplots\.pdf$`, `\.backup$`, `^logs$`, `^rsconnect$`, `^todo$`, `^updates$`
      (`.claude`, `.worktrees`, `.Rproj.user` var allerede ekskluderet)
- [x] 6.2 Tilføj workflow-step der tjekker at tarball ikke indeholder matching paths — tarball-audit step i `release-gate` job

## 7. Dokumentation

- [x] 7.1 Opdater `docs/PRE_RELEASE_CHECKLIST.md` med de nye gates (tarball check, skip-inventory, shinytest2 nightly)
- [x] 7.2 Opret `.github/workflows/README.md` der beskriver workflow-hierarki
- [x] 7.3 Opdater `CLAUDE.md` pre-push sektion med ny CI-forventning
- [x] 7.4 Kør `openspec validate harden-ci-quality-gates --strict` — BESTÅET

Tracking: GitHub Issue #315
