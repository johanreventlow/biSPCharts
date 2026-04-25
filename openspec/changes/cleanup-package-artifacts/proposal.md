## Why

Reviews (Claude + Codex, 2026-04-24) identificerede en samling af lavthængende cleanup-items der akkumuleres over tid og forurener repo/tarball: (1) `R/utils_profiling.R` er en 3-linjers kommentar-fil uden funktioner — død placeholder. (2) `CLAUDE.md.backup`, `NAMESPACE.backup`, `Rplots.pdf` ligger i repo-root. (3) `tests/_archive/testthat-legacy/` indeholder arkiverede tests der ikke bør være i aktivt repo. (4) 34 rå `cat()`/`print()`-statements i production-kode udenfor logging-system. (5) 84+ linjer >120 tegn uden styler-check. (6) 10+ duplicate `skip("testServer-migration — se #230")`-stubs i testfiler. Disse items kan ryddes hurtigt uden arkitekturændringer.

## What Changes

- Slet `R/utils_profiling.R` (tom placeholder).
- Slet `CLAUDE.md.backup`, `NAMESPACE.backup`, `Rplots.pdf` fra repo-root.
- Arkivér eller slet `tests/_archive/testthat-legacy/` efter maintainer-beslutning (default: slet, git-historik bevarer dem).
- Konvertér alle 34 `cat()`/`print()`-statements i `R/` (ikke test-helpers) til `log_debug()`/`log_info()`/`log_warn()` baseret på context. Audit via `grep -rn "cat(\|print(" R/`.
- Kør `styler::style_pkg()` og commit formatering som separat commit (så efterfølgende PRs ikke forurenes af styler-diffs).
- Konsolidér 10+ duplicate `skip("testServer-migration — se #230")`-stubs: enten (a) implementér testen hvis scope er lille, (b) slet stubben hvis sagen er forældet, (c) placér én samlet "skipped tests awaiting #230"-rapport i `tests/testthat/test-pending-issue-230.R`.
- Udvid `.gitignore` til at forhindre fremtidige forekomster: `*.backup`, `Rplots.pdf`, `..Rcheck/`, `.DS_Store` (flere er allerede — verificér).

## Impact

- **Affected specs**: `package-hygiene` (ADDED requirements)
- **Affected code**:
  - Slettes: `R/utils_profiling.R`, `CLAUDE.md.backup`, `NAMESPACE.backup`, `Rplots.pdf`, evt. `tests/_archive/testthat-legacy/`
  - Modificeres: 34 filer med `cat()/print()`-kald, alle R-filer pga. styler-run, 10+ testfiler med duplicate skip-stubs
  - `.gitignore` (udvides)
- **Risks**:
  - Styler-run kan overlappe med pending PRs — koordinér merge-timing
  - Sletning af `tests/_archive/` bør bekræftes i PR-review
- **Non-breaking for brugere**: Rent internt cleanup.

## Related

- GitHub Issue: #316
- Review-rapport: Claude + Codex 2026-04-24 (hurtige gevinster-sektion)
