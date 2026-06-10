# ==============================================================================
# CONFIG_CHART_TYPE_GROUPS.R
# ==============================================================================
# Grupperet diagramtype-dropdown med progressiv disclosure i tre kategorier.
# Samme korttype kan optraede i flere grupper, saa hver option har en UNIK
# alias-value (fx "ip__dt") for at undgaa at selectize.js deduperer paa value.
# get_qic_chart_type() stripper aliaset tilbage til den rene qicharts2-kode
# (se config_chart_types.R: sub("__.*$", "", ...)).
#
#   Standardvalg              -> simple valg (run + anbefalet kontrolkort = ip)
#   Udvidede kontrolkortvalg  -> datatype-drevne labels (skjuler kort-navnet)
#   Avanceret kontrolkortvalg -> alle korttyper ved navn
# ==============================================================================

#' Grupperet choices-struktur til chart-type dropdown
#'
#' Named list of lists klar til selectizeInput(choices = ...). Values med
#' "__"-suffix er aliaser der peger paa samme qicharts2-kode (resolves i
#' get_qic_chart_type via sub("__.*$", "", ...)).
#' @keywords internal
#' @noRd
CHART_TYPE_GROUPS <- list(
  "Standardvalg" = list(
    "Seriediagram \u2013 udvikling over tid" = "run",
    "Kontrolkort \u2013 vurdering af variation" = "ip__ctrl"
  ),
  "Udvidede kontrolkortvalg" = list(
    "Enkeltm\u00e5linger/v\u00e6rdier \u2013 fx ventetid, blodtryk, score" = "ip__dt",
    "Procent/andele \u2013 fx andel med komplikation" = "pp__dt",
    "Rater \u2013 fx h\u00e6ndelser pr. 1000 patientdage" = "up__dt",
    "Antal/t\u00e6llinger \u2013 fx antal fald pr. m\u00e5ned" = "c__dt"
  ),
  "Avanceret kontrolkortvalg" = list(
    "I-kort \u2013 enkeltm\u00e5linger" = "i",
    "I'-kort \u2013 enkeltm\u00e5linger, varierende n\u00e6vner" = "ip",
    "P-kort \u2013 andele" = "p",
    "P'-kort \u2013 andele, standardiseret" = "pp",
    "U-kort \u2013 rater" = "u",
    "U'-kort \u2013 rater, standardiseret" = "up",
    "C-kort \u2013 t\u00e6llinger" = "c",
    "MR-kort \u2013 variation mellem m\u00e5linger" = "mr",
    "G-kort \u2013 muligheder mellem sj\u00e6ldne h\u00e6ndelser" = "g",
    "T-kort \u2013 tid mellem sj\u00e6ldne h\u00e6ndelser" = "t"
  )
)

#' Byg grupperet choices-liste til chart-type dropdown
#'
#' Returnerer den kuraterede CHART_TYPE_GROUPS-struktur. Wrapper saa UI-laget
#' kalder en funktion (fremtidssikret mod en evt. dynamisk builder).
#' @return Named list of lists klar til selectizeInput(choices = ...).
#' @keywords internal
#' @noRd
build_grouped_chart_choices <- function() {
  CHART_TYPE_GROUPS
}
