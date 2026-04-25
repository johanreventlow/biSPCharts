## Why

Codex-review (2026-04-24) identificerede at NAMESPACE (42 linjer) eksporterer UI-builders, module-servers, analytics-helpers, og `compute_spc_results_bfh` — mange af disse er app-internals der ikke bør have stabil public API-kontrakt. Konsekvens: intern refaktor er sværere fordi utilsigtede eksterne brugere kan afhænge af exports. Claude-review tilføjede at reducering af exports er teknisk BREAKING change — selvom ingen rigtige eksterne brugere findes, bør det ske som separat proposal med bevidst dokumentation og version-bump. Pakken er pre-1.0 så breaking changes i MINOR er tilladt, men skal markeres tydeligt.

## What Changes

- **BREAKING (pre-1.0 MINOR)**: Fjern eller markér som `@keywords internal` følgende exports fra NAMESPACE:
  - UI-builders: `create_ui_header`, `create_ui_main_content`, `create_ui_upload_page`, `create_chart_settings_card_compact` (intern UI)
  - Module-servers/UI: `mod_app_guide_server/ui`, `mod_help_server/ui`, `mod_landing_server/ui`, `mod_export_server/ui` (app-interne moduler)
  - Internals: `app_server`, `app_ui`, `main_app_server` (kaldes af run_app, ikke direkte af brugere)
  - Analytics: `ANALYTICS_CONFIG`, `setup_analytics_consent`, `format_analytics_metadata`, `aggregate_and_pin_logs`, `rotate_log_files`, `read_shinylogs_all`, `read_shinylogs_sessions` (intern analytics-pipeline)
- **Beholdt som public**: `run_app`, `should_track_analytics`, `get_analytics_config`, `compute_spc_results_bfh` (eneste reelle stable-API-kandidater)
- Verificér at ingen ekstern pakke i BFH-økosystemet (BFHcharts, BFHtheme, BFHllm) afhænger af de eksporter der fjernes.
- Opdatér `NEWS.md` med klar `## Breaking changes`-sektion der lister hver fjernet eksport + migration-hint (typisk: "brug run_app() i stedet" eller "intern funktion — ingen offentlig erstatning").
- Opdatér `DESCRIPTION` Version: bump MINOR (pre-1.0 semver: `0.2.0 → 0.3.0`).
- Kør `R CMD check` mod externe sibling-pakker (BFHcharts, BFHtheme, BFHllm) for at verificere ingen brænder.

## Impact

- **Affected specs**: `package-hygiene` (ADDED requirement for minimal public API)
- **Affected code**:
  - `NAMESPACE` (regenereres via `devtools::document()` efter `@keywords internal`-tagging)
  - Roxygen-headers på ~15 exports: tilføj `@keywords internal` + fjern `@export`
  - `NEWS.md` (BREAKING-sektion)
  - `DESCRIPTION` (version-bump)
- **Risks**:
  - Downstream-brugere kan brænde hvis de har direkte afhængigheder — mitigeret ved verifikation mod BFH-økosystem
  - Hvis ekstern kode afhænger af fjernet eksport: midlertidigt behold export + deprecation-warning
- **Breaking for brugere**: Ja — pre-1.0 acceptabelt, dokumenteret i NEWS.md.

## Related

- GitHub Issue: #324
- Review-rapport: Codex V4 (Public API er for bred/uklar)
