<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Claude Instructions – biSPCharts

**Bootstrap workflow:**

- Mac: `@~/.claude/rules/CLAUDE_BOOTSTRAP_WORKFLOW.md`
- Windows: `@C:/Users/jrev0004/.claude/rules/CLAUDE_BOOTSTRAP_WORKFLOW.md`

---

## ⚠️ OBLIGATORISKE REGLER (KRITISK)

❌ **ALDRIG:**
1. Merge til master/main uden eksplicit godkendelse
2. Push til remote uden anmodning
3. Tilføj Claude attribution footers:
   - ❌ "🤖 Generated with [Claude Code]"
   - ❌ "Co-Authored-By: Claude <noreply@anthropic.com>"

---

## 1) Project Overview

- **Project Type:** Shiny Application
- **Purpose:** Statistical Process Control (SPC) applikation til klinisk kvalitetsarbejde ved Bispebjerg og Frederiksberg Hospital. Krav om stabilitet, forståelighed og dansk sprog.
- **Status:** Production (Industristandard mønstre med TDD, centraliseret state management, robust error handling)

**Technology Stack:**
- Shiny (Golem framework)
- BFHcharts (SPC visualization engine)
- BFHtheme (Hospital branding)
- qicharts2 (Anhøj rules beregning)
- Ragnar (RAG knowledge store for AI context enhancement)
- Gemini API (LLM provider for AI improvement suggestions)

---

## 2) Project-Specific Architecture

### Unified Event Architecture

**biSPCharts bruger centraliseret event-bus:**

```r
# Events defineres i global.R
app_state$events <- reactiveValues(
  data_updated = 0L,
  auto_detection_completed = 0L,
  ui_sync_requested = 0L,
  ...
)

# Emit API
emit$data_updated(context = "upload")
emit$auto_detection_completed()

# Lyttere med prioritet
observeEvent(app_state$events$data_updated,
  ignoreInit = TRUE,
  priority = OBSERVER_PRIORITIES$HIGH, {
  handle_data_update()
})
```

**Event Infrastructure:**
- Events: `global.R` (`app_state$events`)
- Emit functions: `create_emit_api()`
- Listeners: `R/utils_event_system.R` via `setup_event_listeners()`

### App State Structure

**Hierarchisk state (se `R/state_management.R`):**

```r
app_state$events         # Event triggers
app_state$data           # current_data, original_data, file_info
app_state$columns        # Hierarkisk: auto_detect, mappings, ui_sync
app_state$session        # Session state
```

**Detaljeret schema:** Se Appendix i original CLAUDE.md.backup

### Golem Configuration

**Environment-specific settings:**

```r
# Læsning
config_value <- golem::get_golem_options("test_mode_auto_load", default = FALSE)

# Initialisering
Sys.setenv(GOLEM_CONFIG_ACTIVE = "dev")  # dev/test/prod
```

**Standard environments:**
- **DEV:** `test_mode_auto_load = TRUE`, `logging.level = "debug"`
- **TEST:** `test_mode_auto_load = TRUE`, `logging.level = "info"`
- **PROD:** `test_mode_auto_load = FALSE`, `logging.level = "warn"`

### Performance Architecture

**Boot strategy:**
- Production: `library(biSPCharts)` (~50-100ms)
- Debug: `source('global.R')` med `options(spc.debug.source_loading = TRUE)` (~400ms+)

**Lazy loading:** Tunge moduler (file_operations, advanced_debug, performance_monitoring) loaded on demand

**Target:** Startup < 100ms (achieved: 55-57ms)

### Session Persistence (Issue #193)

**Auto-save flow:**
- Data ændringer debounced 2s → `autoSaveAppState()` → `saveDataLocally()` → `session$sendCustomMessage("saveAppState", …)` → JS handler → `localStorage`
- Settings ændringer debounced 1s via `bindEvent()` på form-felter
- Feature flag: `get_auto_save_enabled()` (default TRUE)

**Auto-restore flow:**
- JS `$(document).on('shiny:sessioninitialized', ...)` → `Shiny.setInputValue('auto_restore_data', …)` → `observeEvent(input$auto_restore_data, …, once = TRUE)`
- Rækkefølge: version-check → guards → `restore_metadata()` → reconstruct data.frame med class preservation → emit `data_updated(context = "session_restore")`
- Feature flag: `get_auto_restore_enabled()` (prod=TRUE, dev/test=FALSE)

**Class preservation:**
- `extract_class_info()` gemmer per-kolonne metadata (primary, is_date, is_posixct, is_factor, levels, tz)
- `restore_column_class()` rekonstruerer præcis R-type
- Understøtter: `numeric`, `integer`, `character`, `logical`, `Date`, `POSIXct` med tz, `factor` med levels

**Fejl-håndtering:**
- JS rapporterer success/failure tilbage via `input$local_storage_save_result`
- R observer deaktiverer auto-save ved quota-fejl og viser dansk notifikation
- `last_save_time` opdateres KUN ved bekræftet success

**Schema version:** `LOCAL_STORAGE_SCHEMA_VERSION = "2.0"` — ved mismatch ryddes localStorage lydløst.

**Relevante filer:**
- `R/utils_local_storage.R` — `saveDataLocally`, `autoSaveAppState`, class helpers
- `R/utils_server_server_management.R` — auto-restore observer + `clear_saved`
- `R/utils_server_session_helpers.R` — auto-save triggers + save-status display
- `inst/app/www/local-storage.js` — localStorage wrapper (IKKE `JSON.stringify`)
- `inst/app/www/shiny-handlers.js` — custom message handlers + auto-restore trigger
- `inst/golem-config.yml` — `session:` sektion

---

## 3) Critical Project Constraints

### External Package Ownership

✅ **KRITISK:** Maintainer har fuld kontrol over:

- **BFHcharts** – SPC chart rendering og visualisering
- **BFHtheme** – Hospital branding, themes og fonts
- **Ragnar** – RAG knowledge store, embedding, retrieval algorithms

❌ **ALDRIG implementer funktionalitet i biSPCharts som hører hjemme i BFHcharts, BFHtheme eller Ragnar**

✅ **I STEDET:**
1. Identificer manglende funktionalitet i ekstern pakke
2. Dokumentér behovet (issue, ADR, eller docs/)
3. Informér maintainer om feature request
4. Implementér midlertidig workaround i biSPCharts HVIS kritisk (marker tydeligt som temporary)
5. Fjern workaround når funktionalitet er tilgængelig i ekstern pakke

**Eksempler:**
- Target line rendering → BFHcharts ansvar
- Font fallback logic → BFHtheme ansvar
- Hospital branding colors → BFHtheme ansvar
- Chart styling defaults → BFHcharts ansvar
- Embedding generation → Ragnar ansvar
- BM25 search algorithms → Ragnar ansvar
- Vector store operations → Ragnar ansvar
- Chunking strategies → Ragnar ansvar

### Integration Pattern

- biSPCharts: **Integration layer + business logic + knowledge curation**
- BFHcharts: **Visualization engine**
- BFHtheme: **Styling framework**
- Ragnar: **RAG knowledge store engine**

**biSPCharts's RAG responsibilities:**
- Knowledge content curation (`inst/spc_knowledge/`)
- Integration layer (`R/utils_ragnar_integration.R`)
- Application-specific query formulation
- Store build scripts (`data-raw/build_ragnar_store.R`)

### Do NOT Modify

- `brand.yml` uden godkendelse
- **NAMESPACE** uden explicit godkendelse (brug `devtools::document()`)
- Breaking changes uden major version bump

### Versioning

biSPCharts og sibling-pakker (BFHcharts, BFHllm, BFHtheme) følger
`~/.claude/rules/VERSIONING_POLICY.md`:
- Strict semver (`vX.Y.Z`-tags), pre-1.0 tillader breaking i MINOR
- NEWS.md på dansk efter standard template
- Lower-bound deps (`BFHcharts (>= X.Y.Z)`), ingen øvre grænse
- Pre-release checklist (9 trin) køres før hver tag/push
- Cross-repo bump: separat `chore(deps):`-PR efter sibling-release

---

## 4) Cross-Repository Coordination

### BFHcharts + qicharts2 Hybrid Architecture

✅ **KRITISK:** biSPCharts bruger **permanent hybrid arkitektur**:

| Komponent | Ansvar | Package | Rationale |
|-----------|--------|---------|-----------|
| **SPC Plotting** | Chart rendering, visual theming | BFHcharts | Modern ggplot2 med BFH branding |
| **Anhøj Rules** | Serielængde, antal kryds, special cause detection | qicharts2 | Valideret, klinisk accepteret |

**Implementation:**

```r
# BFHcharts: Primary plotting
plot <- BFHcharts::create_spc_chart(data, x, y, chart_type, notes_column, ...)

# qicharts2: Anhøj rules metadata (UI value boxes)
qic_result <- qicharts2::qic(x, y, chart = chart_type, return.data = TRUE)
anhoej_metadata <- extract_anhoej_metadata(qic_result)
```

**Constraints:**

❌ **qicharts2 KUN til:** Anhøj rules, metadata extraction
✅ **BFHcharts til:** Plot rendering, chart types, theming, notes, target lines, freezing

**Files involved:**
- `R/fct_spc_bfh_service.R` - BFHcharts service + qicharts2 Anhøj rules
- `R/utils_qic_preparation.R` - qicharts2 input prep
- `R/utils_qic_caching.R` - Anhøj rules caching
- `R/utils_qic_debug_logging.R` - qicharts2 debug logging

### Coordination Workflow

**Primær guide:** `docs/CROSS_REPO_COORDINATION.md`

**Quick references:**
- `.claude/ISSUE_ESCALATION_DECISION_TREE.md` - Beslutningsdiagram
- `.github/ISSUE_TEMPLATE/bfhchart-feature-request.md` - Issue template

**Eskalér til BFHcharts hvis:**
- Core chart rendering bugs
- Statistiske beregningsfejl
- Manglende chart types eller features
- BFHcharts API design limitations
- Performance issues i BFHcharts algoritmer

**Fix i biSPCharts hvis:**
- Parameter mapping (qicharts2 → BFHcharts)
- UI integration og Shiny reaktivitet
- Data preprocessing og validering
- Fejlbeskeder og dansk lokalisering
- biSPCharts-specifik caching

---

## 5) Project-Specific Configuration

### Configuration Files Overview

| Fil | Ansvar |
|-----|--------|
| `config_branding_getters.R` | Hospital branding (navn, logo, theme, farver) |
| `config_chart_types.R` | SPC chart type definitions (DA→EN mappings) |
| `config_observer_priorities.R` | Observer priorities (race condition prevention) |
| `config_spc_config.R` | SPC-specifikke konstanter (validation, colors) |
| `config_log_contexts.R` | Centraliserede log context strings (inkl. RAG contexts) |
| `config_system_config.R` | System constants (performance, timeouts, cache) |
| `config_ui.R` | UI layout (widths, heights, font scaling) |
| `inst/golem-config.yml` | Environment-based config (dev/prod/test, RAG settings) |
| `.Renviron` | API keys og environment variables (GOOGLE_API_KEY, GEMINI_API_KEY) |

**Detaljeret guide:** `docs/CONFIGURATION.md`

**RAG Configuration:**
- `inst/golem-config.yml` indeholder `rag:` section med RAG-specifikke settings
- `.Renviron` skal indeholde `GOOGLE_API_KEY` (bruges automatisk som fallback til `GEMINI_API_KEY`)
- Development mode: RAG store loading fra project root
- Production mode: RAG store loading fra installed package

### Test Commands

```r
# Alle tests
R -e "library(biSPCharts); testthat::test_dir('tests/testthat')"

# Specifik test
R -e "source('global.R'); testthat::test_file('tests/testthat/test-*.R')"

# Performance benchmark
R -e "microbenchmark::microbenchmark(package = library(biSPCharts), source = source('global.R'), times = 5)"

# Manual verification scripts (for external integrations)
Rscript tests/manual/verify_rag.R
```

**Manual Tests:**
Manual tests bruges til scenarios hvor automatiseret testing ikke er praktisk:
- **External API integrations** (Gemini API) - Kræver API keys og internet
- **Development-only verification** - Interactive debugging og RAG store validation
- **Cost-sensitive operations** - Undgå API costs i CI/CD pipeline

Manual tests køres IKKE automatisk i CI/CD. De bruges under development og før production deployment.

**Coverage targets:**
- 100% kritiske paths (data load, plot generation, state sync)
- ≥90% samlet coverage
- Edge cases (null, tomme datasæt, fejl, store filer)

---

## 6) Domain-Specific Guidance

### Git Hooks (pre-push gate)

**Installation:** `Rscript dev/install_git_hooks.R` — installerer symlink `.git/hooks/pre-push → dev/git-hooks/pre-push`.

**Formål:** Blokér push til remote hvis lintr fejler eller test-suiten er rød (§3.1 af `harden-test-suite-regression-gate` openspec change).

**Anvendelse:**
```bash
# Normal push (udløser hooken)
git push

# Hurtig pre-push (kun lintr + udvalgte unit-tests, ~2 min)
PREPUSH_MODE=fast git push

# Bypass (brug sparsomt, fx når #239-paraply blokerer)
SKIP_PREPUSH=1 git push
git push --no-verify        # Git-native alternativ
```

⚠️ **VIGTIG:** Pre-push-hooken vil blokere push indtil paraply-issue #239 er lukket (suite har 43 fails + 21 errors pre-existing). Brug `SKIP_PREPUSH=1` midlertidigt.

**Rprofile-advarsel:** Interaktive R-sessioner i dette repo logger advarsel hvis pre-push ikke er installeret. Ignoreres i Rscript/CI.

### Issue Tracking (GitHub Issues)

✅ **OBLIGATORISK:** Alle fejl, rettelser, todo-emner og forbedringsforslag dokumenteres som GitHub Issues.

```bash
gh issue create --title "Beskrivelse" --body "Details"
git commit -m "fix: beskrivelse (fixes #123)"
```

**Labels:** `bug`, `enhancement`, `documentation`, `technical-debt`, `performance`, `testing`

### Gemini CLI for Large Codebase Analysis

**Brug `gemini -p` når:**
- Analysere hele Shiny-kodebase på tværs af mange filer
- Forstå sammenhæng mellem moduler, reaktive kæder
- Finde duplikerede mønstre eller anti-patterns
- Verificere arkitektur på tværs af hele projektet

**Eksempler:**

```bash
# Arkitektur verification
gemini -p "@R/ Analyze current state management patterns and identify areas for centralization"

# Test coverage check
gemini -p "@tests/ @R/ Are all critical paths covered by tests?"
```

**Integration med biSPCharts workflow:**
1. Arkitektur verification før større refaktorering
2. Code review på tværs af moduler
3. Pattern detection for inconsistencies
4. Dependency analysis før nye features
5. Test coverage gaps identifikation

### AI/LLM Integration Patterns (BFHllm Package)

**Architecture (efter BFHllm migration):**
- **biSPCharts facade:** `R/fct_ai_improvement_suggestions.R` - Thin wrapper
- **Integration layer:** `R/utils_bfhllm_integration.R` - biSPCharts-specific config
- **Core AI logic:** Delegeret til `BFHllm` package (v0.1.0+)

**biSPCharts API (unchanged for users):**

```r
# Generate AI improvement suggestion
suggestion <- generate_improvement_suggestion(
  spc_result = spc_result,  # BFHcharts result object
  context = list(
    data_definition = "Ventetid til operation",
    chart_title = "Ventetid 2024",
    y_axis_unit = "dage",
    target_value = 30
  ),
  session = session,        # Shiny session (required for caching)
  max_chars = 350
)
```

**BFHllm Integration:**

```r
# biSPCharts initialization (global.R eller run_app.R)
initialize_bfhllm(
  ai_config = get_ai_config(),
  rag_config = get_rag_config()
)

# Check availability
if (is_bfhllm_available()) {
  # BFHllm is configured and ready
}

# Direct BFHllm usage (advanced)
library(BFHllm)
BFHllm::bfhllm_spc_suggestion(
  spc_result = spc_result,
  context = context,
  max_chars = 350,
  use_rag = TRUE,
  cache = BFHllm::bfhllm_cache_shiny(session)
)
```

**Graceful Degradation:**

1. **BFHllm unavailable** → Suggestion returns NULL, log warning
2. **RAG query fejl** → BFHllm fortsætter uden RAG context
3. **API fejl** → Return NULL, log error via `safe_operation`
4. **Cache miss** → Normal API call via BFHllm

**API Key Management:**

- **Development:** `.Renviron` med `GOOGLE_API_KEY` eller `GEMINI_API_KEY`
- **Production:** Environment variables (container deployment)
- **Fallback:** BFHllm handles `GOOGLE_API_KEY` → `GEMINI_API_KEY` fallback

**Configuration:**

```yaml
# inst/golem-config.yml
default:
  ai:
    model: "gemini-2.0-flash-exp"
    timeout_seconds: 10
    max_response_chars: 350
  rag:
    enabled: TRUE
    top_k: 5
    min_similarity: 0.3
```

**Files involved:**
- `R/fct_ai_improvement_suggestions.R` - biSPCharts facade (thin wrapper)
- `R/utils_bfhllm_integration.R` - Integration layer
- `inst/golem-config.yml` - AI/RAG configuration
- **BFHllm package:** Core AI logic, RAG, caching, prompts, knowledge base

**See Also:** BFHllm package documentation for advanced usage, RAG configuration, and knowledge base management

### Danish Language

- **UI text:** Dansk
- **Error messages:** Dansk, brugervenlige
- **Code:** Engelsk (funktionsnavne, variabler)
- **Comments:** Dansk

**Key terms:**
- Serieplot = SPC chart
- Centrallinje = Center line
- Kontrolgrænser = Control limits

---

## 7) AI/LLM Integration via BFHllm Package

### Overview (Post-Migration)

**VIGTIGT:** Efter Issue #100 (Phase 2) er al AI/LLM funktionalitet migreret til **BFHllm** package (v0.1.0+). biSPCharts delegerer nu til BFHllm for RAG, LLM calls, caching, og prompt building.

**System Flow:**
1. User anmoder om AI suggestion via biSPCharts UI
2. biSPCharts kalder `generate_improvement_suggestion()` (thin wrapper)
3. Wrapper delegerer til `BFHllm::bfhllm_spc_suggestion()`
4. BFHllm performer RAG query, prompt building, LLM call, caching
5. AI suggestion returneres til biSPCharts og vises i UI

### biSPCharts Integration Layer

**Files i biSPCharts:**
- `R/fct_ai_improvement_suggestions.R` - Thin facade, input validation
- `R/utils_bfhllm_integration.R` - biSPCharts-specific BFHllm configuration
- `inst/golem-config.yml` - AI/RAG configuration settings

**BFHllm Package Responsibilities:**
- RAG knowledge store management (`inst/spc_knowledge/`, `inst/ragnar_store/`)
- Ragnar integration (`bfhllm_query_knowledge`, `bfhllm_load_knowledge_store`)
- LLM provider abstraction (`bfhllm_chat`, `bfhllm_configure`)
- Prompt templates og building (`bfhllm_build_prompt`, `bfhllm_create_structured_prompt`)
- Session-scoped caching (`bfhllm_cache_shiny`)
- SPC-specific suggestion logic (`bfhllm_spc_suggestion`, `bfhllm_extract_spc_metadata`)

### Configuration

**biSPCharts Configuration (`inst/golem-config.yml`):**

```yaml
default:
  ai:
    model: "gemini-2.0-flash-exp"
    timeout_seconds: 10
    max_response_chars: 350
  rag:
    enabled: TRUE
    top_k: 5
    min_similarity: 0.3
```

**Initialization (global.R eller run_app.R):**

```r
# Configure BFHllm with biSPCharts settings
initialize_bfhllm(
  ai_config = get_ai_config(),
  rag_config = get_rag_config()
)
```

### API Key Management

- **Development:** `.Renviron` med `GOOGLE_API_KEY` eller `GEMINI_API_KEY`
- **Production:** Environment variables via deployment config
- **Fallback:** BFHllm automatically uses `GOOGLE_API_KEY` → `GEMINI_API_KEY`

### Knowledge Base Management

**Location:** Knowledge base er nu i **BFHllm package**

**Update Process:**
1. Clone BFHllm repository: `git clone https://github.com/johanreventlow/BFHllm`
2. Edit markdown files: `inst/spc_knowledge/*.md`
3. Rebuild Ragnar store: `source("data-raw/build_ragnar_store.R")`
4. Test locally: `devtools::install("path/to/BFHllm")`
5. Commit og push til BFHllm repo
6. Update biSPCharts DESCRIPTION: `BFHllm (>= new_version)`

**Benefits of Extraction:**
- Single source of truth for SPC knowledge
- Independent versioning og updates
- Reusable across multiple R packages
- Reduced biSPCharts maintenance burden

### Testing

**biSPCharts Tests:**
- `tests/testthat/test-fct_ai_improvement_suggestions.R` - Facade behavior (delegation, validation)
- Mocked BFHllm calls (no API dependency)

**BFHllm Tests:**
- Se BFHllm package documentation for RAG, caching, og LLM integration tests

**Manual Verification:**
1. Install BFHllm: `devtools::install_github("johanreventlow/BFHllm")`
2. Verify biSPCharts integration: `devtools::load_all()` i biSPCharts project
3. Test AI suggestions via Shiny app

### Troubleshooting

**Common Issues:**

1. **"BFHllm package not found"**
   - Install BFHllm: `devtools::install_github("johanreventlow/BFHllm")`
   - Check DESCRIPTION: `BFHllm (>= 0.1.0)` listed in Imports

2. **"AI suggestions return NULL"**
   - Check `is_bfhllm_available()` returns TRUE
   - Verify API key: `Sys.getenv("GOOGLE_API_KEY")` or `Sys.getenv("GEMINI_API_KEY")`
   - Check logs for BFHllm errors

3. **"RAG not working"**
   - Verify BFHllm ragnar store built: Check BFHllm package installation
   - Check RAG enabled: `get_rag_config()$enabled == TRUE`
   - See BFHllm troubleshooting documentation

**Debug Logging:**

```r
# Enable debug logs
options(spc.log.level = "debug")

# Check for AI_SUGGESTION context logs
# [AI_SUGGESTION] - biSPCharts wrapper behavior
# [BFHllm] - See BFHllm package logs (if enabled)
```

### Related Documentation

- **BFHllm Package:** `https://github.com/johanreventlow/BFHllm` - Full RAG/LLM documentation
- **NEWS.md:** Migration notes for Issue #100 (Phase 2)
- **Issues:** #100 - BFHllm extraction tracking issue

---

## 📚 Global Standards Reference

**Dette projekt følger:**
- **R Development:** `~/.claude/rules/R_STANDARDS.md`
- **Shiny Development:** `~/.claude/rules/SHINY_STANDARDS.md`
- **Shiny Advanced Patterns:** `~/.claude/rules/SHINY_ADVANCED_PATTERNS.md`
- **Git Workflow:** `~/.claude/rules/GIT_WORKFLOW.md`
- **Development Philosophy:** `~/.claude/rules/DEVELOPMENT_PHILOSOPHY.md`
- **Architecture Patterns:** `~/.claude/rules/ARCHITECTURE_PATTERNS.md`
- **Troubleshooting:** `~/.claude/rules/TROUBLESHOOTING_GUIDE.md`

**Globale agents:** tidyverse-code-reviewer, performance-optimizer, security-reviewer, test-coverage-analyzer, refactoring-advisor, legacy-code-detector, shiny-code-reviewer, architecture-validator

**Globale commands:** /boost, /code-review-recent, /double-check, /debugger

---

**Original documentation:** Se `CLAUDE.md.backup` for fuld dokumentation af alle patterns, appendices og detaljeret arkitektur.
