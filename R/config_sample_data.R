# ==============================================================================
# CONFIG_SAMPLE_DATA.R
# ==============================================================================
# FORMÅL: Metadata for eksempeldatasæt til dropdown-menu i trin 1.
#         Hvert entry mapper et chart type til en CSV-fil med realistiske
#         kliniske data.
#
# ANVENDES AF:
#   - UI dropdown (create_ui_upload_page)
#   - Server observer (sample data loading)
#
# RELATERET:
#   - config_chart_types.R - Chart type definitions
#   - ui_app_ui.R - Upload page UI
#   - utils_server_event_listeners.R - Sample data observer
# ==============================================================================

#' Sample Dataset Definitions
#'
#' Liste over eksempeldatasæt med metadata til dropdown-menu.
#' Hvert entry indeholder id, label, beskrivelse, filnavn og anbefalet chart type.
#'
#' @format Named list of lists
#' @keywords internal
SAMPLE_DATASETS <- list(
  list(
    id = "run",
    label = "Run \u2014 M\u00f8defremmøde procent",
    description = "M\u00f8defremmøde (mødt/tilkaldt) som procent",
    file = "sample_run.csv",
    chart_type = "run"
  ),
  list(
    id = "i",
    label = "I-kort \u2014 Operationsvarighed",
    description = "Individuelle m\u00e5linger af operationstid i minutter",
    file = "sample_i_mr.csv",
    chart_type = "i"
  ),
  # list(
  #   id = "mr",
  #   label = "MR-kort \u2014 Operationsvarighed (variation)",
  #   description = "Variation mellem p\u00e5 hinanden f\u00f8lgende operationstider",
  #   file = "sample_i_mr.csv",
  #   chart_type = "mr"
  # ),
  list(
    id = "p",
    label = "P-kort \u2014 Postoperativ infektionsrate",
    description = "Andel infektioner per antal opererede patienter",
    file = "sample_p.csv",
    chart_type = "p"
  ),
  # list(
  #   id = "pp",
  #   label = "P\u2032-kort \u2014 Tryks\u00e5rsforekomst (store n\u00e6vnere)",
  #   description = "Standardiseret andel med store, varierende n\u00e6vnere",
  #   file = "sample_pp.csv",
  #   chart_type = "pp"
  # ),
  list(
    id = "u",
    label = "U-kort \u2014 Medicineringsfejl pr. 1000",
    description = "Rate af medicineringsfejl per 1000 indl\u00e6ggelser",
    file = "sample_u.csv",
    chart_type = "u"
  ),
  # list(
  #   id = "up",
  #   label = "U\u2032-kort \u2014 Falduheld pr. 10.000 sengedage",
  #   description = "Standardiseret rate med store, varierende n\u00e6vnere",
  #   file = "sample_up.csv",
  #   chart_type = "up"
  # ),
  list(
    id = "c",
    label = "C-kort \u2014 Antal klager pr. m\u00e5ned",
    description = "T\u00e6llinger af patientklager per m\u00e5ned",
    file = "sample_c.csv",
    chart_type = "c"
  )
  # list(
  #   id = "g",
  #   label = "G-kort \u2014 Tid mellem alvorlige h\u00e6ndelser",
  #   description = "Dage mellem alvorlige utilsigtede h\u00e6ndelser",
  #   file = "sample_g.csv",
  #   chart_type = "g"
  # ),
  # list(
  #   id = "t",
  #   label = "T-kort \u2014 Tid mellem sj\u00e6ldne komplikationer",
  #   description = "Dage mellem sj\u00e6ldne komplikationer (log-transformeret)",
  #   file = "sample_t.csv",
  #   chart_type = "t"
  # )
)
