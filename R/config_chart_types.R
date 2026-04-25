# ==============================================================================
# CONFIG_CHART_TYPES.R
# ==============================================================================
# FORMAaL: SPC chart type definitions og mappings mellem danske UI labels og
#         engelske qicharts2-koder. Centraliserer chart type logik og
#         beskrivelser.
#
# ANVENDES AF:
#   - UI dropdowns (chart type selection)
#   - Plot generation (qicharts2::qic interface)
#   - Input validation (chart type -> naevner relevans)
#
# RELATERET:
#   - config_spc_config.R - Y-axis units og SPC validation
#   - fct_spc_plot_generation.R - Plot rendering
#   - See: docs/CONFIGURATION.md for complete guide
# ==============================================================================

# DIAGRAM TYPER ================================

## Dansk oversaettelse af chart typer -----

#' Danish Chart Type Names
#'
#' Mapping mellem danske UI labels og engelske qicharts2 koder.
#'
#' @format Named list med dansk label -> engelsk kode
#' @keywords internal
CHART_TYPES_DA <- list(
  "Seriediagram (Run) \u2014 data over tid" = "run",
  "I-kort \u2014 enkelte m\u00e5linger (fx ventetid, temperatur)" = "i",
  # "MR-kort \u2014 variation mellem m\u00e5linger" = "mr",
  "P-kort \u2014 andele/procenter (fx infektionsrate)" = "p",
  # "P\u2032-kort \u2014 andele, standardiseret" = "pp",
  "U-kort \u2014 rater (fx komplikationer pr. 1000)" = "u",
  # "U\u2032-kort \u2014 rater, standardiseret" = "up",
  "C-kort \u2014 t\u00e6llinger (fx antal fald)" = "c"
  # "G-kort \u2014 tid mellem sj\u00e6ldne h\u00e6ndelser" = "g",
  # "T-kort \u2014 tid mellem sj\u00e6ldne komplikationer" = "t"
)

## Omvendt mapping til engelske koder -----
CHART_TYPES_EN <- list(
  "run" = "run",
  "i" = "i",
  # "mr" = "mr",
  "p" = "p",
  # "pp" = "pp",
  "u" = "u",
  # "up" = "up",
  "c" = "c"
  # "g" = "g",
  # "t" = "t"
)

## Understoettede chart types (single source of truth) -----
## Typer der kan renderes af BFHcharts og er tilgaengelige i UI
SUPPORTED_CHART_TYPES <- unname(unlist(CHART_TYPES_EN))

## Alle BFHcharts-kendte typer (inkl. typer der endnu ikke har UI-support)
SUPPORTED_CHART_TYPES_BFH <- c(SUPPORTED_CHART_TYPES, "xbar", "s")

## Hjaelpefunktion til konvertering -----

#' Convert Danish Chart Type Names to QIC Codes
#'
#' Konverterer danske displaynavne til engelske qicharts2-koder for plot generation.
#'
#' @param danish_selection Valgt chart type (dansk label eller engelsk kode)
#' @return Engelsk qicharts2 kode (fx "i", "run", "p")
#' get_qic_chart_type("I-kort -- enkelte maalinger") # Returns "i"
#' get_qic_chart_type("i") # Returns "i" (already English)
#' @keywords internal
get_qic_chart_type <- function(danish_selection) {
  if (is.null(danish_selection) || danish_selection == "") {
    return("run") # standard
  }

  # Hvis det allerede er en engelsk kode, returner som-den-er
  if (danish_selection %in% unlist(CHART_TYPES_EN)) {
    return(danish_selection)
  }

  # Find mapping fra dansk til engelsk
  for (da_name in names(CHART_TYPES_DA)) {
    if (da_name == danish_selection) {
      return(CHART_TYPES_DA[[da_name]])
    }
  }

  # Fallback
  return("run")
}

## Chart type beskrivelser -----

#' Chart Type Descriptions
#'
#' Danske beskrivelser af hver chart type til UI help-tekst.
#'
#' @format Named list med engelsk kode -> dansk beskrivelse
#' @keywords internal
CHART_TYPE_DESCRIPTIONS <- list(
  "run" = "Seriediagram der viser data over tid med median centerlinje",
  "i" = "I-kort til individuelle m\u00e5linger",
  "mr" = "Moving Range kort til variabilitet mellem p\u00e5 hinanden f\u00f8lgende m\u00e5linger",
  "p" = "P-kort til andele og procenter",
  "pp" = "P'-kort til standardiserede andele",
  "u" = "U-kort til rater og h\u00e6ndelser per enhed",
  "up" = "U'-kort til standardiserede rater",
  "c" = "C-kort til t\u00e6llinger af defekter eller h\u00e6ndelser",
  "g" = "G-kort til tid mellem sj\u00e6ldne h\u00e6ndelser",
  "t" = "T-kort til tid mellem sj\u00e6ldne komplikationer (log-transformeret)"
)

#' Kraever diagramtype en naevner (n)?
#'
#' Hjaelper der afgoer om naevner-feltet (n_column) er relevant for den valgte
#' diagramtype. Bruges til at styre UI (enable/disable) og til at undlade at
#' sende `n` til qicharts2 for irrelevante typer.
#'
#' Accepter baade danske labels og engelske qicharts2-koder.
#'
#' @param chart_type Valgt diagramtype (dansk label eller engelsk kode)
#' @return TRUE hvis naevner er relevant (skal vaere aktiv i UI), ellers FALSE
chart_type_requires_denominator <- function(chart_type) {
  # Normaliser til qicharts2-kode
  ct <- get_qic_chart_type(chart_type)

  # Naevner er relevant for run, p, pp, u, up
  return(ct %in% c("run", "p", "pp", "u", "up"))
}
