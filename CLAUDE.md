# Claude Instructions – SPCify

@~/.claude/rules/CLAUDE_BOOTSTRAP_WORKFLOW.md

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

**SPCify bruger centraliseret event-bus:**

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
- Production: `library(SPCify)` (~50-100ms)
- Debug: `source('global.R')` med `options(spc.debug.source_loading = TRUE)` (~400ms+)

**Lazy loading:** Tunge moduler (file_operations, advanced_debug, performance_monitoring) loaded on demand

**Target:** Startup < 100ms (achieved: 55-57ms)

---

## 3) Critical Project Constraints

### External Package Ownership

✅ **KRITISK:** Maintainer har fuld kontrol over:

- **BFHcharts** – SPC chart rendering og visualisering
- **BFHtheme** – Hospital branding, themes og fonts
- **Ragnar** – RAG knowledge store, embedding, retrieval algorithms

❌ **ALDRIG implementer funktionalitet i SPCify som hører hjemme i BFHcharts, BFHtheme eller Ragnar**

✅ **I STEDET:**
1. Identificer manglende funktionalitet i ekstern pakke
2. Dokumentér behovet (issue, ADR, eller docs/)
3. Informér maintainer om feature request
4. Implementér midlertidig workaround i SPCify HVIS kritisk (marker tydeligt som temporary)
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

- SPCify: **Integration layer + business logic + knowledge curation**
- BFHcharts: **Visualization engine**
- BFHtheme: **Styling framework**
- Ragnar: **RAG knowledge store engine**

**SPCify's RAG responsibilities:**
- Knowledge content curation (`inst/spc_knowledge/`)
- Integration layer (`R/utils_ragnar_integration.R`)
- Application-specific query formulation
- Store build scripts (`data-raw/build_ragnar_store.R`)

### Do NOT Modify

- `brand.yml` uden godkendelse
- **NAMESPACE** uden explicit godkendelse (brug `devtools::document()`)
- Breaking changes uden major version bump

---

## 4) Cross-Repository Coordination

### BFHcharts + qicharts2 Hybrid Architecture

✅ **KRITISK:** SPCify bruger **permanent hybrid arkitektur**:

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

**Fix i SPCify hvis:**
- Parameter mapping (qicharts2 → BFHcharts)
- UI integration og Shiny reaktivitet
- Data preprocessing og validering
- Fejlbeskeder og dansk lokalisering
- SPCify-specifik caching

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
| `config_label_placement.R` | Intelligent label placement (collision avoidance) |
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
R -e "library(SPCify); testthat::test_dir('tests/testthat')"

# Specifik test
R -e "source('global.R'); testthat::test_file('tests/testthat/test-*.R')"

# Performance benchmark
R -e "microbenchmark::microbenchmark(package = library(SPCify), source = source('global.R'), times = 5)"

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

**Integration med SPCify workflow:**
1. Arkitektur verification før større refaktorering
2. Code review på tværs af moduler
3. Pattern detection for inconsistencies
4. Dependency analysis før nye features
5. Test coverage gaps identifikation

### AI/LLM Integration Patterns

**Architecture:**
- **Primary function:** `R/fct_ai_improvement_suggestions.R` - AI suggestion generation
- **RAG integration:** `R/utils_ragnar_integration.R` - Knowledge retrieval
- **Caching layer:** `R/utils_ai_cache.R` - Response caching to reduce API calls

**RAG-Enhanced vs Non-RAG Calls:**

```r
# RAG-enhanced (default for improvement suggestions)
suggestion <- generate_ai_improvement_suggestion(
  chart_data = data,
  spc_metadata = metadata,
  use_rag = TRUE  # Retrieves SPC knowledge context
)

# Non-RAG (fallback ved RAG fejl)
suggestion <- generate_ai_improvement_suggestion(
  chart_data = data,
  spc_metadata = metadata,
  use_rag = FALSE  # Kun chart data + metadata
)
```

**Caching Strategy:**
- **Cache key:** Baseret på chart data hash + metadata + RAG context
- **Cache location:** Session-based (in-memory reactiveValues)
- **Invalidation:** Automatic ved data updates (via events)
- **Benefits:** Reducerer API calls, forbedrer response time, sænker costs

**Graceful Degradation:**

1. **RAG query fejl** → Fortsæt uden RAG context, log warning
2. **API fejl** → Return informativ fejlbesked til bruger, log error
3. **Cache miss** → Normal API call (ikke en fejl)

**API Key Management:**

```r
# Runtime fallback pattern (implementeret i load_ragnar_store())
if (Sys.getenv("GEMINI_API_KEY") == "") {
  google_key <- Sys.getenv("GOOGLE_API_KEY")
  if (google_key != "") {
    Sys.setenv(GEMINI_API_KEY = google_key)
  }
}
```

- **Development:** `.Renviron` med `GOOGLE_API_KEY`
- **Production:** Miljøvariabel management (containerized deployment)
- **Fallback:** `GOOGLE_API_KEY` → `GEMINI_API_KEY` automatic

**Prompt Construction Best Practices:**

- **Structured context:** Chart type, metadata, Anhøj rules violations
- **RAG context injection:** Top-k most relevant SPC knowledge chunks
- **Language specification:** Dansk output explicit i prompt
- **Output format:** Markdown med konkrete, handlingsorienterede anbefalinger
- **Context window management:** Limit RAG chunks til top-5 for at undgå token overforbrug

**Files involved:**
- `R/fct_ai_improvement_suggestions.R` - Main AI logic
- `R/utils_ragnar_integration.R` - RAG integration
- `R/utils_ai_cache.R` - Cache implementation
- `inst/golem-config.yml` - RAG configuration
- `inst/spc_knowledge/` - Knowledge base content

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

## 7) RAG Integration Architecture

### Overview

SPCify bruger **Ragnar** (tidyverse RAG framework) til at forbedre AI-genererede forbedringsforslag med domæne-specifik SPC viden.

**System Flow:**
1. User anmoder om AI suggestion for SPC chart
2. RAG query retriever relevante SPC knowledge chunks fra Ragnar store
3. Retrieved context + chart data sendes til Gemini API
4. AI genererer domæne-informeret forbedringsforslag på dansk

### Architecture Components

**Knowledge Base:**
- **Location:** `inst/spc_knowledge/`
- **Format:** Markdown files med SPC metodologi, best practices, Anhøj rules forklaringer
- **Content:** SPC fundamentals, chart interpretation, special cause patterns

**Ragnar Store:**
- **Build script:** `data-raw/build_ragnar_store.R`
- **Store location (dev):** `inst/ragnar_store/`
- **Store location (prod):** Installed package path
- **Embedding provider:** Gemini API (via `GOOGLE_API_KEY`)
- **Search methods:** Semantic (embeddings) + BM25 (keyword)
- **Chunks:** Markdown-based chunking med target size

**Integration Layer:**
- **Main file:** `R/utils_ragnar_integration.R`
- **Key functions:**
  - `load_ragnar_store()` - Loader store med API key fallback
  - `query_spc_knowledge()` - Retriever relevante chunks
  - `format_rag_context()` - Formatter context til prompt

**AI Suggestion Flow:**
- **Main file:** `R/fct_ai_improvement_suggestions.R`
- **Integration point:** RAG query før Gemini API call
- **Fallback:** Graceful degradation ved RAG fejl (fortsæt uden RAG context)

### Build Process

**Knowledge Store Build:**

```r
# Kør fra project root
source("data-raw/build_ragnar_store.R")
```

**Build steps:**
1. Initialize Ragnar store med Gemini embeddings
2. Read markdown files fra `inst/spc_knowledge/`
3. Chunk documents (markdown-aware)
4. Generate embeddings via Gemini API
5. Build BM25 search index
6. Persist store til `inst/ragnar_store/`

**Verification:**

```r
# Manual verification
Rscript tests/manual/verify_rag.R
```

### Development vs Production Mode

**Development Mode Detection:**

```r
# SPCify ikke installeret → development mode
ragnar_store_path <- system.file("ragnar_store", package = "SPCify")
if (ragnar_store_path == "") {
  ragnar_store_path <- "inst/ragnar_store"  # Project root
}
```

**Development:**
- Store path: `inst/ragnar_store/` (relative til project root)
- API key: `.Renviron` med `GOOGLE_API_KEY`
- Rebuild: Manual via `data-raw/build_ragnar_store.R`

**Production:**
- Store path: Installed package `system.file("ragnar_store", package = "SPCify")`
- API key: Environment variable (container/deployment config)
- Rebuild: Package reinstall med updated knowledge base

### Configuration

**Golem Config (`inst/golem-config.yml`):**

```yaml
default:
  rag:
    enabled: TRUE
    top_k: 5
    min_similarity: 0.3

test:
  rag:
    enabled: FALSE  # Skip RAG i automated tests
```

**API Keys:**
- `GOOGLE_API_KEY` - Primary (bruges til både embeddings og generation)
- `GEMINI_API_KEY` - Auto-populated som fallback fra `GOOGLE_API_KEY`

### Modification Guidelines

**When to Modify Knowledge Base:**
- Nye SPC metodologier eller best practices
- Opdaterede Anhøj rules fortolkninger
- Feedback fra klinikere om manglende viden
- Fejlagtige eller outdated information

**Update Process:**
1. Edit markdown files i `inst/spc_knowledge/`
2. Rebuild Ragnar store: `source("data-raw/build_ragnar_store.R")`
3. Verify via `Rscript tests/manual/verify_rag.R`
4. Test AI suggestions med updated knowledge
5. Commit både markdown source OG rebuilt store

**When to Modify Integration Layer:**
- Ændringer i RAG query strategi (top-k, similarity threshold)
- Nye prompt engineering patterns
- Performance optimization (caching, batching)
- Graceful degradation improvements

**When NOT to Modify (Escalate to Ragnar):**
- Embedding generation algorithms
- Vector search/retrieval algorithms
- BM25 implementation
- Store persistence format
- Chunking algorithms (se External Package Ownership)

### Performance Considerations

**Embedding Generation:**
- **Cost:** Gemini API call per chunk (one-time ved store build)
- **Time:** ~1-2s per document (afhængig af size)
- **Optimization:** Batch builds, incremental updates

**Query Performance:**
- **Retrieval:** <100ms for semantic + BM25 search
- **Caching:** Session-based cache for identical queries
- **Top-k limit:** Default 5 chunks (balance mellem context quality og token usage)

**API Usage:**
- **Store build:** One-time embedding cost (rebuild kun ved knowledge updates)
- **Query time:** Kun Gemini generation call (embeddings reused fra store)
- **Caching:** Reduces repeated API calls for samme chart data

### Testing Strategy

**Automated Tests:**
- `tests/testthat/test-utils_ragnar_integration.R` - Integration layer logic
- `tests/testthat/test-fct_ai_improvement_suggestions.R` - AI suggestion flow med RAG
- Mocked Ragnar calls (no API dependency)

**Manual Tests:**
- `tests/manual/verify_rag.R` - End-to-end RAG verification
- Requires: API key, internet, Ragnar store built
- Use case: Pre-deployment verification

**Coverage:**
- Integration layer: 100% (critical path)
- Fallback scenarios: Required (RAG fejl, API fejl)
- Cache invalidation: Verified via events

### Troubleshooting

**Common Issues:**

1. **"Ragnar store not found"**
   - Check `inst/ragnar_store/` exists
   - Run `source("data-raw/build_ragnar_store.R")`
   - Verify development mode detection

2. **"API key not configured"**
   - Add `GOOGLE_API_KEY` til `.Renviron`
   - Restart R session
   - Check `Sys.getenv("GOOGLE_API_KEY")`

3. **"No results from RAG query"**
   - Check query formulation
   - Verify store built successfully
   - Check `min_similarity` threshold i config

4. **"Poor suggestion quality"**
   - Review RAG context chunks (are they relevant?)
   - Check `top_k` setting (more/fewer chunks?)
   - Update knowledge base content
   - Rebuild store

**Debug Logging:**

```r
# Enable RAG debug logs
options(spc.log.level = "debug")

# Check RAG context in logs
# [RAG] - Context retrieval and formatting
```

### Related Documentation

- **README.md** - RAG verification guide
- **MCP Context** - Recent RAG implementation sessions
- **Issues:** #82, #83, #87, #79 - Original RAG epic implementation

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
