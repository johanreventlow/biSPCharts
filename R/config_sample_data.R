# ==============================================================================
# CONFIG_SAMPLE_DATA.R
# ==============================================================================
# FORMAaL: Metadata for eksempeldatasaet til dropdown-menu i trin 1.
#         Hvert entry mapper et chart type til en CSV-fil med realistiske
#         kliniske data.
#
# ANVENDES AF:
#   - UI dropdown (create_ui_upload_page)
#   - Server observer (sample data loading)
#
# RELATERET:
#   - config_chart_types.R - Chart type definitions
#   - utils_ui_app_layout.R - Upload page UI
#   - utils_server_event_listeners.R - Sample data observer
# ==============================================================================

#' Sample Dataset Definitions
#'
#' Liste over eksempeldatasaet med metadata til dropdown-menu.
#' Hvert entry indeholder id, label, beskrivelse, filnavn og anbefalet chart type.
#'
#' @format Named list of lists
#' @keywords internal
SAMPLE_DATASETS <- list(
  list(
    id = "run",
    label = "Seriediagram: Patientfremm\u00f8de",
    description = "Andel m\u00f8dt af planlagte aftaler (m\u00f8dt/aftaler)",
    file = "sample_run.csv",
    chart_type = "run"
  ),
  list(
    id = "i",
    label = "Kontrolkort: Enkeltm\u00e5linger",
    description = "Operationsvarighed i minutter (individuelle m\u00e5linger)",
    file = "sample_i_mr.csv",
    chart_type = "ip__dt"
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
    label = "Kontrolkort: Procent/andele",
    description = "Postoperativ infektionsrate (infektioner/opererede)",
    file = "sample_p.csv",
    chart_type = "pp__dt"
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
    label = "Kontrolkort: Rater",
    description = "Medicineringsfejl pr. indl\u00e6ggelse",
    file = "sample_u.csv",
    chart_type = "up__dt"
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
    label = "Kontrolkort: Antal/t\u00e6llinger",
    description = "Antal patientklager pr. m\u00e5ned",
    file = "sample_c.csv",
    chart_type = "c__dt"
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
