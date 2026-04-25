## Why

Review (Claude + Codex, 2026-04-24) fandt tre runtime-integritetsproblemer: (1) `qicharts2` blev flyttet til Suggests i DESCRIPTION, men kaldes 24 gange uden `requireNamespace()`-guards — minimal-install crasher ved første Anhøj-beregning. (2) BFHllm-integrationen (utils_bfhllm_integration.R, fct_ai_improvement_suggestions.R) kalder `BFHllm::bfhllm_*` aktivt, men BFHllm findes hverken i Imports, Suggests eller Remotes — runtime-status divergerer fra dokumentationen i DESCRIPTION og CLAUDE.md. (3) `utils_server_export.R:333` bruger intern `BFHcharts:::bfh_create_typst_document()` (triple-colon), hvilket er en stærk runtime-afhængighed af ikke-stabil API.

## What Changes

- Indfør `require_qicharts2()`-helper i `R/utils_error_handling.R` som kaster en typed `spc_dependency_error` hvis qicharts2 ikke er installeret. Kald den før alle 24 `qicharts2::`-brug.
- Flyt BFHllm til `Suggests:` + `Remotes:` i DESCRIPTION (pin til `johanreventlow/BFHllm@v<current>`). Opdater `Config/Notes` og fjern misvisende formulering om "midlertidigt fjernet fra deploy-bundle".
- Tilføj opstarts-log (`.onAttach`) der rapporterer status for optional-features: BFHllm, qicharts2, Quarto/Typst.
- Erstat `BFHcharts:::bfh_create_typst_document()` og `BFHcharts:::`-brug i `R/utils_server_export.R` med BFHcharts public API. Hvis API mangler: oprett issue i BFHcharts-repo og wrap med capability-check + dansk brugerbesked som fallback.
- Audit existing guards: `gert`, `pins`, `shinylogs`, `curl` har allerede `requireNamespace()`-guards i integrations-filer, men er stadig i `Imports:`. Flyt dem til `Suggests:` så minimal-install kan skippe dem.
- Tilføj lower-bounds til `excelR` og `digest` i DESCRIPTION (begge mangler version-constraints).
- Ret maintainer-email fra `noreply@example.com` til ægte email i DESCRIPTION + `Authors@R`.

## Impact

- **Affected specs**: `package-hygiene` (MODIFIED + ADDED requirements)
- **Affected code**:
  - `DESCRIPTION` (Imports → Suggests migration, version-bounds, email, Remotes)
  - `R/utils_error_handling.R` (ny `require_qicharts2()` + `require_optional_package()`)
  - `R/utils_bfhllm_integration.R` (verificér guards, ingen ændring af logic)
  - `R/utils_qic_preparation.R`, `R/fct_spc_bfh_signals.R`, `R/utils_anhoej_results.R` m.fl. (24 `qicharts2::`-kald → wrapped)
  - `R/utils_server_export.R` (fjern `:::`-brug)
  - `R/zzz.R` (`.onAttach`-optional-feature-rapport)
- **Risks**:
  - BFHllm pin kan være forældet ved merge — verificér tag ved implementation.
  - BFHcharts public Typst-API eksisterer muligvis ikke endnu — kan kræve sideløbende BFHcharts-PR.
- **Non-breaking for brugere**: Ingen UI-ændring. Optional-features fortsætter med at degradere gracefully.

## Related

- GitHub Issue: #314
- Review-rapport: Claude + Codex 2026-04-24
