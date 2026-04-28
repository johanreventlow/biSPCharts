# Claude Instructions – biSPCharts

**Bootstrap workflow:**

- Mac: `@~/.claude/rules/CLAUDE_BOOTSTRAP_WORKFLOW.md`
- Windows: `@C:/Users/jrev0004/.claude/rules/CLAUDE_BOOTSTRAP_WORKFLOW.md`

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
- **Purpose:** Statistical Process Control (SPC) til klinisk kvalitetsarbejde
  ved Bispebjerg og Frederiksberg Hospital. Krav om stabilitet, forståelighed
  og dansk sprog.
- **Status:** Production

**Technology Stack:**
- Shiny + Golem
- BFHcharts (SPC visualization), BFHtheme (branding), BFHllm (AI/LLM)
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

**Filer:** `global.R` (events), `R/utils_event_system.R` (`setup_event_listeners()`),
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
  loaded on demand
- **Target:** Startup < 100ms (achieved 55-57ms)

### Session Persistence (Issue #193)

Auto-save (debounce 2s data / 1s settings) + auto-restore via localStorage.
Schema-version-gate (`LOCAL_STORAGE_SCHEMA_VERSION`). Class-preservation per
kolonne. Detaljer i `R/utils_local_storage.R`,
`R/utils_server_server_management.R`, `inst/app/www/local-storage.js`.

### Excel I/O

3-ark download (`Data` round-trip + `Indstillinger` round-trip + `SPC-analyse`
informational), multi-sheet upload med picker. Specifikationer i
`openspec/specs/excel-import/` og
`openspec/changes/archive/2026-04-26-harden-export-quarto-capability/`.
Implementation: `R/fct_spc_file_save_load.R`, `R/fct_excel_sheet_detection.R`,
`R/utils_server_paste_data.R`.

---

## 3) Critical Project Constraints

### External Package Ownership

✅ **Maintainer kontrollerer fuldt:** BFHcharts (rendering), BFHtheme (branding),
BFHllm (LLM/RAG/caching), Ragnar (knowledge store).

❌ **ALDRIG implementér** funktionalitet i biSPCharts som hører hjemme i ekstern
pakke (eks: target lines, font fallback, hospital colors, embeddings, BM25,
chunking).

✅ **I STEDET:** Identificér gap → opret issue/feature-request i ekstern pakke
→ implementér midlertidig workaround **kun hvis kritisk** (markér som
temporary) → fjern når ekstern pakke leverer.

### Integration Pattern

biSPCharts = **integration layer + business logic + knowledge curation**.
Ekstern pakke = engine.

biSPCharts's RAG-ansvar: knowledge content (`inst/spc_knowledge/`),
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

`compute_spc_results_bfh()` orkestrerer: validate → prepare → resolve_axes →
build_args → execute → decorate. S3-typed errors arver fra `spc_error`
(`spc_input_error`, `spc_prepare_error`, `spc_render_error`).

**Filer:** `R/fct_spc_{bfh_facade,validate,prepare,execute,decorate}.R`.
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

**Manual tests** (`tests/manual/`): kun for external API-integrationer
(Gemini), interaktiv debug og cost-sensitive flows. **Køres ikke i CI/CD**.

**Coverage targets:** 100% kritiske paths, ≥90% samlet, edge cases (null,
tomme, fejl, store filer).

---

## 6) Domain-Specific Guidance

### Pre-push gate

Installation: `Rscript dev/install_git_hooks.R`. Default-mode (fast) =
lintr + manifest-validering + små regressionstests. Modes:
`PREPUSH_MODE=fast|full`, `RUN_SHINYTEST2=1` (opt-in), `SKIP_PREPUSH=1`
(bypass).

⚠️ shinytest2 visual-tests er miljøfølsomme — opt-in, ikke push-blokering.
Stabil browser-regression hører i nightly `shinytest2.yaml` CI-job.

CI-gate-hierarki: se `.github/workflows/README.md`.

### Analytics Privacy

Payload-kontrakt + opt-in + DPIA: `docs/ANALYTICS_PRIVACY.md`. Opdatér
`ANALYTICS_PRIVACY.md` og `SHINYLOGS_ALLOWLIST` synkront ved enhver ændring
af hvad der indsamles.

### Issue Tracking

Alle fejl/forbedringer dokumenteres som GitHub Issues. Reference i commits:
`fix: beskrivelse (fixes #123)`. Labels: `bug`, `enhancement`,
`documentation`, `technical-debt`, `performance`, `testing`.

### AI/LLM Integration (BFHllm)

biSPCharts er **thin wrapper** omkring BFHllm-pakken (v0.1.1, `Suggests +
Remotes`, ikke krævet for minimal-install).

**Lag:**
- `R/fct_ai_improvement_suggestions.R` — facade + input validering
- `R/utils_bfhllm_integration.R` — biSPCharts-config for BFHllm
- `BFHllm` package — RAG, LLM-calls, caching, prompts, knowledge base

**Public API (uændret for brugere):**

```r
suggestion <- generate_improvement_suggestion(
  spc_result = spc_result,
  context = list(data_definition = "...", chart_title = "...",
                 y_axis_unit = "dage", target_value = 30),
  session = session,  # required for caching
  max_chars = 350
)
```

**Graceful degradation:** BFHllm unavailable → NULL + log warning. RAG-fejl
→ fortsæt uden RAG. API-fejl → NULL via `safe_operation`.

**Konfiguration:** `inst/golem-config.yml` `ai:` + `rag:` sektion. Init via
`initialize_bfhllm(get_ai_config(), get_rag_config())` i `run_app.R`.

**Knowledge base:** Live i BFHllm-repo (`inst/spc_knowledge/`). Update-flow:
edit i BFHllm → rebuild ragnar store → bump biSPCharts DESCRIPTION
`BFHllm (>= ...)`.

**Reference:** BFHllm package docs (https://github.com/johanreventlow/BFHllm),
ADR-016, Issue #100.

### Danish Language

- **UI / fejlbeskeder / kommentarer:** dansk
- **Funktions- og variabelnavne:** engelsk

**Termer:** Serieplot = SPC chart · Centrallinje = Center line ·
Kontrolgrænser = Control limits.

---

## 📚 Global Standards Reference

**Følger:**
- R: `~/.claude/rules/R_STANDARDS.md`
- Shiny: `~/.claude/rules/SHINY_STANDARDS.md` +
  `~/.claude/rules/SHINY_ADVANCED_PATTERNS.md`
- Git: `~/.claude/rules/GIT_WORKFLOW.md`
- Philosophy: `~/.claude/rules/DEVELOPMENT_PHILOSOPHY.md`
- Architecture: `~/.claude/rules/ARCHITECTURE_PATTERNS.md`
- Troubleshooting: `~/.claude/rules/TROUBLESHOOTING_GUIDE.md`

**Globale agents:** tidyverse-code-reviewer, performance-optimizer,
security-reviewer, test-coverage-analyzer, refactoring-advisor,
legacy-code-detector, shiny-code-reviewer, architecture-validator.

**biSPCharts-specifik bidrag-guide:** `docs/CONTRIBUTING.md` (roxygen2-konvention,
brugervendt fejlbesked-pattern).
