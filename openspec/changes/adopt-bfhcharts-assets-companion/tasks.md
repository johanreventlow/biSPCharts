## 1. DESCRIPTION + Remotes

- [x] 1.1 Tilføj `BFHchartsAssets` til `Suggests`
- [x] 1.2 Tilføj `johanreventlow/BFHchartsAssets@v0.1.0` til `Remotes`
- [x] 1.3 Bump `BFHcharts (>= 0.11.0)` → `BFHcharts (>= 0.11.1)`
- [x] 1.4 Bump Remotes-pin `BFHcharts@v0.11.0` → `@v0.11.1`

## 2. inject_template_assets simplification

- [x] 2.1 Erstat `R/utils_server_export.R` `inject_template_assets()`-body med delegation
- [x] 2.2 Bevar funktion-signatur (`inject_template_assets(template_dir)`)
- [x] 2.3 Graceful fallback hvis `BFHchartsAssets` ikke installeret (log_warn + invisible(FALSE))
- [x] 2.4 Fjern `bisp_system_file()`-logik (assets ligger ikke længere i biSPCharts)

## 3. Stop tracking af proprietære assets

- [x] 3.1 `git rm -r inst/templates/typst/bfh-template/fonts/`
- [x] 3.2 `git rm -r inst/templates/typst/bfh-template/images/`
- [x] 3.3 Behold `inst/templates/typst/bfh-template/bfh-template.typ`
- [x] 3.4 `.gitignore`: tilføj defensive patterns for `fonts/` + `images/` subdirs
- [x] 3.5 Verificér at `bisp_system_file()` stadig fungerer for `bfh-template.typ` (eneste resterende fil)

## 4. manifest.json regen

- [x] 4.1 Installer `BFHchartsAssets` lokalt fra GitHub@v0.1.0 via pak
- [x] 4.2 Reinstaller `BFHcharts` fra GitHub@v0.11.1 (renv-source-tracking)
- [x] 4.3 Kør `Rscript dev/_regen_manifest.R` (kuratet appFiles-liste — undgår 10000-fil-limit)
- [x] 4.4 Verificér at `manifest.json` har komplet `Remote*`-felter for: `BFHchartsAssets`, `BFHcharts`, `BFHtheme`, `BFHllm`
- [x] 4.5 Diff manifest mod tidligere version

## 5. Tests

- [x] 5.1 Opdatér tests for `inject_template_assets()` (hvis findes) — N/A, ingen eksisterende tests; nyt `tests/testthat/test-inject-template-assets.R` oprettet
- [x] 5.2 Tilføj test der mocker `BFHchartsAssets`-fravær (4 tests: missing+no-error + delegation + companion-fail)
- [x] 5.3 Kør `devtools::test()` — 5552 PASS, 0 FAIL, 101 SKIP, 50 WARN (alle pre-existing, ej introducerede regressions)
- [ ] 5.4 Kør `devtools::check()` — DEFERRED til PR CI-gate (`gate (tests + warnings)` job)

## 6. Connect Cloud setup (MANUELT)

- [x] 6.1 **[MANUELT]** Generér GitHub PAT med scope `repo` (bekræftet udført 2026-04-30)
- [x] 6.2 **[MANUELT]** Connect Cloud → biSPCharts app → Settings → Environment Variables: `GITHUB_PAT=<token>` (bekræftet udført 2026-04-30)
- [x] 6.3 **[MANUELT]** Re-deploy biSPCharts via `rsconnect::deployApp()` (bekræftet udført 2026-04-30)
- [x] 6.4 **[MANUELT]** Verifikation: download genereret PDF, bekræft Mari + logos rendres (bekræftet udført 2026-04-30)

## 7. NEWS + dokumentation

- [ ] 7.1 NEWS.md / CHANGELOG.md entry under `## Sikkerhed`
- [ ] 7.2 Opdatér `CLAUDE.md` med BFHchartsAssets-dependency reference

## 8. License-history follow-up (BLOCKED)

⚠️ **OPEN:** proprietære fonts forbliver i biSPCharts git history selv efter denne change.

- [ ] 8.1 **[BESLUTNING]** Skal git history purges via `git filter-repo`?
- [ ] 8.2 Hvis ja: backup repo, kør filter-repo, force-push
- [ ] 8.3 Hvis nej: dokumentér beslutning + risiko

## 9. Release

- [x] 9.1 PR til develop — implementation via #379/#381/#387; finalize-PR #398 (`feat/adopt-bfhcharts-finalize`)
- [ ] 9.2 CI grøn (afventer PR #398)
- [ ] 9.3 Merge + bump biSPCharts version (afventer CI grøn)
