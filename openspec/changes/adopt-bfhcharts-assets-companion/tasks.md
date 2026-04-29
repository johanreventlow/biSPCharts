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
- [ ] 3.5 Verificér at `bisp_system_file()` stadig fungerer for `bfh-template.typ` (eneste resterende fil)

## 4. manifest.json regen

- [x] 4.1 Installer `BFHchartsAssets` lokalt fra GitHub@v0.1.0 via pak
- [x] 4.2 Reinstaller `BFHcharts` fra GitHub@v0.11.1 (renv-source-tracking)
- [ ] 4.3 Kør `Rscript dev/_regen_manifest.R` (kuratet appFiles-liste — undgår 10000-fil-limit)
- [ ] 4.4 Verificér at `manifest.json` har komplet `Remote*`-felter for: `BFHchartsAssets`, `BFHcharts`, `BFHtheme`, `BFHllm`
- [ ] 4.5 Diff manifest mod tidligere version

## 5. Tests

- [ ] 5.1 Opdatér tests for `inject_template_assets()` (hvis findes)
- [ ] 5.2 Tilføj test der mocker `BFHchartsAssets`-fravær
- [ ] 5.3 Kør `devtools::test()`
- [ ] 5.4 Kør `devtools::check()`

## 6. Connect Cloud setup (MANUELT)

- [ ] 6.1 **[MANUELT]** Generér GitHub PAT med scope `repo`
- [ ] 6.2 **[MANUELT]** Connect Cloud → biSPCharts app → Settings → Environment Variables: `GITHUB_PAT=<token>`
- [ ] 6.3 **[MANUELT]** Re-deploy biSPCharts via `rsconnect::deployApp()`
- [ ] 6.4 **[MANUELT]** Verifikation: download genereret PDF, bekræft Mari + logos rendres

## 7. NEWS + dokumentation

- [ ] 7.1 NEWS.md / CHANGELOG.md entry under `## Sikkerhed`
- [ ] 7.2 Opdatér `CLAUDE.md` med BFHchartsAssets-dependency reference

## 8. License-history follow-up (BLOCKED)

⚠️ **OPEN:** proprietære fonts forbliver i biSPCharts git history selv efter denne change.

- [ ] 8.1 **[BESLUTNING]** Skal git history purges via `git filter-repo`?
- [ ] 8.2 Hvis ja: backup repo, kør filter-repo, force-push
- [ ] 8.3 Hvis nej: dokumentér beslutning + risiko

## 9. Release

- [ ] 9.1 PR til develop fra `feat/adopt-bfhcharts-assets-companion`
- [ ] 9.2 CI grøn
- [ ] 9.3 Merge + bump biSPCharts version
