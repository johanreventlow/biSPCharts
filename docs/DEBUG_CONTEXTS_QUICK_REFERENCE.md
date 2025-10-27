# Debug Contexts - Quick Reference

**Se alle contexts:** `show_debug_contexts()`

## All Available Contexts by Category

### AI (AI Improvement Suggestions)
```
AI_METADATA         - SPC metadata extraction for AI prompts
AI_PROMPT           - Prompt building and template interpolation
AI_SUGGESTION       - Main suggestion generation workflow
AI_CACHE            - AI result caching operations
GEMINI_API          - Gemini API integration and calls
```

### EXPORT (Export Module)
```
EXPORT_MODULE       - PDF export functionality and operations
```

### DATA (Data Processing)
```
DATA_PROCESS        - General data processing
DATA_PROC          - Legacy name for DATA_PROCESS
DATA_VALIDATION    - Data validation checks
DATA_TABLE         - Data table operations
```

### AUTODETECT (Column Auto-Detection)
```
UNIFIED_AUTODETECT      - Main auto-detection system
AUTO_DETECT_CACHE       - Caching of auto-detected columns
AUTO_DETECT_EVENT       - Auto-detection events
AUTODETECT_DECISIONS    - Decision-making logic
AUTODETECT_SETUP        - Setup and initialization
NAME_BASED_DETECT       - Name-based column detection
FULL_DATA_DETECT        - Full dataset detection
DATE_DETECT             - Date column detection
NUMERIC_DETECT          - Numeric column detection
COLUMN_SCORING          - Column scoring calculations
```

### PERFORMANCE (Performance Monitoring)
```
PERFORMANCE         - General performance monitoring
PERFORMANCE_BENCHMARK    - Benchmark measurements
PERFORMANCE_CACHE        - Cache performance
PERFORMANCE_MONITOR      - Active monitoring
PERFORMANCE_MONITORING   - Extended monitoring (variant)
PERFORMANCE_OPT          - Optimization work
PERFORMANCE_SETUP        - Setup and initialization
TIMING_MONITOR           - Timing measurements
```

### QIC (QIC/Anhøj Rules Calculations)
```
QIC                 - General QIC operations
QIC_CALL            - Function calls
QIC_ERROR           - Error handling
QIC_INPUT           - Input preparation
QIC_PREPARATION     - Data preparation
QIC_RESULT          - Results processing
QIC_TIMING          - Timing measurements
SPC_CALC_DEBUG      - SPC calculation debugging
SPC_PIPELINE        - Full pipeline operations
```

### UI (User Interface & Visualization)
```
VISUALIZATION       - General visualization
RENDER_PLOT         - Plot rendering
PLOT_OPTIMIZATION   - Plot optimization
PLOT_COMMENT        - Plot comments/notes
X_AXIS_FORMAT       - X-axis formatting
Y_AXIS_SCALING      - Y-axis scaling
[UI_SYNC]           - UI synchronization
[Y_AXIS_UI]         - Y-axis UI updates
```

### COLUMN (Column Management)
```
COLUMN_MGMT                  - General column management
COLUMN_CHOICES_UNIFIED       - Unified column choices
COLUMN_SCORING               - Column scoring
```

### APP (Application Lifecycle)
```
APP_INIT            - Application initialization
APP_SERVER          - Server setup
APP_CONFIG          - Configuration
SESSION_CLEANUP     - Session cleanup
SESSION_RESET       - Session reset
MEMORY_MGMT         - Memory management
BACKGROUND_CLEANUP  - Background cleanup tasks
```

### NAVIGATION
```
NAVIGATION_UNIFIED  - Unified navigation system
WELCOME_PAGE        - Welcome page
```

### TEST (Test Mode)
```
TEST_MODE           - General test mode
[TEST_MODE_STARTUP] - Test mode startup
DEMO_DATA           - Demo data loading
```

### FILE (File Operations)
```
FILE_UPLOAD         - File uploads
FILE_UPLOAD_SECURITY - Upload security checks
[FILE_VALIDATION]   - File validation
```

### SECURITY
```
[SECURITY]          - General security
[INPUT_SANITIZATION] - Input validation/sanitization
```

### CONFIG (Configuration)
```
CONFIG_APPLY        - Configuration application
CONFIG_CONVERT      - Configuration conversion
CONFIG_REGISTRY     - Configuration registry
RUNTIME_CONFIG      - Runtime configuration
```

### STARTUP (Initialization & Golem)
```
STARTUP_CACHE       - Startup caching
STARTUP_OPTIMIZATION - Startup optimizations
GOLEM_APPLY         - Golem configuration
GOLEM_ENV           - Golem environment
GOLEM_FALLBACK      - Golem fallback behavior
LAZY_LOADING        - Lazy module loading
```

### CACHE (Cache Management)
```
CACHE_GENERATOR     - Cache generation
CACHE_INVALIDATION  - Cache invalidation
[PERFORMANCE_CACHE] - Performance cache (variant)
```

### DEBUG (Debugging & Development)
```
DEBUG               - General debugging
ADVANCED_DEBUG      - Advanced debugging
DEV_MODE            - Development mode
PROD_MODE           - Production mode
[BENCHMARK]         - Benchmarking
MICROBENCHMARK      - Micro-benchmarking
```

### MISC (Miscellaneous)
```
EMIT_API            - Event emit API
ERROR_SYSTEM        - Error system
LOOP_PROTECTION     - Loop protection
ANHOEJ_COMPARISON   - Anhøj rules comparison
BRANDING_VERIFICATION - Branding verification
FAVICON             - Favicon handling
PACKAGE_VERIFICATION - Package verification
RESOURCE_PATHS      - Resource paths
SHINYLOGS           - Shinylogs configuration
TITLE_PROCESSING    - Title processing
USER_INTERACTION    - User interaction
VERIFICATION        - General verification
PIPELINE            - General pipeline operations
```

## Common Use Cases

### Debug AI Features
```r
show_debug_contexts()  # See all contexts
set_debug_context(c("AI_METADATA", "AI_PROMPT", "AI_SUGGESTION", "AI_CACHE", "GEMINI_API"))
```

### Debug PDF Export
```r
set_debug_context(c("EXPORT_MODULE"))
```

### Debug Auto-Detection
```r
set_debug_context(c("UNIFIED_AUTODETECT", "AUTO_DETECT_CACHE",
                    "NAME_BASED_DETECT", "FULL_DATA_DETECT", "COLUMN_SCORING"))
```

### Debug Plot Rendering
```r
set_debug_context(c("RENDER_PLOT", "PLOT_OPTIMIZATION",
                    "VISUALIZATION", "Y_AXIS_SCALING", "X_AXIS_FORMAT"))
```

### Debug Performance Issues
```r
set_debug_context(c("PERFORMANCE", "PERFORMANCE_BENCHMARK",
                    "PERFORMANCE_CACHE", "TIMING_MONITOR"))
```

### Debug Data Processing
```r
set_debug_context(c("DATA_PROCESS", "DATA_VALIDATION", "DATA_TABLE"))
```

### Debug File Uploads
```r
set_debug_context(c("FILE_UPLOAD", "FILE_UPLOAD_SECURITY", "[FILE_VALIDATION]"))
```

## Tips

1. **Start simple:** Filter to one category first, then add more as needed
2. **Use partial names:** `grep("PLOT", list_available_log_contexts())` to find plot-related contexts
3. **Reset easily:** `set_debug_context(NULL)` to go back to logging everything
4. **Combine levels:** Use log levels (`set_log_level("DEBUG")`) AND context filtering together
5. **Save token usage:** Filter to only what you need when debugging in Claude - huge token savings!

## See Also

- `docs/DEBUG_CONTEXT_FILTERING.md` - Full documentation
- `show_debug_contexts()` - Display in R console
- `set_debug_context()` - Set filter
- `get_debug_context()` - Check current filter
- `list_available_log_contexts()` - Get all contexts as vector
