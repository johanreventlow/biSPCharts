## Why

Codex-review (2026-04-24) identificerede at Anhøj-regel-derivation udføres to steder i pakken: (1) i `R/mod_spc_chart_compute.R:410` i compute-observer, og (2) i cache-aware observer. De to implementationer kan divergere og har givet subtle regression-bugs (dokumenteret i test-critical-fixes-*). Claude-review noterede at `fct_spc_bfh_signals.R` (288 linjer) indeholder relateret logik med yderligere `qicharts2::qic`-kald. Samlet: Anhøj-beregning er spredt over mindst 3 steder, hvert med let forskellig input-preparation. Løsningen er at ekstrahere én pure funktion `derive_anhoej_results(qic_data, chart_type, show_phases)` som er eneste kilde til Anhøj-metadata og kan unit-testes deterministisk.

## What Changes

- Opret `R/fct_spc_anhoej_derivation.R` med pure funktion `derive_anhoej_results(qic_data, chart_type, show_phases = FALSE)` der returnerer struktureret output: `list(crossings, longest_run, runs_signal, crossings_signal, special_cause_points)`.
- Funktionen SHALL være ren: ingen Shiny-dependency, ingen `app_state`-læsning, ingen side-effects, ingen caching. Caching håndteres af kaldere.
- Refaktorér `R/mod_spc_chart_compute.R:410` til at kalde `derive_anhoej_results()` i stedet for inline-logik.
- Refaktorér cache-aware observer til samme kald.
- Konsolidér beslægtet logik i `R/fct_spc_bfh_signals.R` hvor muligt — enten som tynd wrapper eller erstat helt. Behold `calculate_combined_anhoej_signal()`-API hvis downstream bruger det.
- Tilføj omfattende pure-unit-tests i `tests/testthat/test-derive-anhoej-results.R`: baseline-fixtures, edge cases (tomme data, 1-punkt, NA-punkter, frys/skift-scenarier).
- Tilføj regression-test der verificerer at begge gamle call-sites (compute.R + cache observer) nu producerer identiske resultater for en battery af test-inputs.

## Impact

- **Affected specs**: `spc-facade` (MODIFIED requirements + ADDED requirement for pure derivation)
- **Affected code**:
  - Ny: `R/fct_spc_anhoej_derivation.R`
  - Modificeret: `R/mod_spc_chart_compute.R` (compute-observer kald)
  - Modificeret: cache-aware observer (find via grep hvis ikke i compute.R)
  - Modificeret/Konsolideret: `R/fct_spc_bfh_signals.R`
  - Ny: `tests/testthat/test-derive-anhoej-results.R`
- **Afhængighed**: Skal landes efter `fix-dependency-namespace-guards` (qicharts2-guards), da `derive_anhoej_results()` vil bruge guarded kald.
- **Risks**:
  - Divergence mellem nuværende to implementationer kan afsløre subtile bugs — test mod begge før refaktor for at dokumentere baseline
  - Performance-regression hvis pure-funktion ikke kan genbruge cache-miss-optimering
- **Non-breaking for brugere**: Ingen UI-ændring. Pure funktion, samme metadata.

## Related

- GitHub Issue: #318
- Review-rapport: Codex 2026-04-24 (K3: SPC compute-logik orchestration-heavy)
