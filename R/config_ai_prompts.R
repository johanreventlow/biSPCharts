# ==============================================================================
# CONFIG_AI_PROMPTS.R
# ==============================================================================
# FORMÅL: AI prompt templates og configuration for Gemini-baserede
#         forbedringsforslag. Indeholder prompt engineering logik, chart type
#         mappings til dansk, og template interpolation.
#
# ANVENDES AF:
#   - AI suggestion service (Gemini API calls)
#   - SPC analysis module (improvement suggestions)
#
# RELATERET:
#   - inst/golem-config.yml - AI configuration settings
#   - config_chart_types.R - Chart type definitions
#   - See: .claude/epics/ai-improvement-suggestions/README.md
# ==============================================================================

# AI CONFIGURATION GETTERS ================================
# NOTE: get_ai_config() er defineret i utils_ai_cache.R for at undgå duplikering
# Den version har bedre error handling og korrekte defaults (enabled = TRUE)

# CHART TYPE MAPPING ================================

#' Map Chart Type to Danish Name
#'
#' Konverterer engelsk chart type til dansk navngivning til brug i AI prompts.
#' Understøtter alle BFHcharts chart types.
#'
#' @param chart_type Engelsk chart type (fx "run", "p", "c")
#' @return Dansk chart type navn (fx "serieplot (run chart)")
#' @keywords internal
map_chart_type_to_danish <- function(chart_type) {
  mapping <- list(
    "run" = "serieplot (run chart)",
    "i" = "I-chart (individuelle værdier)",
    "mr" = "MR-chart (moving range)",
    "xbar" = "X-bar chart (gennemsnit)",
    "s" = "S-chart (standardafvigelse)",
    "t" = "T-chart (tid mellem events)",
    "p" = "P-chart (andel)",
    "pp" = "PP-chart (andel per periode)",
    "c" = "C-chart (antal events)",
    "u" = "U-chart (rate per enhed)",
    "g" = "G-chart (events mellem)",
    "prime" = "Prime chart"
  )

  danish_name <- mapping[[tolower(chart_type)]]

  if (is.null(danish_name)) {
    log_warn(
      message = "Unknown chart type",
      .context = "AI_CONFIG",
      details = list(chart_type = chart_type)
    )
    return(chart_type) # Fallback til engelsk
  }

  return(danish_name)
}

# PROMPT TEMPLATES ================================

#' Get Improvement Suggestion Prompt Template
#'
#' Returnerer det fulde prompt template til Gemini API med placeholders for
#' SPC metadata og analyse resultater. Templatet er designet til at generere
#' korte, handlingsorienterede forbedringsforslag på dansk.
#'
#' @return Character string med prompt template indeholdende placeholders
#' @examples
#' template <- get_improvement_suggestion_template()
#' prompt <- interpolate_prompt(template, list(
#'   data_definition = "Medicineringsfejl",
#'   chart_type_dansk = "P-chart (andel)",
#'   n_points = 24
#' ))
#' @export
get_improvement_suggestion_template <- function() {
  template <- "
Du er en ekspert i Statistical Process Control (SPC) og klinisk kvalitetsforbedring. Du vurderer SPC-processer efter Anhøj-reglerne.

Baseret på følgende SPC-data, skal du generere en kort positivt og handlingsorienteret analyse af et seriediagram (max 350 tegn) på dansk. Formater target_values i samme enhed som y_axis_unit.

KONTEKST:
- Indikator: {data_definition}
- Titel: {chart_title}
- Enhed: {y_axis_unit}
- Chart type: {chart_type_dansk}
- Antal observationer: {n_points}
- Periode: {start_date} til {end_date}
- Target: {target_value}
- Centerline: {centerline}

SPC ANALYSE:
- Proces varierer {process_variation}
- Antal særligt afvigende punkter: {signals_detected}
- Længste serie: {longest_run} punkter (forventet: {longest_run_max})
- Antal krydsninger: {n_crossings} (forventet: {n_crossings_min})
- Niveau vs. mål: {target_comparison}

STRUKTUR (følg dette format):
1. Start med kontekst (fx \"Mere end X gange om måneden...\")
2. Beskriv processens variation (naturlig/ikke-naturlig, særlige punkter)
3. Forhold til mål (over/under/ved)
4. Konkret forslag markeret med **fed** (fx \"**Identificér årsager...**\")

EKSEMPEL:
\"Mere end 35.000 gange om måneden administreres medicin ikke korrekt. Processen varierer ikke naturligt, og indeholder 3 særligt afvigende målepunkter. Niveauet er under målet. Forslag: **Identificér årsager bag de afvigende målepunkter**, og understøt faktorer der kan forbedre målopfyldelsen. Stabilisér processen når niveauet er tilfredsstillende.\"


VIGTIGE REGLER:
- Maksimalt 350 tegn
- Dansk sprog
- Konkret og handlingsorienteret
- Brug fed (**tekst**) til forslag, men vær selektiv - kun 1-2 forslag, max 3 i sjældnere tilfælde.
- Fokusér på forbedringsmuligheder
- Undgå teknisk jargon - men hold professionel distance
"

  return(template)
}


# PROMPT INTERPOLATION ================================

#' Interpolate Prompt Template with Data
#'
#' Erstatter placeholders i prompt template med faktiske værdier fra SPC analyse.
#' Håndterer NULL/NA værdier ved at indsætte "Ikke angivet".
#'
#' @param template Character string med placeholders på formen {placeholder_name}
#' @param data Named list med værdier der skal interpoleres
#' @return Character string med fuldt interpoleret prompt
#' @examples
#' template <- "Chart: {chart_type}, Points: {n_points}"
#' prompt <- interpolate_prompt(template, list(
#'   chart_type = "run",
#'   n_points = 24
#' ))
#' @keywords internal
interpolate_prompt <- function(template, data) {
  prompt <- template

  for (key in names(data)) {
    placeholder <- paste0("{", key, "}")
    raw_value <- data[[key]]

    # Håndter NULL/NA værdier først, før konvertering
    if (is.null(raw_value) || length(raw_value) == 0) {
      value <- "Ikke angivet"
    } else {
      value <- as.character(raw_value)
      if (is.na(value) || value == "") {
        value <- "Ikke angivet"
      }
    }

    prompt <- gsub(placeholder, value, prompt, fixed = TRUE)
  }

  # Tjek for resterende placeholders (indikerer manglende data)
  remaining <- stringr::str_extract_all(prompt, "\\{[^}]+\\}")[[1]]
  if (length(remaining) > 0) {
    log_warn(
      message = "Prompt has unfilled placeholders",
      .context = "AI_CONFIG",
      details = list(placeholders = paste(remaining, collapse = ", "))
    )
  }

  return(prompt)
}
