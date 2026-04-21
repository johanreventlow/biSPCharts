## 1. DESCRIPTION og LICENSE

- [ ] 1.1 Opret `LICENSE` fil (MIT-standardskabelon, copyright holder = Johan Reventlow, year = 2026)
- [ ] 1.2 Bump `Depends: R (>= 4.1.0)` i DESCRIPTION
- [ ] 1.3 Tilføj `htmltools`, `rlang` til `Imports:` med minimumsversioner
- [ ] 1.4 Tilføj `pkgload` til `Suggests:`
- [ ] 1.5 Fjern verificeret ubrugte `Imports:` (kør `devtools::check()` efter hver fjernelse for at fange transitive brug)
- [ ] 1.6 Fjern `LazyData: true` (ingen `data/` mappe findes)
- [ ] 1.7 Fjern `VignetteBuilder: knitr` (ingen `vignettes/`)

## 2. NAMESPACE oprydning

- [ ] 2.1 Audit R/NAMESPACE vs rod-NAMESPACE — dokumentér forskelle i git commit message
- [ ] 2.2 Slet `R/NAMESPACE`
- [ ] 2.3 Kør `devtools::document()` og verificer rod-`NAMESPACE` er konsistent
- [ ] 2.4 Verificer at alle `@export`-markerede funktioner er tilgængelige efter `devtools::load_all()`

## 3. log_warn runtime bug

- [ ] 3.1 Beslut fix-strategi: (a) udvid `log_warn()` signatur med `session_id` OR (b) flyt `session_id` ind i `details = list(...)`
- [ ] 3.2 Anbefalt valg (b): mindst invasivt, bevarer struktureret logging
- [ ] 3.3 Opdater R/fct_file_operations.R:162 (rate-limit handler)
- [ ] 3.4 Søg efter andre kald med `session_id = ...` der ikke er i `details` og fix dem
- [ ] 3.5 Tilføj regression-test: `test_that("log_warn accepts session_id in details without error")`

## 4. Artefakt-oprydning

- [ ] 4.1 Fjern `.DS_Store` filer rekursivt
- [ ] 4.2 Fjern `Rplots.pdf`
- [ ] 4.3 Fjern `tests/testthat/testthat-problems.rds`
- [ ] 4.4 Fjern `inst/templates/typst/test_output.pdf`
- [ ] 4.5 Udvid `.gitignore` med: `.DS_Store`, `Rplots.pdf`, `**/testthat-problems.rds`, `test_output.*`
- [ ] 4.6 Verificer at `git status` er ren efter oprydning

## 5. Rd-regenerering

- [ ] 5.1 Kør `devtools::document()` — fang alle ændringer
- [ ] 5.2 Fix signatur-mismatches identificeret af `R CMD check`
- [ ] 5.3 Slet forældede `man/*.Rd` filer uden kildekode
- [ ] 5.4 Commit regenerated `man/` som separat commit

## 6. R CMD check gate

- [ ] 6.1 Kør `R CMD check --as-cran --no-tests --no-manual --no-vignettes --no-build-vignettes` og verificer 0 WARNINGs
- [ ] 6.2 Dokumentér alle tilbageværende NOTEs med begrundelse i `docs/PRE_RELEASE_CHECKLIST.md`
- [ ] 6.3 Tilføj R CMD check-trin til `dev/git-hooks/pre-push` i full-mode (ikke fast-mode)
- [ ] 6.4 Opdater `docs/PRE_RELEASE_CHECKLIST.md` med nyt krav: "R CMD check --as-cran uden warnings"

## 7. Dokumentation

- [ ] 7.1 Opdater README hvis dependency-instruktioner har ændret sig
- [ ] 7.2 Tilføj NEWS.md entry under "(development)" med oversigt over hygiene-fixes
- [ ] 7.3 Link GitHub issues til hver task-gruppe

## 8. Verifikation

- [ ] 8.1 `devtools::load_all()` kører rent
- [ ] 8.2 `devtools::test()` bestået (skal dog ikke være værre end før; #279/#280 forventes stadig røde)
- [ ] 8.3 Shiny-app starter (`run_app()`)
- [ ] 8.4 R CMD check-output committet som artefakt eller beskrevet i PR-body

Tracking: GitHub Issue TBD
