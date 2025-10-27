# Debug Context Filtering

**Formål:** Reducer token-forbrug ved debugging ved at filtrere logging til kun relevante områder.

## Quick Start

### Step 1: Se alle tilgængelige contexts
```r
# Vis alle contexts organiseret efter kategori
show_debug_contexts()
```

### Step 2: Sæt filter baseret på hvad du vil debugge
```r
# Log kun state og data-relateret debugging
set_debug_context(c("state", "data", "performance"))

# Se din debug-output:
log_debug("Processerer data", .context = "state")       # ✓ Logges
log_debug("Rendrer plot", .context = "performance")     # ✓ Logges
log_debug("Cache hit", .context = "cache")              # ✗ Udeladt (ikke i filterlisten)
```

### Step 3: Reset når du er færdig
```r
# Log alt igen (default behavior)
set_debug_context(NULL)
```

## How It Works

### Default Behavior (Intet filtrering)
```r
# Hvis spc.debug.context ikke er sat (default):
# Alle log_debug(), log_info(), log_warn(), log_error() calls logges
log_debug("Besked 1", .context = "state")          # ✓ Logges
log_debug("Besked 2", .context = "performance")    # ✓ Logges
log_debug("Besked 3", .context = "data")           # ✓ Logges
```

### With Filtering
```r
# Når spc.debug.context er sat til specifik liste:
set_debug_context(c("state", "data"))
log_debug("Besked 1", .context = "state")          # ✓ Logges
log_debug("Besked 2", .context = "performance")    # ✗ Udeladt
log_debug("Besked 3", .context = "data")           # ✓ Logges
```

## Available Log Contexts

Log contexts er organiseret i kategorier. Her er alle tilgængelige:

### Data Processing
- `DATA_PROCESS` / `DATA_PROC` – Generel dataprocessering
- `DATA_VALIDATION` – Data validering
- `DATA_TABLE` – Data table operationer

### Auto Detection
- `UNIFIED_AUTODETECT` – Unified auto-detection system
- `AUTO_DETECT_CACHE` – Auto-detect caching
- `AUTO_DETECT_EVENT` – Auto-detect events
- `AUTODETECT_DECISIONS` – Auto-detect decision logic
- `AUTODETECT_SETUP` – Auto-detect setup
- `NAME_BASED_DETECT` – Name-based column detection
- `FULL_DATA_DETECT` – Full data auto-detection
- `DATE_DETECT` – Date column detection
- `NUMERIC_DETECT` – Numeric column detection
- `COLUMN_SCORING` – Column scoring calculations

### Performance Monitoring
- `PERFORMANCE` – Generel performance monitoring
- `PERFORMANCE_BENCHMARK` – Performance benchmarking
- `PERFORMANCE_CACHE` – Cache performance
- `PERFORMANCE_MONITOR` – Performance monitoring
- `PERFORMANCE_MONITORING` – Performance monitoring (variant)
- `PERFORMANCE_OPT` – Performance optimization
- `PERFORMANCE_SETUP` – Performance setup
- `TIMING_MONITOR` – Timing monitoring

### QIC/SPC Calculations
- `QIC` – Generel QIC-relateret
- `QIC_CALL` – QIC function calls
- `QIC_ERROR` – QIC errors
- `QIC_INPUT` – QIC input preparation
- `QIC_PREPARATION` – QIC preparation
- `QIC_RESULT` – QIC results
- `QIC_TIMING` – QIC timing
- `SPC_CALC_DEBUG` – SPC calculation debugging
- `SPC_PIPELINE` – SPC pipeline

### UI & Visualization
- `VISUALIZATION` – Generel visualization
- `RENDER_PLOT` – Plot rendering
- `PLOT_OPTIMIZATION` – Plot optimization
- `PLOT_COMMENT` – Plot comments
- `X_AXIS_FORMAT` – X-axis formatting
- `Y_AXIS_SCALING` – Y-axis scaling
- `[UI_SYNC]` – UI synchronization
- `[Y_AXIS_UI]` – Y-axis UI

### Column Management
- `COLUMN_MGMT` – Column management
- `COLUMN_CHOICES_UNIFIED` – Unified column choices
- `COLUMN_SCORING` – Column scoring

### App Lifecycle
- `APP_INIT` – App initialization
- `APP_SERVER` – App server setup
- `APP_CONFIG` – App configuration
- `SESSION_CLEANUP` – Session cleanup
- `SESSION_RESET` – Session reset
- `MEMORY_MGMT` – Memory management
- `BACKGROUND_CLEANUP` – Background cleanup

### Navigation
- `NAVIGATION_UNIFIED` – Unified navigation
- `WELCOME_PAGE` – Welcome page

### Test Mode
- `TEST_MODE` – Test mode general
- `[TEST_MODE_STARTUP]` – Test mode startup
- `DEMO_DATA` – Demo data

### File Operations
- `FILE_UPLOAD` – File uploads
- `FILE_UPLOAD_SECURITY` – File upload security
- `[FILE_VALIDATION]` – File validation

### Security
- `[SECURITY]` – Generel security
- `[INPUT_SANITIZATION]` – Input sanitization

### Configuration
- `CONFIG_APPLY` – Config application
- `CONFIG_CONVERT` – Config conversion
- `CONFIG_REGISTRY` – Config registry
- `RUNTIME_CONFIG` – Runtime configuration

### Startup & Golem
- `STARTUP_CACHE` – Startup caching
- `STARTUP_OPTIMIZATION` – Startup optimization
- `GOLEM_APPLY` – Golem application
- `GOLEM_ENV` – Golem environment
- `GOLEM_FALLBACK` – Golem fallback
- `LAZY_LOADING` – Lazy loading

### Cache Management
- `CACHE_GENERATOR` – Cache generation
- `CACHE_INVALIDATION` – Cache invalidation
- `[PERFORMANCE_CACHE]` – Performance cache (variant)

### Debug & Development
- `DEBUG` – Generel debugging
- `ADVANCED_DEBUG` – Advanced debugging
- `DEV_MODE` – Development mode
- `PROD_MODE` – Production mode
- `[BENCHMARK]` – Benchmarking
- `MICROBENCHMARK` – Microbenchmarking

### Miscellaneous
- `EMIT_API` – Event emit API
- `ERROR_SYSTEM` – Error system
- `LOOP_PROTECTION` – Loop protection
- `ANHOEJ_COMPARISON` – Anhøj rules comparison
- `BRANDING_VERIFICATION` – Branding verification
- `FAVICON` – Favicon handling
- `PACKAGE_VERIFICATION` – Package verification
- `RESOURCE_PATHS` – Resource paths
- `SHINYLOGS` – Shinylogs configuration
- `TITLE_PROCESSING` – Title processing
- `USER_INTERACTION` – User interaction
- `VERIFICATION` – Generel verification
- `PIPELINE` – Generel pipeline

## Helper Functions

### Show Debug Contexts (Recommended)

```r
# Se alle tilgængelige contexts organiseret efter kategori
show_debug_contexts()

# Output:
# === AVAILABLE DEBUG CONTEXTS ===
# Use with: set_debug_context(c("context1", "context2"))
#
# DATA                : DATA_PROCESS, DATA_PROC, DATA_VALIDATION, DATA_TABLE
# AUTODETECT          : UNIFIED_AUTODETECT, AUTO_DETECT_CACHE, ...
# PERFORMANCE         : PERFORMANCE, PERFORMANCE_BENCHMARK, ...
# ... osv.
```

### Set Debug Context

```r
# Sæt hvilke contexts skal logges
set_debug_context(c("state", "data", "performance"))

# Log intet
set_debug_context(character(0))

# Log alt igen (default)
set_debug_context(NULL)
```

### Get Debug Context

```r
# Få nuværende filter
current_filter <- get_debug_context()

# NULL betyder ingen filtrering (logger alt)
if (is.null(current_filter)) {
  cat("Logging all contexts\n")
} else {
  cat("Currently filtering to:", paste(current_filter, collapse = ", "))
}
```

### List Available Contexts (Programmatic)

```r
# Se alle tilgængelige contexts som vektor
all_contexts <- list_available_log_contexts()

# Find alle state-relaterede contexts
state_contexts <- grep("state", all_contexts, ignore.case = TRUE, value = TRUE)
set_debug_context(state_contexts)
```

## Common Use Cases

### Case 1: Debug AI Suggestion Feature
```r
set_debug_context(c("QIC", "AI", "CACHE", "ERROR_SYSTEM"))
# Eller hvis du ønsker mere specifik:
set_debug_context(c("QIC_CALL", "QIC_RESULT", "CACHE_GENERATOR"))
```

### Case 2: Debug Auto-Detection Issues
```r
set_debug_context(c(
  "UNIFIED_AUTODETECT",
  "AUTO_DETECT_CACHE",
  "NAME_BASED_DETECT",
  "FULL_DATA_DETECT",
  "COLUMN_SCORING"
))
```

### Case 3: Debug Performance Issues
```r
set_debug_context(c(
  "PERFORMANCE",
  "PERFORMANCE_BENCHMARK",
  "PERFORMANCE_CACHE",
  "TIMING_MONITOR"
))
```

### Case 4: Debug Plot Rendering
```r
set_debug_context(c(
  "RENDER_PLOT",
  "PLOT_OPTIMIZATION",
  "VISUALIZATION",
  "Y_AXIS_SCALING"
))
```

## Implementation Details

### How It Works

1. **Option Storage:** Debug context filter er gemt i `spc.debug.context` R option
2. **Check Before Log:** Hver log-funktion (`log_debug`, `log_info`, `log_warn`, `log_error`) checker filter før de logger
3. **Match Logic:** Hvis context er i listen, logges beskeden. Ellers springes den over
4. **Default:** Hvis option ikke er sat eller er `NULL`, logger alle

### Special Cases

- **Empty filter (`character(0)`):** Gemmes internt som `"__EMPTY__"` marker, da R automatisk konverterer tom vektor til `NULL` i options. Dette marker sikrer "log intet"-mode virker korrekt
- **NULL context:** Hvis en log-funktion kaldes uden `.context` parameter, behandles den som `"UNSPECIFIED"` og logges kun hvis eksplicit tilladt

### Performance Considerations

- **Zero overhead når inaktiv:** Hvis `spc.debug.context` ikke er sat, er der ingen performance impact
- **Fast matching:** Context-checking bruger simpel vektor-matching (`%in%`)
- **Early exit:** Log-funktioner returnerer tidligt hvis context ikke matcher

## Integration with Logging Levels

Debug context filtering arbejder **sammen med** log levels, ikke i stedet for dem:

```r
# Log level kontrollerer HVILKE BESKEDER der logges (DEBUG vs INFO vs WARN)
set_log_level("DEBUG")  # Enable all debug messages

# Debug context kontrollerer HVILKE OMRÅDER der logges
set_debug_context(c("state", "data"))  # Only from these contexts

# Kombineret effekt:
log_debug("Besked 1", .context = "state")        # ✓ DEBUG enabled + context match
log_debug("Besked 2", .context = "performance")  # ✗ DEBUG enabled but context skip
log_info("Besked 3", .context = "state")         # ✓ (INFO også filtreres af context)
```

## Notes

- Context-navne er **case-sensitive** (brug nøjagtigt som defineret i `LOG_CONTEXTS`)
- `set_debug_context()` viser en besked når den sættes, så du kan se hvad der blev sat
- For at finde præcise context-navne, brug `list_available_log_contexts()`
- Denne feature er **ikke** til production-logging – det handler kun om lokalt debugging
