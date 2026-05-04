# biSPCharts Configuration Guide

Complete guide to biSPCharts configuration system with unified precedence rules, getter functions, and environment-specific settings.

## Configuration Overview

biSPCharts uses a **unified configuration system** with clear precedence rules:

1. **Environment Variables** (highest priority — runtime overrides)
2. **Golem Config YAML** (`inst/golem-config.yml`)
3. **Constant Defaults** (built-in defaults)

All configuration is accessed through **centralized getter functions** that support future YAML-based configuration without code changes.

---

## Logging Configuration

### Setting Log Levels

The logging system uses **unified precedence** to resolve log levels:

```r
# Priority 1: Environment Variable (overrides everything)
Sys.setenv(SPC_LOG_LEVEL = "DEBUG")

# Priority 2: Golem Config YAML (if no env var)
# inst/golem-config.yml:
# default:
#   logging:
#     level: "WARN"
# development:
#   logging:
#     level: "DEBUG"

# Priority 3: Default (fallback)
# Default: "INFO"
```

### Available Log Levels

| Level  | Numeric | Description |
|--------|---------|-------------|
| DEBUG  | 1       | Detailed debug information |
| INFO   | 2       | General information |
| WARN   | 3       | Warnings |
| ERROR  | 4       | Error messages |

### Accessing Log Configuration

```r
# Get effective log level (respects precedence)
get_effective_log_level()

# Get log level name
get_log_level_name()

# Helper functions for common configurations
set_log_level_development()  # DEBUG
set_log_level_production()   # WARN
set_log_level_quiet()        # ERROR
set_log_level_info()         # INFO
set_log_level("CUSTOM")      # Custom level

# Set debug context filtering (reduce token usage)
set_debug_context(c("state", "data", "ai"))
get_debug_context()
show_debug_contexts()
```

---

## Performance Configuration

All performance constants are accessed via getter functions supporting future YAML configuration.

### Debounce Delays

```r
get_debounce_delay(operation)
```

**Available operations:**
- `"input_change"` → **150ms** (rapid user input)
- `"file_select"` → **500ms** (file selection)
- `"chart_update"` → **500ms** (chart rendering)
- `"table_cleanup"` → **2000ms** (table operations)

**Example:**
```r
user_input <- shiny::debounce(
  reactive(input$dropdown),
  millis = get_debounce_delay("input_change")
)
```

### Operation Timeouts

```r
get_operation_timeout(operation)
```

**Available operations:**
- `"file_read"` → **30,000ms (30s)**
- `"chart_render"` → **10,000ms (10s)**
- `"auto_detect"` → **5,000ms (5s)**
- `"ui_update"` → **2,000ms (2s)**

### Performance Thresholds

```r
get_performance_threshold(metric)
```

**Available metrics:**
- `"reactive_warning"` → **0.5s**
- `"debounce_warning"` → **1.0s**
- `"memory_warning"` → **10MB**
- `"cache_timeout_default"` → **300s (5 min)**

### Cache Configuration

```r
get_cache_config(setting)
```

**Available settings:**
- `"default_timeout_seconds"` → **300s (5 min)**
- `"extended_timeout_seconds"` → **600s (10 min)**
- `"short_timeout_seconds"` → **60s**
- `"size_limit_entries"` → **50**
- `"cleanup_interval_seconds"` → **300s**

### Auto-Save Configuration

```r
get_autosave_delay(context)
```

- `"data_save"` → **2000ms (2s)**
- `"settings_save"` → **1000ms (1s)**

### UI Update Protection

```r
get_loop_protection_delay(scenario)
```

- `"default"` → **500ms**
- `"conservative"` → **800ms** (slower browsers)
- `"minimal"` → **200ms** (fast responses)
- `"onFlushed_fallback"` → **1000ms** (fallback)

### Test Mode Configuration

```r
get_test_mode_config(setting)
```

- `"ready_event_delay_seconds"` → **1.5s**
- `"startup_debounce_ms"` → **300ms**
- `"auto_detect_delay_ms"` → **250ms**
- `"lazy_plot_generation"` → **TRUE**

---

## UI Configuration

All UI constants are accessed via getter functions for responsive design support.

### Column Layouts

```r
get_ui_column_width(layout_type)
```

- `"sidebar"` → `c(3, 9)` (sidebar + main)
- `"half"` → `c(6, 6)` (50/50)
- `"thirds"` → `c(4, 4, 4)` (33/33/33)
- `"quarter"` → `c(6, 6, 6, 6)` (four equal)

### Component Heights

```r
get_ui_height(component)
```

- `"logo"` → `"40px"`
- `"modal_content"` → `"300px"`
- `"chart_container"` → `"calc(50vh - 60px)"`
- `"table_max"` → `"200px"`
- `"sidebar_min"` → `"130px"`

### Reusable CSS Styles

```r
get_ui_style(style_type)
```

- `"flex_column"` — Flexible column layout
- `"scroll_auto"` — Scrollable container
- `"full_width"` — Full width
- `"right_align"` — Right-aligned text
- `"margin_right"` — Right margin (10px)
- `"position_absolute_right"` — Absolute positioned (top right)

### Input Widths

```r
get_ui_input_width(width_type)
```

- `"full"` → `"100%"`
- `"half"` → `"50%"`
- `"quarter"` → `"25%"`
- `"three_quarter"` → `"75%"`
- `"auto"` → `"auto"`

### Layout Proportions

```r
get_ui_layout_proportion(proportion_type)
```

- `"half"` → **0.5**
- `"third"` → **0.333**
- `"quarter"` → **0.25**
- `"two_thirds"` → **0.667**
- `"three_quarters"` → **0.75**

### Font Scaling

```r
get_ui_font_scaling(parameter)
```

- `"divisor"` → **42** (lower = larger fonts)
- `"min_size"` → **8** (points)
- `"max_size"` → **64** (points)

**Formula:** `base_size = max(min_size, min(max_size, diagonal / divisor))`

### Viewport Defaults

```r
get_ui_viewport_default(parameter)
```

- `"width"` → **800px**
- `"height"` → **600px**
- `"dpi"` → **96**

---

## Export Configuration

PDF/PNG-eksport-konstanter (defineret i `R/config_export_config.R`).

### Metadata Character Limits

| Konstant | Default | Beskrivelse |
|----------|---------|-------------|
| `EXPORT_TITLE_MAX_LENGTH` | 200 | Maks chart-titel |
| `EXPORT_DESCRIPTION_MAX_LENGTH` | 2000 | Maks PDF-datadefinition + LLM-context truncation-cap |
| `EXPORT_DEPARTMENT_MAX_LENGTH` | 250 | Maks afdelings-/afsnit-navn |
| `EXPORT_HOSPITAL_MAX_LENGTH` | 250 | Maks hospitalsnavn |
| `EXPORT_FOOTNOTE_MAX_LENGTH` | 500 | Maks fodnote/datakilde-attribution (sendes som `metadata$footer_content` til BFHcharts Typst-template, #485) |

Limits håndhæves client-side (HTML5 `maxlength` for input-felter) +
server-side via `validate_export_inputs()`.

---

## Environment Variables

### Logging

| Variable | Values | Default | Priority |
|----------|--------|---------|----------|
| `SPC_LOG_LEVEL` | `DEBUG`, `INFO`, `WARN`, `ERROR` | From YAML | 1 (highest) |

### API Configuration

| Variable | Purpose | Example | Default |
|----------|---------|---------|---------|
| `GOOGLE_API_KEY` | Google API authentication | `AIza...` | None |
| `GEMINI_API_KEY` | Gemini LLM API (fallback) | `AIza...` | None |

### Application

| Variable | Values | Default | Purpose |
|----------|--------|---------|---------|
| `GOLEM_CONFIG_ACTIVE` | `development`, `testing`, `production`, `default` | `default` | Active configuration environment |

---

## Dependencies

### Core Dependencies

biSPCharts requires the following key R packages:

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

biSPCharts uses `inst/golem-config.yml` for environment-specific settings:

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
remotes::install_github("johanreventlow/biSPCharts")
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

## Git Hooks

biSPCharts bruger custom git-hooks for at håndhæve kvalitetskrav før push til remote. Hooks er versioneret i `dev/git-hooks/` og installeres som symlinks.

### Installation

```bash
Rscript dev/install_git_hooks.R
```

Installerer:

- `.git/hooks/pre-push` → `dev/git-hooks/pre-push`

Kan køres flere gange (idempotent). Brug `--force` for at overskrive eksisterende hooks. `--uninstall` fjerner installerede symlinks.

### pre-push hook

**Kører før `git push`:**

1. `lintr::lint_package()` — afviser ved lintr-ERROR (warnings er ikke-blokerende)
2. `devtools::test()` — afviser ved fail/error (skips er OK)

**Tilstande:**

| Mode | Sætning | Varighed | Formål |
|------|---------|----------|--------|
| `full` (default) | `git push` | 5-10 min | Komplet suite før push |
| `fast` | `PREPUSH_MODE=fast git push` | ~2 min | Hurtig iteration under udvikling |

**Bypass:**

```bash
SKIP_PREPUSH=1 git push      # Environment variable
git push --no-verify         # Git-native bypass
```

⚠️ **Kendt begrænsning:** Pre-push vil blokere push indtil #279 + #280 er lukket (suite har pre-existing 2 fails + 17 errors). Brug `SKIP_PREPUSH=1` indtil da.

### Interaktiv R-session advarsel

Ved R-start i projekt-rod logges en advarsel hvis pre-push ikke er installeret. Implementeret i `.Rprofile`. Vises kun i interaktive sessioner (ignoreres i Rscript/CI).

---

## Additional Documentation

- **README.md** - General usage and AI setup guide
- **CLAUDE.md** - Development instructions and architecture
- **docs/adr/** - Architecture Decision Records
- **inst/spc_knowledge/** - RAG knowledge base documentation

---

**Last Updated:** 2025-10-28
**Related Issues:** #79 (RAG Epic), #80 (Infrastructure setup)
