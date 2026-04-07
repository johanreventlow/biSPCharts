# Startup Contract - SPC App

## Unified Boot Sequence

Dette dokument definerer den autoritative startup-rækkefølge for SPC-applikationen.

### 📋 Startup Contract Phases

#### Phase 1: Environment Detection
```
.onLoad() → GOLEM_CONFIG_ACTIVE → Basic Package ENV Setup
```

**Ansvar:** `R/zzz.R:.onLoad()`
- Sæt basis package environment (branding, colors)
- **IKKE** sæt log-level her (kun hvis tomt)
- Registrer hospital branding i package ENV

#### Phase 2: Configuration Loading
```
run_app() → configure_logging_from_yaml() → YAML → SPC_LOG_LEVEL
```

**Ansvar:** `R/app_run.R:configure_logging_from_yaml()`
- **YAML som single source**: `inst/golem-config.yml:logging.level`
- Respektér eksplicit `run_app(log_level=...)` override
- Fallback kun hvis YAML fejler

#### Phase 3: Environment Configuration
```
configure_app_environment() → Test Mode + Golem Options
```

**Ansvar:** `R/app_run.R:configure_app_environment()`
- Sæt `GOLEM_CONFIG_ACTIVE` baseret på test mode
- Konfigurér package ENV for test data
- **IKKE** override log-level igen

#### Phase 4: Performance Optimizations
```
initialize_startup_performance_optimizations() → Cache + Lazy Loading
```

**Ansvar:** `R/app_run.R:initialize_startup_performance_optimizations()`
- Lazy loading: namespace-baseret i prod, source-baseret i dev
- Startup cache: TTL-baseret artifacts
- Performance monitoring setup

#### Phase 5: Application Start
```
shiny::shinyApp(app_ui, app_server) → Event Bus → Observers
```

**Ansvar:** `R/app_server_main.R:main_app_server()`
- Event listeners registration
- UI/Server binding
- Reactive system initialization

## 🎯 Configuration Sources Priority

1. **Eksplicit parameter**: `run_app(log_level="DEBUG")` - Highest priority
2. **YAML config**: `inst/golem-config.yml:logging.level` - Standard source
3. **Environment fallback**: Development="DEBUG", Production="WARN" - Last resort

## 🚫 Anti-Patterns to Avoid

### ❌ Multiple config sources
```r
# WRONG: Multiple places setting same value
.onLoad: Sys.setenv(SPC_LOG_LEVEL = "INFO")
configure_app_environment: Sys.setenv(SPC_LOG_LEVEL = "DEBUG")
run_app: Sys.setenv(SPC_LOG_LEVEL = "WARN")
```

### ✅ Single source pattern
```r
# CORRECT: One authoritative source
configure_logging_from_yaml(log_level) → YAML → SPC_LOG_LEVEL
```

### ❌ Source loading in production
```r
# WRONG: File paths in installed package
if (file.exists("R/heavy_module.R")) source("R/heavy_module.R")
```

### ✅ Namespace-based loading
```r
# CORRECT: Environment-aware loading
if (package_mode) {
  # Functions already loaded via namespace
} else {
  source("R/heavy_module.R")  # Dev only
}
```

## 🧪 Testing the Contract

### Log Level Verification
```r
# Test: YAML adherence
Sys.setenv(GOLEM_CONFIG_ACTIVE = "development")
# Expected: SPC_LOG_LEVEL == get_golem_config("logging")$level

# Test: Explicit override
run_app(log_level = "INFO")
# Expected: SPC_LOG_LEVEL == "INFO" regardless of YAML
```

### Environment Consistency
```r
# Test: Single config flow
# Change YAML → restart → verify app reflects change
# No hidden env vars should override YAML
```

### Production vs Development
```r
# Production test: No file warnings
library(biSPCharts); run_app()  # Should not mention missing R/ files

# Development test: Source loading works
source('global.R')  # Should load all functions correctly
```

## 📁 Key Files

- `R/zzz.R:.onLoad()` - Package initialization
- `R/app_run.R:configure_logging_from_yaml()` - Log config
- `R/app_run.R:configure_app_environment()` - Environment setup
- `R/utils_lazy_loading.R` - Performance optimizations
- `inst/golem-config.yml` - Single source of configuration truth
- `global.R` - Development/test harness (NOT production dependency)

## 🎯 Success Criteria

✅ **Predictable**: Same config always produces same startup behavior
✅ **Testable**: Config changes can be unit tested
✅ **Observable**: Clear logging shows which source provided each setting
✅ **Maintainable**: One place to change each configuration type
✅ **Production-ready**: No dev artifacts leak into production boot