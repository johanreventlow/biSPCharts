# AI/LLM Integration (BFHllm)

biSPCharts = **thin wrapper** omkring BFHllm-pakken (v0.1.1, `Suggests +
Remotes`, ej krævet for minimal-install).

## Lag

- `R/fct_ai_improvement_suggestions.R` — facade + input validering
- `R/utils_bfhllm_integration.R` — biSPCharts-config for BFHllm
- `BFHllm` package — RAG, LLM-calls, caching, prompts, knowledge base

## Public API (uændret for brugere)

```r
suggestion <- generate_improvement_suggestion(
  spc_result = spc_result,
  context = list(data_definition = "...", chart_title = "...",
                 y_axis_unit = "dage", target_value = 30),
  session = session,  # required for caching
  max_chars = 350
)
```

## Graceful degradation

BFHllm unavailable → NULL + log warning. RAG-fejl → fortsæt uden RAG.
API-fejl → NULL via `safe_operation`.

## Konfiguration

`inst/golem-config.yml` `ai:` + `rag:` sektion. Init via
`initialize_bfhllm(get_ai_config(), get_rag_config())` i `run_app.R`.

## Knowledge base

Live i BFHllm-repo (`inst/spc_knowledge/`). Update-flow:
1. Edit i BFHllm
2. Rebuild ragnar store
3. Bump biSPCharts DESCRIPTION `BFHllm (>= ...)`

## Reference

- BFHllm package docs: https://github.com/johanreventlow/BFHllm
- ADR-016
- Issue #100
