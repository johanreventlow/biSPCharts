# ADR-018: Minimalt public API surface

Status: Accepted

Kontekst: NAMESPACE eksporterede 24+ funktioner inkl. app-interne UI-builders,
Shiny-moduler og analytics-pipeline. Dette gør intern refaktorering sværere da
utilsigtede eksterne brugere kan afhænge af funktioner der aldrig var tiltænkt
public brug. Codex-review (2026-04-24) og Claude-review identificerede problemet.

Beslutning: Reducer NAMESPACE til 4 stabile public exports:
- `run_app()` — primær entry point
- `compute_spc_results_bfh()` — SPC-beregnings-API
- `should_track_analytics()` — analytics consent check
- `get_analytics_config()` — analytics konfiguration

Alle øvrige 20 funktioner er gjort interne via `@keywords internal` uden `@export`.
Downstream-verifikation (BFHcharts, BFHtheme, BFHllm) bekræftede ingen ekstern
afhængighed af de fjernede exports.

Konsekvenser:
- Intern refaktorering er nu friere — interne funktioner kan ændres uden semver-bump
- Breaking change dokumenteret i NEWS.md v0.3.0 (pre-1.0 MINOR tillader breaking)
- Mindsker risiko for utilsigtet API-kontrakt med fremtidige brugere

Dato: 2026-04-25
