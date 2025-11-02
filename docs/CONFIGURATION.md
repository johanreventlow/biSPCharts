# SPCify Configuration Guide

This document covers configuration options and dependencies for SPCify.

## Dependencies

### Core Dependencies

SPCify requires the following key R packages:

- **shiny** (>= 1.7.0) - Shiny web application framework
- **BFHcharts** (>= 0.1.0) - SPC visualization engine for BFH branding
- **qicharts2** (>= 0.7.0) - Anhøj rules calculation (in Suggests for testing)
- **golem** (>= 0.4.0) - Shiny app framework

### AI and RAG Dependencies

**AI-Powered Improvement Suggestions:**

- **ellmer** (>= 0.2.0) - R interface to Google Gemini API
  - Used for generating AI-assisted improvement suggestions
  - Requires `GOOGLE_API_KEY` environment variable
  - See README.md "AI-Assisteret Forbedringsmål" section for setup

- **ragnar** (>= 0.1.0) - RAG (Retrieval-Augmented Generation) framework
  - Provides knowledge base integration for improved AI suggestions
  - Grounds Gemini responses in authoritative SPC methodology
  - Knowledge store built at package installation time
  - **Status:** Infrastructure setup complete (issue #80), build system pending (issue #82)

**RAG Knowledge Base:**

The Ragnar integration uses a pre-built knowledge store containing:
- SPC fundamentals (common vs. special cause variation)
- Anhøj rules and signal detection
- Chart type guidance and interpretation
- Investigation frameworks (Pyramid Model)

**Location:**
- Knowledge documentation: `inst/spc_knowledge/*.md`
- Built store: `inst/ragnar_store/` (created during package build)

**Source:** Jacob Anhøj's "SPC for Healthcare" (https://anhoej.github.io/spc4hc/)

### Environment Variables

**Required for AI Features:**

```r
# Set in .Renviron file
GOOGLE_API_KEY=your_api_key_here
```

**How to configure:**

```r
# Open .Renviron file
usethis::edit_r_environ()

# Add the API key line
# Save and restart R session

# Verify
Sys.getenv("GOOGLE_API_KEY")
```

## Golem Configuration

SPCify uses `inst/golem-config.yml` for environment-specific settings:

- **dev** - Development mode with debug logging
- **test** - Testing mode with reduced logging
- **prod** - Production mode with minimal logging

**AI Configuration:**

```yaml
ai:
  enabled: TRUE/FALSE
  model: "gemini-2.5-flash-lite"
  timeout_seconds: 10
  max_chars: 350
  rag:
    enabled: TRUE/FALSE  # Enable RAG knowledge base
    n_results: 3         # Number of knowledge chunks to retrieve (1-10)
    method: "hybrid"     # "vector", "keyword", or "hybrid" search
  circuit_breaker:
    failure_threshold: 5
    reset_timeout_seconds: 300
```

**Environment-Specific RAG Settings:**

| Environment | RAG Enabled | Rationale |
|-------------|-------------|-----------|
| **default** | `true` | Base configuration with RAG enabled |
| **development** | `true` | Enable RAG for development testing |
| **production** | `true` | Grounded AI responses in production |
| **testing** | `false` | Use mocks for deterministic tests |

**RAG Configuration Parameters:**

- **`enabled`** (Boolean): Feature flag to enable/disable RAG
  - `true`: Query knowledge store for SPC methodology context
  - `false`: Use base prompt without RAG augmentation

- **`n_results`** (Integer, 1-10): Number of knowledge chunks to retrieve
  - Lower values (1-2): Faster, less context
  - Optimal (3): Balance mellem context og performance (anbefalet)
  - Higher values (5-10): Richer context, slower retrieval

- **`method`** (String): Search method for knowledge retrieval
  - `"vector"`: Pure semantic similarity search
  - `"keyword"`: Traditional keyword/BM25 search
  - `"hybrid"`: Combined vector + keyword (anbefalet for SPC terminology)

**Access configuration in code:**

```r
# Get AI config
ai_config <- golem::get_golem_options("ai")

# Check if AI enabled
if (isTRUE(ai_config$enabled)) {
  # AI features available
}

# Get RAG settings
rag_config <- get_rag_config()
if (isTRUE(rag_config$enabled)) {
  spc_knowledge <- query_spc_knowledge(
    chart_type = metadata$chart_type,
    signals = signals,
    target_comparison = target_comparison,
    n_results = rag_config$n_results,
    method = rag_config$method
  )
}
```

## Package Installation

**Standard Installation:**

```r
# Install from local source
devtools::install()

# Or from GitHub (when available)
remotes::install_github("johanreventlow/claude_spc")
```

**With RAG Knowledge Store Build:**

The RAG knowledge store is built automatically during package installation if `GOOGLE_API_KEY` is available. If the build fails:

1. Package still installs successfully (RAG is optional)
2. AI features fall back to base prompt without RAG context
3. To rebuild store manually: Run `data-raw/build_ragnar_store.R` (when implemented in issue #82)

## Troubleshooting

### RAG Issues

**Problem:** "Ragnar store not found"
- **Cause:** Knowledge store build failed or was skipped
- **Solution:** AI features still work, but without RAG context. To rebuild:
  - Ensure `GOOGLE_API_KEY` is set
  - Reinstall package: `devtools::install()`
  - Or run build script manually (when available)

**Problem:** "Ragnar package not installed"
- **Cause:** Missing ragnar dependency
- **Solution:** Install ragnar: `install.packages("ragnar")`

### AI Issues

See README.md "AI-Assisteret Forbedringsmål" section for detailed AI troubleshooting.

## Additional Documentation

- **README.md** - General usage and AI setup guide
- **CLAUDE.md** - Development instructions and architecture
- **docs/adr/** - Architecture Decision Records
- **inst/spc_knowledge/** - RAG knowledge base documentation

---

**Last Updated:** 2025-10-28
**Related Issues:** #79 (RAG Epic), #80 (Infrastructure setup)
