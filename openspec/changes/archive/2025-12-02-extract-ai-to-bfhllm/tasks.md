# Tasks: Extract AI to BFHllm

**Tracking:** GitHub Issue #99
**Status:** proposed

## Phase 1: BFHllm Package Creation

### 1.1 Repository Setup
- [ ] 1.1.1 Opret GitHub repo `johanreventlow/BFHllm`
- [ ] 1.1.2 Opret lokal mappe `~/Documents/R/BFHllm`
- [ ] 1.1.3 Initialiser R package struktur (`usethis::create_package()`)
- [ ] 1.1.4 Konfigurer DESCRIPTION (Title, Description, License: MIT)
- [ ] 1.1.5 Setup testthat (`usethis::use_testthat()`)
- [ ] 1.1.6 Opret README.md med basic beskrivelse

### 1.2 Core Infrastructure
- [ ] 1.2.1 Implementer `R/BFHllm-package.R` (package dokumentation)
- [ ] 1.2.2 Implementer `R/config.R` (konfigurationsstyring)
- [ ] 1.2.3 Implementer `R/provider-interface.R` (provider abstraktion)
- [ ] 1.2.4 Implementer `R/provider-gemini.R` (ellmer wrapper)
- [ ] 1.2.5 Implementer `R/circuit-breaker.R` (fra utils_gemini_integration.R)
- [ ] 1.2.6 Implementer `R/response-validation.R` (response sanitering)

### 1.3 Caching Layer
- [ ] 1.3.1 Implementer `R/cache.R` (generisk in-memory cache)
- [ ] 1.3.2 Implementer `R/cache-shiny.R` (Shiny session adapter)
- [ ] 1.3.3 Skriv tests for cache funktionalitet

### 1.4 Main Chat Function
- [ ] 1.4.1 Implementer `R/chat.R` (bfhllm_chat hovedfunktion)
- [ ] 1.4.2 Implementer `R/prompts.R` (template utilities)
- [ ] 1.4.3 Skriv tests for chat funktion

### 1.5 RAG Integration
- [ ] 1.5.1 Implementer `R/knowledge-store.R` (store loading)
- [ ] 1.5.2 Implementer `R/rag.R` (RAG query functions)
- [ ] 1.5.3 Flyt `inst/spc_knowledge/` fra SPCify
- [ ] 1.5.4 Flyt `inst/ragnar_store/` fra SPCify
- [ ] 1.5.5 Flyt `data-raw/build_ragnar_store.R` fra SPCify
- [ ] 1.5.6 Skriv tests for RAG funktionalitet

### 1.6 SPC Suggestions Module
- [ ] 1.6.1 Implementer `R/spc-suggestions.R` (bfhllm_spc_suggestion)
- [ ] 1.6.2 Implementer metadata extraction helpers
- [ ] 1.6.3 Implementer Danish chart type mapping
- [ ] 1.6.4 Skriv tests for SPC suggestions

### 1.7 Documentation & Release Prep
- [ ] 1.7.1 Dokumenter alle exported functions (roxygen2)
- [ ] 1.7.2 Opdater NAMESPACE via `devtools::document()`
- [ ] 1.7.3 Skriv eksempler i `inst/examples/`
- [ ] 1.7.4 Kør `devtools::check()` - fix eventuelle issues
- [ ] 1.7.5 Tag v0.1.0

---

## Phase 2: SPCify Migration

### 2.1 Dependency Update
- [ ] 2.1.1 Tilføj `BFHllm (>= 0.1.0)` til DESCRIPTION Imports
- [ ] 2.1.2 Fjern `ellmer`, `ragnar` fra DESCRIPTION (nu indirekte via BFHllm)
- [ ] 2.1.3 Verificer dependency resolution

### 2.2 Integration Layer
- [ ] 2.2.1 Opret `R/utils_bfhllm_integration.R` (tynd wrapper)
- [ ] 2.2.2 Implementer SPCify-specifik konfiguration
- [ ] 2.2.3 Implementer Shiny cache adapter integration

### 2.3 Code Migration
- [ ] 2.3.1 Opdater `R/fct_ai_improvement_suggestions.R` → kald `BFHllm::bfhllm_spc_suggestion()`
- [ ] 2.3.2 Opdater `R/mod_export_server.R` → brug BFHllm cache
- [ ] 2.3.3 Opdater eventuelle andre AI-kaldende filer

### 2.4 Code Cleanup
- [ ] 2.4.1 Slet `R/utils_gemini_integration.R`
- [ ] 2.4.2 Slet `R/utils_ai_cache.R`
- [ ] 2.4.3 Slet `R/utils_ragnar_integration.R`
- [ ] 2.4.4 Opdater/slet relevante dele af `R/config_ai_prompts.R`
- [ ] 2.4.5 Slet `inst/spc_knowledge/` (nu i BFHllm)
- [ ] 2.4.6 Slet `inst/ragnar_store/` (nu i BFHllm)
- [ ] 2.4.7 Slet `data-raw/build_ragnar_store.R` (nu i BFHllm)
- [ ] 2.4.8 Opdater NAMESPACE via `devtools::document()`

### 2.5 Testing
- [ ] 2.5.1 Opdater `tests/testthat/test-fct_ai_improvement_suggestions.R`
- [ ] 2.5.2 Opdater `tests/testthat/test-utils_ai_cache.R` → slet eller mock
- [ ] 2.5.3 Fjern tests for slettede funktioner
- [ ] 2.5.4 Tilføj integration tests for BFHllm kald
- [ ] 2.5.5 Kør `devtools::check()` - fix eventuelle issues

### 2.6 Documentation
- [ ] 2.6.1 Opdater NEWS.md med migration notes
- [ ] 2.6.2 Opdater CLAUDE.md RAG sektion (referencer til BFHllm)
- [ ] 2.6.3 Bump version i DESCRIPTION

---

## Phase 3: Release & Verification

### 3.1 BFHllm Release
- [ ] 3.1.1 Push BFHllm til GitHub
- [ ] 3.1.2 Tag BFHllm v0.1.0 release
- [ ] 3.1.3 Verificer `remotes::install_github("johanreventlow/BFHllm")` virker

### 3.2 SPCify Integration Test
- [ ] 3.2.1 Manuel test: AI suggestions i Shiny app
- [ ] 3.2.2 Manuel test: RAG context i AI suggestions
- [ ] 3.2.3 Verificer cache fungerer korrekt
- [ ] 3.2.4 Test graceful degradation ved API fejl

### 3.3 Standalone BFHcharts Test
- [ ] 3.3.1 Test BFHllm standalone med BFHcharts
- [ ] 3.3.2 Dokumenter standalone usage i BFHllm README
- [ ] 3.3.3 Opret eksempel script

### 3.4 Final Cleanup
- [ ] 3.4.1 Close GitHub tracking issue
- [ ] 3.4.2 Arkiver OpenSpec change
- [ ] 3.4.3 Commit og push SPCify ændringer

---

## Critical Files

### BFHllm (New Package)
| File | Source | Description |
|------|--------|-------------|
| `R/chat.R` | New | Main `bfhllm_chat()` function |
| `R/config.R` | New | Configuration management |
| `R/provider-gemini.R` | SPCify utils_gemini_integration.R | Gemini API wrapper |
| `R/circuit-breaker.R` | SPCify utils_gemini_integration.R | Circuit breaker logic |
| `R/cache.R` | SPCify utils_ai_cache.R | Generic cache |
| `R/cache-shiny.R` | SPCify utils_ai_cache.R | Shiny adapter |
| `R/rag.R` | SPCify utils_ragnar_integration.R | RAG integration |
| `R/spc-suggestions.R` | SPCify fct_ai_improvement_suggestions.R | SPC facade |
| `inst/spc_knowledge/` | SPCify inst/spc_knowledge/ | Knowledge base |
| `inst/ragnar_store/` | SPCify inst/ragnar_store/ | RAG store |

### SPCify (Modifications)
| File | Action | Description |
|------|--------|-------------|
| `DESCRIPTION` | Modify | Add BFHllm, remove ellmer/ragnar |
| `R/utils_bfhllm_integration.R` | Create | Thin wrapper for SPCify config |
| `R/fct_ai_improvement_suggestions.R` | Modify | Call BFHllm functions |
| `R/utils_gemini_integration.R` | Delete | Moved to BFHllm |
| `R/utils_ai_cache.R` | Delete | Moved to BFHllm |
| `R/utils_ragnar_integration.R` | Delete | Moved to BFHllm |
| `inst/spc_knowledge/` | Delete | Moved to BFHllm |
| `inst/ragnar_store/` | Delete | Moved to BFHllm |

---

## Dependencies

- Phase 1 must complete before Phase 2
- Phase 2.1-2.2 must complete before Phase 2.3-2.4
- Phase 2 must complete before Phase 3
- Phase 3.1 must complete before Phase 3.2-3.3
