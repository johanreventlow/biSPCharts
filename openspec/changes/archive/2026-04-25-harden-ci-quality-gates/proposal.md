## Why

Codex-review (2026-04-24) fandt at CI giver falsk tryghed: `.github/workflows/R-CMD-check.yaml:53` kører `R CMD check` med `--no-tests` og `error-on: '"error"'`. Betyder WARNINGs og NOTEs blokerer IKKE en PR, og testsuite køres aldrig som del af package-checket. `.github/workflows/testthat.yaml` kører kun på master. `CI_SKIP_SHINYTEST2=true` betyder E2E/shinytest2 aldrig kører i CI. Der er ingen tarball-build check. Resultatet: grøn CI garanterer ikke at pakken kan installeres, ikke at regression-tests passerer, og ikke at package-hygiejne er ren. Review fandt 544+ skip-referencer i testsuite — uden CI-synlighed over skip-count kan gæld akkumulere ubemærket.

## What Changes

- Introducér **release-gate job** i R-CMD-check workflow der kører tarball R CMD check (`R CMD build .` + `R CMD check biSPCharts_*.tar.gz`) med `error-on: '"warning"'` — kører på PRs mod `master` og release-tags.
- Fjern `--no-tests` fra den ene obligatoriske workflow-step (mindst én run SKAL køre tests). Behold eventuel fast develop-smoke-check uden tests hvis hastighed er kritisk.
- Udvid `testthat.yaml` til at køre på `develop` push/PR (ikke kun master).
- Tilføj **skip-inventory CI-step**: kør en lint-pass der tæller `skip(...)`-kald per kategori (miljø-skip vs TODO-skip vs permanent-skip). Publicér som workflow-artifact og som kommentar på PR. Fejl hvis TODO-skip-antal øges uden begrundelse.
- Tilføj **shinytest2-gating-regime**: separat opt-in CI-job (`shinytest2.yaml`) der kører med kontrolleret Chrome/Chromium-miljø. Kører nightly + on-demand, ikke per-PR (visuel regression er miljøfølsom).
- Tilføj `.Rbuildignore`-audit-step: verificér at tarball ikke indeholder `.claude/`, `.worktrees/`, `.Rproj.user/`, `.DS_Store`, `..Rcheck/`, `Rplots.pdf`, `*.backup`, `logs/`, `rsconnect/`.
- Dokumentér nye gates i `docs/PRE_RELEASE_CHECKLIST.md` og `.github/workflows/README.md`.

## Impact

- **Affected specs**: `test-infrastructure` (MODIFIED + ADDED), `package-hygiene` (ADDED)
- **Affected code**:
  - `.github/workflows/R-CMD-check.yaml` (fjern --no-tests, tilføj release-gate job)
  - `.github/workflows/testthat.yaml` (trigger på develop)
  - `.github/workflows/shinytest2.yaml` (ny, opt-in)
  - `.github/workflows/skip-inventory.yaml` (ny, eller step i eksisterende)
  - `.Rbuildignore` (udvid)
  - `docs/PRE_RELEASE_CHECKLIST.md`
- **Afhængighed**: Depends on `fix-dependency-namespace-guards`, `cleanup-package-artifacts`, `harden-csv-parse-error-reporting` landet først, så CI ikke fejler på eksisterende WARNINGs ved aktivering.
- **Risks**:
  - Nye WARNINGs kan afsløres når gate strammes — forventet, og skal adresseres som del af implementationen.
  - Tarball-build-tid øges; acceptabel pris for reel package-hygiejne.
- **Non-breaking for brugere**: Rent CI/developer-experience ændring.

## Related

- GitHub Issue: #315
- Review-rapport: Codex 2026-04-24 (CI-tryghed-kritik)
