# SPC App - Statistical Process Control i R Shiny

En professionel Shiny applikation til **Statistical Process Control (SPC)** analyser med dansk interface og integration med qicharts2. Udviklet til klinisk kvalitetsarbejde med fokus på stabilitet, brugervenlighed og danske standarder.

## 🔧 Features

### Core Funktionalitet
- **SPC Charts**: I-kort, MR-kort, P-kort, U-kort med automatisk beregning af kontrolgrænser
- **Auto-detektion**: Intelligent kolonne matching baseret på navne og data karakteristika
- **Dansk Support**: Komplet understøttelse af danske karakterer, dato formater og CSV standarder
- **Excel/CSV Import**: Robust file håndtering med metadata preservation
- **Interactive UI**: Moderne Bootstrap interface med real-time feedback

### AI-Assisteret Forbedringsmål

biSPCharts kan generere kontekst-bevidste forbedringsmål automatisk ved hjælp af Google Gemini AI.

**Features:**
- Genererer konkrete, handlingsorienterede forslag på dansk (max 350 tegn)
- Baseret på SPC-analyse (signaler, serielængde, målforhold)
- Caching for hurtig respons (samme data → samme forslag)
- Fejltolerant: AI-fejl crasher ikke appen
- Fuldt editerbar output for brugertilpasning

**Setup:**

1. **Få en Google API-nøgle:**
   - Gå til https://makersuite.google.com/app/apikey
   - Opret en ny API-nøgle
   - Kopier nøglen

2. **Konfigurer environment variable:**
   - Rediger `.Renviron` fil (brug `usethis::edit_r_environ()`)
   - Tilføj: `GOOGLE_API_KEY=your_actual_api_key_here`
   - Genstart R session

3. **Verificer setup:**
   ```r
   Sys.getenv("GOOGLE_API_KEY")  # Should return your key
   library(biSPCharts)
   # AI button should be enabled in export panel
   ```

**Usage:**

1. Upload data og generér SPC-graf
2. Udfyld metadata i export-panel (datadefinition, titel, enhed)
3. Klik "✨ Generér forslag med AI"
4. Vent ~5-10 sekunder (første gang), derefter instant (cache)
5. Redigér forslaget efter behov

**Costs & Limits:**

- **Model:** Gemini 2.0 Flash (gratis tier: 1500 requests/dag)
- **Expected usage:** < 100 requests/dag per bruger
- **Cache hit rate:** 70%+ (reducerer API calls)
- **Cost:** Gratis for typisk brug

**Troubleshooting:**

*Problem:* "AI button er deaktiveret"
- *Løsning:* Generér først en SPC-graf. Knappen aktiveres kun når data er tilgængelig.

*Problem:* "AI-funktionalitet kræver Google API-nøgle"
- *Løsning:* Sæt `GOOGLE_API_KEY` i `.Renviron` (se setup ovenfor)

*Problem:* "Appen hænger i 30-60 sekunder når AI-knappen klikkes"
- *Årsag:* Manglende eller ustabil internetforbindelse. AI-funktionen kræver aktiv internet.
- *Løsning:*
  - Tjek internetforbindelse (ping google.com)
  - Prøv igen når forbindelsen er stabil
  - Alternativt: Skriv forbedringsmålet manuelt
- *Note:* Dette er en kendt limitation i upstream HTTP-klient. Timeout forbedringer er under udvikling.

*Problem:* "For mange forespørgsler"
- *Løsning:* Vent 1 minut og prøv igen. Rate limit er midlertidig.

**Known Limitations:**

- **Network Timeout:** Ved ustabil/manglende internet kan AI-knappen hænge i 30-60 sekunder før timeout. Dette er en upstream limitation i ellmer HTTP-klient. Sørg for stabil forbindelse før brug.
- **Rate Limits:** Gemini free tier har 1500 requests/dag. Ved overskridelse, vent til næste dag.
- **Response Quality:** AI-forslag er vejledende og skal altid reviewes før brug.

**Privacy:**

- Kun aggregerede SPC-statistikker sendes til Gemini (ingen rådata)
- Ingen patient-identifikation sendes
- Data bruges ikke til model-træning (per Google Gemini API policy)
- Se `docs/adr/ADR-016-gemini-integration.md` for detaljer

**RAG Knowledge Base:**

biSPCharts bruger RAG (Retrieval-Augmented Generation) med Ragnar-pakken til at grunde AI-forslag i autoritativ SPC-metodologi:

- **Knowledge base:** 3 markdown dokumenter med SPC fundamentals, Anhøj rules, og interpretation guidance
- **Source:** Jacob Anhøj's "SPC for Healthcare" (https://anhoej.github.io/spc4hc/)
- **Build:** Knowledge store bygges automatisk ved package installation (kræver `GOOGLE_API_KEY`)
- **Fallback:** AI fungerer uden RAG hvis build fejler (bruger base prompt)

*Manuel build (hvis nødvendigt):*
```r
# Ensure GOOGLE_API_KEY is set
Sys.getenv("GOOGLE_API_KEY")

# Run build script
source("data-raw/build_ragnar_store.R")

# Verify store created
dir.exists("inst/ragnar_store")
```

**RAG Configuration:**

RAG kan konfigureres via `inst/golem-config.yml`:

```yaml
ai:
  rag:
    enabled: true              # Enable/disable RAG
    n_results: 3               # Antal knowledge chunks at hente (1-10)
    method: "hybrid"           # Search method: "hybrid", "vector", "keyword"
```

**Environment-specific settings:**
- **Development/Production:** RAG enabled (grounded AI responses)
- **Testing:** RAG disabled (brug mocks for deterministic tests)

**Performance tuning:**
- `n_results: 3` er optimal balance (mere → bedre context, men langsommere)
- `method: "hybrid"` kombinerer semantisk + keyword matching (anbefales)

Se `docs/CONFIGURATION.md` for detaljeret RAG setup og troubleshooting.

**Verificer RAG Virker:**

```r
# Kør verifikationsscript
source("tests/manual/verify_rag.R")

# Forventet output når RAG virker:
# ✓ RAG enabled: TRUE
# ✓ Ragnar store found at: inst/ragnar_store
# ✓ Successfully connected to Ragnar store
# ✓ Knowledge retrieved successfully
# Chunks retrieved: 2
# Context length: 4296 characters
```

**Ved problemer:**
- Store ikke fundet → Kør `source("data-raw/build_ragnar_store.R")`
- BM25 fejl → Store mangler index, rebuild med updated script
- API key fejl → Sæt `GOOGLE_API_KEY` i `.Renviron`

### Tekniske Highlights
- **Modular Architecture**: Clean separation med event-driven design patterns
- **Environment-Aware Config**: Development/production/testing specific behavior
- **Centraliseret State Management**: Unified app_state med reactive event bus
- **Test-Driven Development**: >95% test coverage med comprehensive integration tests
- **Golem-Style Patterns**: Standard R package structure med best practices
- **Robust Error Handling**: Graceful degradation og centralized logging
- **Performance Optimized**: Debounced operations, caching og memory management
- **Danish Locale**: ISO-8859-1 encoding, komma decimal separator, danske labels
- **AI Integration**: Google Gemini for automated improvement suggestions

## 🚀 Quick Start

### Prerequisites
```r
# Required R packages (automatically managed via DESCRIPTION)
install.packages(c(
  "shiny", "bslib", "dplyr", "readr", "readxl",
  "qicharts2", "ggplot2", "ggrepel", "scales",
  "shinyjs", "excelR", "zoo", "lubridate",
  "openxlsx", "yaml", "shinylogs", "later"
))
```

### Start Application

```r
# Clone repository
git clone <repository-url>
cd biSPCharts

# ═══════════════════════════════════════════════════════
# PRODUCTION MODE (Anbefalet) - Package loading
# ═══════════════════════════════════════════════════════

# Standard production start (~50-100ms startup)
R -e "library(biSPCharts); biSPCharts::run_app()"

# Custom port
R -e "library(biSPCharts); biSPCharts::run_app(port = 3838)"

# Development mode med enhanced debugging
R -e "GOLEM_CONFIG_ACTIVE=development library(biSPCharts); biSPCharts::run_app(port = 4040)"

# ═══════════════════════════════════════════════════════
# DEVELOPMENT MODE - Source loading (kun til debugging)
# ═══════════════════════════════════════════════════════

# Development med source loading (~400ms+ startup, nyttigt til debugging)
R -e "source('global.R'); run_app()"

# Specify custom port
R -e "source('global.R'); run_app(port = 4040)"

# Alternative med direct shiny launch
R -e "source('global.R'); shiny::runApp('.', port = 4040)"
```

### Environment-Specific Usage
```r
# Development environment (auto-load test data, debug logging)
GOLEM_CONFIG_ACTIVE=development R -e "library(biSPCharts); biSPCharts::run_app()"

# Production environment (secure defaults)
GOLEM_CONFIG_ACTIVE=production R -e "library(biSPCharts); biSPCharts::run_app()"

# Testing environment (controlled conditions)
GOLEM_CONFIG_ACTIVE=testing R -e "library(biSPCharts); biSPCharts::run_app()"

# Manual debug logging (via explicit parameter)
R -e "library(biSPCharts); biSPCharts::run_app(log_level = 'DEBUG')"

# Development med source loading og debug logs
GOLEM_CONFIG_ACTIVE=development SPC_LOG_LEVEL=DEBUG R -e "source('global.R'); run_app()"
```

### Loading Strategy

**Package Loading (Anbefalet for produktion):**
- Hurtigere startup (~50-100ms)
- Optimeret til deployment
- Standard for production

**Source Loading (Kun til development debugging):**
- Langsommere startup (~400ms+)
- Nyttigt til debugging og development
- Automatisk aktiveret via `global.R`

```r
# Force source loading mode (kun til debugging)
options(spc.debug.source_loading = TRUE)
source('global.R')
run_app()
```

## 📊 Usage Examples

### Basic SPC Analysis
1. **Upload Data**: CSV eller Excel fil med danske formater
2. **Auto-Detektion**: App matcher automatisk kolonner til SPC standarder
3. **Kolonne Setup**: Juster X-akse, Tæller, Nævner efter behov
4. **Chart Generation**: Vælg chart type og generer SPC plot
5. **Export Results**: Download Excel med session metadata

### Supported Data Formats
```csv
Dato;Tæller;Nævner;Skift;Frys;Kommentarer
01-01-2024;95;100;FALSE;FALSE;Baseline
01-02-2024;92;95;FALSE;FALSE;Normal
01-03-2024;98;102;TRUE;FALSE;Intervention
```

## 🏗️ Architecture

### Project Structure
```
biSPCharts/
├── R/                          # R source files
│   ├── app_server.R           # Main server logic
│   ├── app_ui.R               # User interface
│   ├── fct_data_processing.R  # Data & column management
│   ├── fct_file_operations.R  # File I/O & uploads
│   ├── fct_spc_calculations.R # SPC computations
│   ├── utils_*.R              # Utility functions
│   └── constants.R            # App constants
├── tests/testthat/            # Test suites
├── docs/                      # Documentation
├── global.R                   # Global configuration
└── CLAUDE.md                  # Development guide
```

### State Management (Phase 4)
```r
# Centralized app state structure (environment-based for by-reference sharing)
app_state <- new.env(parent = emptyenv())

# Event bus for reactive communication
app_state$events <- reactiveValues(
  data_updated = 0L,              # CONSOLIDATED: Data load/change events
  auto_detection_completed = 0L,
  ui_sync_requested = 0L,
  session_reset = 0L
)

# Data management (reactiveValues for reactive dependencies)
app_state$data <- reactiveValues(
  current_data = NULL,
  original_data = NULL,
  file_info = NULL,
  updating_table = FALSE
)

# Hierarchical column management
app_state$columns <- reactiveValues(
  auto_detect = reactiveValues(in_progress = FALSE, completed = FALSE, results = NULL),
  mappings = reactiveValues(x_column = NULL, y_column = NULL, n_column = NULL),
  ui_sync = reactiveValues(needed = FALSE, last_sync_time = NULL)
)

# Emit API for event-driven updates
emit <- create_emit_api(app_state)
emit$data_updated(context = "upload")  # Trigger events
```

## 🧪 Testing

### Run Test Suite
```bash
# All tests
R -e "source('global.R'); testthat::test_dir('tests/testthat')"

# Specific test category
R -e "testthat::test_file('tests/testthat/test-name-only-detection-final.R')"
R -e "testthat::test_file('tests/testthat/test-end-to-end-app-flow.R')"
```

### Test Coverage

**Generate Coverage Report:**
```bash
# Detailed coverage report (console + HTML)
make coverage

# HTML report with browser
make coverage-html

# Basic covr output
make coverage-simple

# Or directly:
R -e "source('tests/coverage.R'); run_coverage_report()"
```

**Coverage Targets:**
- **Overall Target**: ≥90% test coverage
- **Critical Paths**: 100% coverage for state management, error handling, file operations

**Current Coverage Status:**
- **Name-only Detection**: 47 tests, >95% coverage
- **File Operations**: 39 tests, >90% coverage
- **Cross-component Reactive**: >85% coverage
- **End-to-end Integration**: 88 tests, >95% coverage
- **Data Consistency**: >85% coverage

## 📚 Documentation

### Developer Resources
- **[CLAUDE.md](CLAUDE.md)**: Comprehensive development guide
- **[REFACTORING_PLAN.md](REFACTORING_PLAN.md)**: Roadmap og progress tracking
- **[ARCHITECTURE.md](ARCHITECTURE.md)**: System architecture
- **[docs/ANALYTICS_PRIVACY.md](docs/ANALYTICS_PRIVACY.md)**: Analytics payload-kontrakt, opt-in mekanisme og DPIA-status

### API Documentation
```r
# Generate roxygen2 documentation
roxygen2::roxygenise()

# View function documentation
?setup_column_management
?detect_columns_name_only
?validate_x_column_format
```

## 🔧 Configuration

### Environment Variables
```bash
# Logging configuration
export SPC_LOG_LEVEL=DEBUG    # DEBUG, INFO, WARN, ERROR

# Development settings
export TEST_MODE_AUTO_LOAD=TRUE
export AUTO_RESTORE_ENABLED=FALSE
```

### CSV Format Settings
```r
# Danish locale (automatic)
locale(
  decimal_mark = ",",
  grouping_mark = ".",
  encoding = "ISO-8859-1"
)
```

## 🛠️ Development

### Code Quality Standards
- **Test-Driven Development**: Skriv tests først
- **Danish Comments**: Funktionalitet beskrives på dansk
- **English Function Names**: API på engelsk
- **Robust Error Handling**: Graceful degradation patterns
- **Performance First**: Debounced operations og memory management

### Contribution Workflow
1. **Problem Definition**: Start med én linje problem statement
2. **Test Design**: Skriv tests for ønsket adfærd FØRST
3. **Implementation**: Minimal viable change
4. **Test Verification**: Alle tests skal bestå
5. **Integration Testing**: Test full app workflow
6. **Documentation**: Opdater denne README hvis nødvendigt

### Git Convention
```bash
# Danish conventional commits
git commit -m "feat(spc): tilføj support for U-kort beregninger

Implementer U-kort funktionalitet med:
- Automatisk rate beregning
- Konfidensgrænser baseret på Poisson
- Integration med eksisterende chart pipeline

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

## 📈 Performance

### Benchmarks
- **App Start**: < 3 sekunder (med cached libraries)
- **File Upload**: < 5 sekunder for 1000+ rækker
- **Chart Generation**: < 2 sekunder for standard datasets
- **Memory Usage**: < 100MB for typical sessions

### Optimization Features
- **Lazy Loading**: Reactive expressions kun når nødvendigt
- **Debounced Operations**: Undgår excessive computations
- **Memory Management**: Automatic cleanup ved session end
- **Caching**: Intelligent data og computation caching

## 🏥 Clinical Integration

### Hospital Compatibility
- **Windows Support**: Testet på Windows hospital netværk
- **UTF-8 & ISO-8859-1**: Dual encoding support
- **Network Restrictions**: Fungerer bag hospital firewalls
- **Data Security**: Ingen data forlader local environment

### Quality Improvement Workflow
1. **Data Export**: Fra hospital systemer som CSV/Excel
2. **SPC Analysis**: Upload til app for automatisk analyse
3. **Chart Generation**: Professional SPC charts med kontrolgrænser
4. **Results Export**: Excel rapport med metadata for arkivering
5. **Quality Review**: Charts klar til quality meetings

## 🐛 Troubleshooting

### Common Issues
```r
# Debug logging
SPC_LOG_LEVEL=DEBUG R -e "shiny::runApp('.', port = 4040)"

# Clear session state
rm(list = ls())
source('global.R')

# Test specific components
testthat::test_file('tests/testthat/test-data-consistency.R')
```

### Error Recovery
- **File Upload Fejl**: Tjek encoding og CSV format
- **Auto-detektion Fejl**: Bekræft standard kolonne navne
- **Chart Generation Fejl**: Valider data typer og missing values
- **Performance Problemer**: Reducer data størrelse eller clear cache

## 📝 Changelog

Se [CHANGELOG.md](CHANGELOG.md) for komplet version history.

### Recent Updates (Oktober 2025)
- ✅ **Phase 5 (Week 16-18)**: Cleanup & Polish completion
  - Removed all commented code blocks
  - Archived completed migration documentation
  - Updated developer guides
- ✅ **Phase 4 (Week 11-15)**: Refactoring excellence
  - Y-axis formatting extraction
  - Parameter objects implementation
  - State accessor functions
  - Event handler strategy pattern
- ✅ **Phase 3 (Week 5-10)**: Test coverage sprint (90%+ coverage achieved)
- ✅ **Phase 2 (Week 3-4)**: Performance optimizations (30-50% improvement)
- ✅ **Phase 1 (Week 1-2)**: Quick wins og critical fixes

## 📄 License

Dette projekt er udviklet til intern hospitalsbrug. Kontakt udviklingsteam for licensing spørgsmål.

## 🤝 Support

### Development Team
- **Technical Lead**: Se [CLAUDE.md](CLAUDE.md) for development guidelines
- **Issues**: Rapporter via GitHub Issues eller internal ticketing system
- **Documentation**: Konsulter ARCHITECTURE.md og CLAUDE.md for detaljeret guidance

### Resources
- **qicharts2 Documentation**: https://github.com/anhoej/qicharts2
- **Shiny Best Practices**: Se [CLAUDE.md](CLAUDE.md) for development guidelines
- **Danish R Community**: Integration med lokale R brugergrupper

---

**Udviklet med ❤️ for dansk sundhedsvæsen**

*Sidste opdatering: 10. oktober 2025 - Fase 5 Cleanup & Polish*