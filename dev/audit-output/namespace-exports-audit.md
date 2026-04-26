# NAMESPACE Exports Audit — reduce-public-namespace-surface

Dato: 2026-04-25
Reviewer: openspec:apply

## Behold som public API (4)

| Export | Begrundelse |
|--------|-------------|
| `run_app` | Primær entry point for brugere |
| `compute_spc_results_bfh` | Stabil SPC-beregnings-API |
| `should_track_analytics` | Nyttig for integration-tests og deploy-scripts |
| `get_analytics_config` | Konfiguration-getter, nyttig eksternt |

## Gør internal (24)

| Export | Kategori | Begrundelse |
|--------|----------|-------------|
| `app_ui` | App-internal | Kun kaldt af run_app |
| `app_server` | App-internal | Kun kaldt af run_app |
| `main_app_server` | App-internal | Kun kaldt af app_server |
| `create_ui_header` | UI-builder | App-intern UI |
| `create_ui_main_content` | UI-builder | App-intern UI |
| `create_ui_upload_page` | UI-builder | App-intern UI |
| `create_chart_settings_card_compact` | UI-builder | App-intern UI |
| `mod_app_guide_server` | Shiny modul | App-internt modul |
| `mod_app_guide_ui` | Shiny modul | App-internt modul |
| `mod_export_server` | Shiny modul | App-internt modul |
| `mod_export_ui` | Shiny modul | App-internt modul |
| `mod_help_server` | Shiny modul | App-internt modul |
| `mod_help_ui` | Shiny modul | App-internt modul |
| `mod_landing_server` | Shiny modul | App-internt modul |
| `mod_landing_ui` | Shiny modul | App-internt modul |
| `ANALYTICS_CONFIG` | Analytics-intern | Intern konstant |
| `aggregate_and_pin_logs` | Analytics-pipeline | Intern pipeline |
| `format_analytics_metadata` | Analytics-pipeline | Intern pipeline |
| `read_shinylogs_all` | Analytics-pipeline | Intern pipeline |
| `read_shinylogs_sessions` | Analytics-pipeline | Intern pipeline |
| `rotate_log_files` | Analytics-pipeline | Intern pipeline |
| `setup_analytics_consent` | Analytics-pipeline | Intern pipeline |
| `init_startup_cache` | Startup-intern | Kun kaldt ved app-start |

## Downstream-verifikation

- BFHcharts: ingen `biSPCharts::`-brug fundet
- BFHtheme: ingen `biSPCharts::`-brug fundet
- BFHllm: ingen `biSPCharts::`-brug fundet

Konklusion: alle 24 kan sikkert gøres interne.
