## Why

Ekstern codex-review (2026-04-21) fandt 13 WARNINGs og 4 NOTEs ved `R CMD check --no-tests`. Pakken kan i praksis ikke distribueres som R-pakke før baseline package hygiene er i orden. Flere af fundene er reelle bugs (fx `log_warn(..., session_id = ...)` der silent-fejler fordi signaturen ikke har parameteren), og andre er compliance-problemer (manglende LICENSE, forkert R-version, direkte brug af `htmltools::`/`rlang::` uden Imports-deklaration).

## What Changes

- **BREAKING** (internt): Fjern `R/NAMESPACE` som duplikat af rod-`NAMESPACE` — eneste kilde bliver `devtools::document()`-genereret rod-fil
- Tilføj `LICENSE` fil matchende `License: MIT + file LICENSE` i DESCRIPTION
- Bump `Depends: R (>= 4.0.0)` → `R (>= 4.1.0)` (pakken bruger `|>` native pipe 28 steder)
- Tilføj `htmltools` og `rlang` til `Imports:` (brugt direkte i 17 kald på tværs af 7 filer)
- Tilføj `pkgload` til `Suggests:` (brugt af test bootstrap)
- Fjern ubrugte `Imports:` verificeret via statisk analyse (`data.table`, `ggpp`, `geomtextpath`, `ggrepel`, `pdftools`, `ragg`, `svglite`, `withr` — kun dem der faktisk ikke bruges direkte)
- Fix runtime-bug: `log_warn(..., session_id = ...)` i R/fct_file_operations.R:162 (rate-limit handler) — enten udvid `log_warn`-signatur til at acceptere `session_id` eller flyt parameteren ind i `details = list(session_id = ...)`
- Regenerér `man/*.Rd` via `devtools::document()` — fix signatur-mismatches og fjern forældede filer
- Fjern `LazyData: true` (ingen `data/` mappe) eller tilføj placeholder-data
- Fjern `VignetteBuilder: knitr` (ingen `vignettes/`) — kan tilføjes igen når vignettes skrives
- Undertryk startup messages (fx `.onAttach` uden `packageStartupMessage()`-wrapper hvis nødvendigt)
- Fjern committed artefakter: `.DS_Store`, `Rplots.pdf`, `tests/testthat/testthat-problems.rds`, `inst/templates/typst/test_output.pdf`
- Udvid `.gitignore` til at blokere disse fremover
- Indfør `R CMD check --as-cran` gate med 0 warnings som release-kriterie (dokumenteret i `docs/PRE_RELEASE_CHECKLIST.md` og pre-push hook)

## Impact

- **Affected specs**: `package-hygiene` (ny capability)
- **Affected code**:
  - `DESCRIPTION`, `NAMESPACE`, `R/NAMESPACE` (slettes)
  - `R/fct_file_operations.R` (log_warn-fix)
  - `R/utils_logging.R` (evt. udvide log_warn-signatur)
  - `man/` (regenereres)
  - `.gitignore` (udvides)
  - `dev/git-hooks/pre-push` (tilføj R CMD check-trin i full-mode)
  - `docs/PRE_RELEASE_CHECKLIST.md` (ny eller opdateret)
- **Risks**:
  - Fjernelse af Imports kan bryde transitive users — mitigeret ved statisk verifikation
  - R ≥ 4.1.0 kan afvise meget gamle installationer — bevidst accept, pakken bruger allerede `|>`
- **Non-breaking for brugere**: Ingen ændring af public API, run_app()-signaturer eller UI-adfærd

## Related

- GitHub Issue: #287 (paraply)
- Sub-issues: #290 (LICENSE), #291 (log_warn bug), #292 (artefakter), #293 (DESCRIPTION/NAMESPACE/docs)
- Codex-review: 2026-04-21 session
