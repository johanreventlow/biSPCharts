# ==============================================================================
# CONFIG_GROUPED_DROPDOWN_MVP.R  (EKSPERIMENTEL MVP -- kan slettes)
# ==============================================================================
# Grupperet diagramtype-dropdown til demo for kolleger. Tre kategorier med
# progressiv disclosure. Samme korttype kan optraede i flere grupper, saa
# hver option har en UNIK alias-value (fx "i'__dt") for at undgaa at
# selectize.js deduperer paa value. get_qic_chart_type() stripper aliaset
# tilbage til den rene qicharts2-kode (se config_chart_types.R).
#
# Standardvalg            -> simple valg (run + anbefalet kontrolkort = i')
# Udvidede kontrolkortvalg -> datatype-drevne valg (skjuler kort-navnet)
# Avanceret kontrolkortvalg -> alle korttyper ved navn
# ==============================================================================

#' Grupperet choices-struktur til chart-type dropdown (MVP)
#'
#' Named list of lists klar til selectizeInput(choices = ...). Values med
#' "__"-suffix er aliaser der peger paa samme qicharts2-kode (resolves i
#' get_qic_chart_type via sub("__.*$", "", ...)).
#' @keywords internal
#' @noRd
CHART_TYPE_GROUPS_MVP <- list(
  "Standardvalg" = list(
    "Seriediagram – udvikling og tendenser over tid" = "run",
    "Kontrolkort – vurdering af variation" = "i'__ctrl"
  ),
  "Udvidede kontrolkortvalg" = list(
    "Enkeltmålinger/værdier – fx ventetid, blodtryk, score" = "i'__dt",
    "Procent/andele – fx andel med komplikation" = "pp__dt",
    "Rater – fx hændelser pr. 1000 patientdage" = "up__dt",
    "Antal/tællinger – fx antal fald pr. måned" = "c__dt"
  ),
  "Avanceret kontrolkortvalg" = list(
    "I-kort – enkeltmålinger" = "i",
    "I'-kort – enkeltmålinger, varierende nævner" = "i'",
    "P-kort – andele" = "p",
    "P'-kort – andele, standardiseret" = "pp",
    "U-kort – rater" = "u",
    "U'-kort – rater, standardiseret" = "up",
    "C-kort – tællinger" = "c",
    "MR-kort – variation mellem målinger" = "mr",
    "G-kort – mellem sjældne hændelser" = "g",
    "T-kort – tid mellem sjældne hændelser" = "t"
  )
)

#' Byg MVP grouped choices (returnerer den statiske struktur).
#'
#' Wrapper saa UI-laget kan kalde en funktion (parallelt med fremtidig
#' dynamisk builder). G/T inkluderes -- de renderer via BFHcharts/qicharts2.
#' @keywords internal
#' @noRd
build_grouped_chart_choices_mvp <- function() {
  CHART_TYPE_GROUPS_MVP
}
