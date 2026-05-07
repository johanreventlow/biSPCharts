# Claude Instructions – biSPCharts

**Project-type rules (Tier 2 — Shiny):**

@~/.claude/rules-profiles/shiny/SHINY_STANDARDS.md
@~/.claude/rules-profiles/shiny/SHINY_ADVANCED_PATTERNS.md
@~/.claude/rules-profiles/shiny/ARCHITECTURE_PATTERNS.md

**On-demand (Tier 3 — uncomment ved aktiv brug):**

<!-- @~/.claude/rules-ondemand/OBSERVABILITY_STANDARDS.md -->
<!-- @~/.claude/rules-ondemand/DEPLOYMENT_GUIDE.md -->
<!-- @~/.claude/rules-ondemand/TROUBLESHOOTING_GUIDE.md -->
<!-- @~/.claude/rules-ondemand/CI_CD_WORKFLOW.md -->

---

## ⚠️ OBLIGATORISKE REGLER (KRITISK)

❌ **ALDRIG:**
1. Merge til master/main uden eksplicit godkendelse
2. Push til remote uden anmodning
3. Tilføj Claude attribution footers (`🤖 Generated with [Claude Code]` /
   `Co-Authored-By: Claude <noreply@anthropic.com>`)

---

## 1) Project Overview

- **Project Type:** Shiny Application (Golem framework)
- **Purpose:** Statistical Process Control (SPC) klinisk kvalitetsarbejde
  Bispebjerg + Frederiksberg Hospital. Krav: stabilitet, forståelighed,
  dansk sprog.
- **Status:** Production

**Technology Stack:**
- Shiny + Golem
- BFHcharts (SPC visualization), BFHtheme (branding), BFHllm (AI/LLM)
- BFHchartsAssets (privat companion-pkg med proprietære fonts/logoer; staages via `inject_template_assets()` ved runtime; kræver `GITHUB_PAT` for Connect Cloud)
- qicharts2 (Anhøj rules)
- Ragnar (RAG knowledge store, via BFHllm)

---

## 2) Project-Specific Architecture

### Unified Event Architecture

Centraliseret event-bus, ingen ad-hoc reactiveVal-triggers:

```r
# Emit
emit$data_updated(context = "upload")

# Listen (priority + ignoreInit)
observeEvent(app_state$events$data_updated,
  ignoreInit = TRUE, priority = OBSERVER_PRIORITIES$HIGH, {
  handle_data_update()
})
```

**Filer:** `global.R` (events), `R/utils_server_event_listeners.R` (`setup_event_listeners()`),
emit API via `create_emit_api()`.

### App State Structure

Hierarkisk `reactiveValues` i `R/state_management.R`:

```r
app_state$events     # Event triggers
app_state$data       # current_data, original_data, file_info
app_state$columns    # auto_detect, mappings, ui_sync
app_state$session    # Session state
```

### Golem Configuration

`inst/golem-config.yml` styrer dev/test/prod. Læs via
`golem::get_golem_options(name, default)`.

### Performance

- **Boot:** Production `library(biSPCharts)` (~50-100ms); debug
  `source('global.R')` med `options(spc.debug.source_loading = TRUE)` (~400ms+)
- **Lazy loading:** file_operations, advanced_debug, performance_monitoring
  on demand
- **Target:** Startup < 100ms (achieved 55-57ms)

### Session Persistence (Issue #193)

Auto-save (debounce 2s data / 1s settings) + auto-restore via localStorage.
Schema-version-gate (`LOCAL_STORAGE_SCHEMA_VERSION`). Class-preservation per
kolonne. Detaljer: `R/utils_local_storage.R`,
`R/utils_server_server_management.R`, `inst/app/www/local-storage.js`.

### Excel I/O

3-ark download (`Data` round-trip + `Indstillinger` round-trip + `SPC-analyse`
informational), multi-sheet upload med picker. Specs:
`openspec/specs/excel-import/`,
`openspec/changes/archive/2026-04-26-harden-export-quarto-capability/`.
Implementation: `R/fct_spc_file_save_load.R`, `R/fct_excel_sheet_detection.R`,
`R/utils_server_paste_data.R`.

---

## 3) Critical Project Constraints

### External Package Ownership

✅ **Maintainer kontrollerer fuldt:** BFHcharts (rendering), BFHtheme (branding),
BFHllm (LLM/RAG/caching), Ragnar (knowledge store), BFHchartsAssets (proprietære
fonts/logoer; privat repo, kræver `GITHUB_PAT`).

❌ **ALDRIG implementér** funktionalitet i biSPCharts som hører hjemme i ekstern
pakke (eks: target lines, font fallback, hospital colors, embeddings, BM25,
chunking).

✅ **I STEDET:** Identificér gap → opret issue/feature-request i ekstern pakke
→ implementér midlertidig workaround **kun hvis kritisk** (markér temporary)
→ fjern når ekstern pakke leverer.

### Integration Pattern

biSPCharts = **integration layer + business logic + knowledge curation**.
Ekstern pakke = engine.

biSPCharts RAG-ansvar: knowledge content (`inst/spc_knowledge/`),
integration (`R/utils_bfhllm_integration.R`), application-specific queries.

### Do NOT Modify

- `brand.yml` uden godkendelse
- **NAMESPACE** uden eksplicit godkendelse (brug `devtools::document()`)
- Breaking changes uden major version bump

### Versioning

biSPCharts + sibling-pakker følger `~/.claude/rules/VERSIONING_POLICY.md`:
strict semver (`vX.Y.Z`-tags), pre-1.0 tillader breaking i MINOR, NEWS.md
dansk, lower-bound deps, 9-trins pre-release checklist, separat
`chore(deps):`-PR ved sibling-bump.

---

## 4) Cross-Repository Coordination

### BFHcharts + qicharts2 Hybrid Architecture

✅ **Permanent hybrid:**

| Komponent | Ansvar | Package |
|-----------|--------|---------|
| **SPC Plotting** | Chart rendering, theming | BFHcharts |
| **Anhøj Rules** | Serielængde, kryds, special cause | qicharts2 |

❌ **qicharts2 KUN til** Anhøj rules + metadata extraction
✅ **BFHcharts til** alt plot-relateret

### SPC Pipeline (facade-arkitektur)

`compute_spc_results_bfh()` orkestrerer:
validate → prepare → resolve_axes → build_args → execute → decorate.
S3-typed errors arver fra `spc_error`
(`spc_input_error`, `spc_prepare_error`, `spc_render_error`).

**Filer:**
- `fct_spc_bfh_facade.R` — orkestrering (entry point)
- `fct_spc_validate.R` — input-validering
- `fct_spc_prepare.R` — data-forberedelse + numerisk parsing
- `fct_spc_bfh_params.R` — resolve_axis_units + build_bfh_args
- `fct_spc_bfh_invocation.R` — execute_bfh_request (BFHcharts-kald)
- `fct_spc_decorate.R` — decorate_plot_for_display
- `fct_spc_bfh_output.R` — output-standardisering
- `fct_spc_bfh_signals.R` — Anhøj-signal-tilknytning
- `fct_spc_contracts.R` — S3-type constructors (spc_request, spc_prepared, spc_axes)

ADR: `docs/adr/ADR-015-bfhchart-migrering.md`.

### Coordination Workflow

**Primær guide:** `docs/CROSS_REPO_COORDINATION.md`. Quick references:
`.claude/ISSUE_ESCALATION_DECISION_TREE.md`,
`.github/ISSUE_TEMPLATE/bfhchart-feature-request.md`.

**Eskalér til BFHcharts:** core rendering bugs, statistik-fejl, manglende
chart types, API-limitations.
**Fix i biSPCharts:** parameter-mapping, Shiny-reaktivitet, data-preprocessing,
dansk lokalisering, app-specifik caching.

---

## 5) Project-Specific Configuration

### Configuration Files

| Fil | Ansvar |
|-----|--------|
| `config_branding_getters.R` | Hospital branding |
| `config_chart_types.R` | SPC chart types (DA→EN) |
| `config_observer_priorities.R` | Race-prevention priorities |
| `config_spc_config.R` | SPC-konstanter |
| `config_log_contexts.R` | Centrale log-contexts |
| `config_system_config.R` | Performance, timeouts, cache |
| `config_ui.R` | UI layout |
| `inst/golem-config.yml` | Environment-config (dev/prod/test, RAG) |
| `.Renviron` | API keys (`GOOGLE_API_KEY` / `GEMINI_API_KEY`) |

**Detaljeret guide:** `docs/CONFIGURATION.md`.

### Test Commands

```r
# Alle tests
R -e "library(biSPCharts); testthat::test_dir('tests/testthat')"

# Specifik test
R -e "source('global.R'); testthat::test_file('tests/testthat/test-*.R')"
```

**Manual tests** (`tests/manual/`): kun external API-integrationer
(Gemini), interaktiv debug + cost-sensitive flows. **Køres ej i CI/CD**.

**Coverage targets:** 100% kritiske paths, ≥90% samlet, edge cases (null,
tomme, fejl, store filer).

---

## 6) Domain-Specific Guidance

### Pre-push gate

Installation: `Rscript dev/install_git_hooks.R`. Default-mode (fast) =
lintr + manifest-validering + små regressionstests. Modes:
`PREPUSH_MODE=fast|full`, `RUN_SHINYTEST2=1` (opt-in), `SKIP_PREPUSH=1`
(bypass).

⚠️ shinytest2 visual-tests miljøfølsomme — opt-in, ej push-blokering.
Stabil browser-regression hører i nightly `shinytest2.yaml` CI-job.

CI-gate-hierarki: se `.github/workflows/README.md`.

### Analytics Privacy

Payload-kontrakt + opt-in + DPIA: `docs/ANALYTICS_PRIVACY.md`. Opdatér
`ANALYTICS_PRIVACY.md` + `SHINYLOGS_ALLOWLIST` synkront ved enhver ændring
af hvad indsamles.

### Issue Tracking

Alle fejl/forbedringer dokumenteres som GitHub Issues. Reference i commits:
`fix: beskrivelse (fixes #123)`. Labels: `bug`, `enhancement`,
`documentation`, `technical-debt`, `performance`, `testing`.

### Fix-patterns store

Recurring fix-mønstre logges i `.claude/fix-patterns.jsonl` (append-only,
JSONL). Schema: `{date, pr, category, symptom, root_cause, fix, files,
detection, recurrence, prevention, related_prs}`. **Slå op før fix:**
`jq 'select(.category == "<cat>")' .claude/fix-patterns.jsonl`.
**Tilføj efter merge** hvis ikke-trivielt fix; bump `recurrence` hvis
samme pattern set før. Top-recurrence-patterns driver hook/skill-prioritering.

### AI/LLM Integration (BFHllm)

biSPCharts = thin wrapper omkring BFHllm-pakken (`Suggests + Remotes`,
graceful degradation: NULL + log warning ved fejl).

**Detaljer:** `docs/AI_INTEGRATION.md` (lag, API, config, knowledge
base, references). On-demand: `@~/R/biSPCharts/docs/AI_INTEGRATION.md`
ved aktivt arbejde med AI-features.

### Danish Language

- **UI / fejlbeskeder / kommentarer:** dansk
- **Funktions- + variabelnavne:** engelsk

**Termer:** Serieplot = SPC chart · Centrallinje = Center line ·
Kontrolgrænser = Control limits.

---

## 📚 References

**Globale rules:** Tier 1 auto-loaded fra `~/.claude/rules/`. Tier 2
Shiny-rules @-imported øverst i denne fil. Tier 3 on-demand via
auskommenterede @-imports øverst.

**Globale agents:** tidyverse-code-reviewer, performance-optimizer,
security-reviewer, test-coverage-analyzer, refactoring-advisor,
legacy-code-detector, shiny-code-reviewer, architecture-validator.

**biSPCharts-specifik bidrag-guide:** `docs/CONTRIBUTING.md`.