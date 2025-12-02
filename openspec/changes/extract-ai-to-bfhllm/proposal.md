# extract-ai-to-bfhllm

## Why

SPCify's AI/LLM-funktionalitet er i dag tæt koblet til Shiny-applikationen. Udskillelse til en separat pakke (BFHllm) muliggør:

1. **Genbrug med BFHcharts standalone** - Brugere kan generere AI-drevne forbedringsforslag direkte fra BFHcharts uden SPCify
2. **Fremtidige applikationer** - Email-generering, rapportskrivning og anden tekstgenerering
3. **Renere separation of concerns** - LLM-integration adskilt fra SPC-applikationslogik
4. **Uafhængig test og versionering** - BFHllm kan versioneres og testes separat

**Nuværende situation:**
- ~1200 linjer AI-relateret kode spredt over 5 filer i SPCify
- Direkte afhængighed af `ellmer` og `ragnar` i SPCify
- RAG knowledge store bundled i SPCify
- Ikke muligt at bruge AI-funktionalitet uden SPCify

## What Changes

### Ny pakke: BFHllm

**Repository:** `johanreventlow/BFHllm`
**Lokal sti:** `~/Documents/R/BFHllm`

**Core funktionalitet:**
- `bfhllm_chat()` - Generisk LLM chat interface
- `bfhllm_chat_with_rag()` - RAG-enhanced chat
- `bfhllm_spc_suggestion()` - SPC-specifik forbedringsforslag facade
- Circuit breaker, caching, response validation

**Dependencies:**
- ellmer (>= 0.2.0) - Gemini API client
- ragnar (>= 0.1.0) - RAG knowledge store
- digest - Cache keys
- stringr - String manipulation

### SPCify ændringer

**Fjernes:**
- `R/utils_gemini_integration.R`
- `R/utils_ai_cache.R`
- `R/utils_ragnar_integration.R`
- `R/config_ai_prompts.R` (delvist)
- `inst/spc_knowledge/`
- `inst/ragnar_store/`
- `data-raw/build_ragnar_store.R`

**Opdateres:**
- `R/fct_ai_improvement_suggestions.R` → kalder `BFHllm::bfhllm_spc_suggestion()`
- `R/mod_export_server.R` → bruger BFHllm cache
- `DESCRIPTION` → tilføjer BFHllm, fjerner ellmer/ragnar

**Ny fil:**
- `R/utils_bfhllm_integration.R` - Tynd wrapper til SPCify-specifik konfiguration

## Impact

**Affected code:**
- 5 R-filer fjernes fra SPCify (~1200 linjer)
- 2 inst/ mapper flyttes til BFHllm
- 2 R-filer opdateres i SPCify
- 1 ny integration fil oprettes

**User-visible changes:**
- Ingen - intern refaktorering
- Ny mulighed: Standalone brug med BFHcharts

**Breaking changes:**
- SPCify kræver nu BFHllm (>= 0.1.0) som dependency

**New package:**
- BFHllm v0.1.0 udgives på GitHub

## Alternatives Considered

**Alternative 1: Behold alt i SPCify**
```r
# Nuværende struktur
SPCify::generate_improvement_suggestion(spc_result, context)
```
**Afvist fordi:**
- Forhindrer standalone brug med BFHcharts
- Tight coupling til Shiny-kontekst
- Svært at genbruge til andre formål

**Alternative 2: Udskil kun Gemini-wrapper**
```r
# Minimal extraction
BFHllm::call_gemini(prompt)
# RAG og SPC-logik forbliver i SPCify
```
**Afvist fordi:**
- RAG og SPC-specifik logik er tæt koblet
- Halvt udskilt løsning giver kompleksitet
- Genbrug med BFHcharts kræver stadig SPCify

**Valgt tilgang: Komplet udskillelse inkl. RAG og SPC-modul**
- Fuldt selvstændig pakke
- Kan bruges med BFHcharts uden SPCify
- Fremtidssikret til andre tekstgenereringsformål

## Related

- **SPCify issue:** #99
- **BFHllm repository:** https://github.com/johanreventlow/BFHllm
- **Plan fil:** ~/.claude/plans/vast-watching-candy.md
