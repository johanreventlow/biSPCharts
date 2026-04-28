# Programmatiske fixtures til test-fct_spc_excel_analysis.R
# Bruger qicharts2::qic() til at generere autentiske qic_data-strukturer.
# Hvis qicharts2 ikke er tilgaengelig, returneres syntetiske
# data.frames der efterligner kontrakten.

# Helper: simpel kontrol-chart-fixture med 3 parts (P-chart-lignende)
fixture_qic_data_3_parts <- function() {
  # Simulerer qic_data med 12 obs, 3 parts a 4 obs hver.
  # Part 1 har lang serie over CL (runs.signal = TRUE).
  # Part 2 er stabil.
  # Part 3 har out-of-limits og faa kryds.
  data.frame(
    x = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    y = c(0.08, 0.09, 0.10, 0.11, 0.05, 0.04, 0.05, 0.06, 0.02, 0.03, 0.15, 0.04),
    cl = c(rep(0.045, 4), rep(0.05, 4), rep(0.05, 4)),
    ucl = c(rep(0.10, 4), rep(0.08, 4), rep(0.10, 4)),
    lcl = c(rep(0.01, 4), rep(0.02, 4), rep(0.01, 4)),
    part = c(rep(1L, 4), rep(2L, 4), rep(3L, 4)),
    runs.signal = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
    n.crossings = c(rep(0, 4), rep(2, 4), rep(0, 4)),
    n.crossings.min = c(rep(1, 4), rep(1, 4), rep(2, 4)),
    longest.run = c(rep(8, 4), rep(2, 4), rep(3, 4)),
    longest.run.max = c(rep(5, 4), rep(5, 4), rep(5, 4)),
    stringsAsFactors = FALSE
  )
}

# Run-chart fixture: ingen ucl/lcl-kolonner.
fixture_qic_data_run_chart <- function() {
  data.frame(
    x = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 6),
    y = c(10, 12, 11, 14, 13, 15),
    cl = rep(12.5, 6),
    runs.signal = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
    n.crossings = rep(2, 6),
    n.crossings.min = rep(1, 6),
    longest.run = rep(2, 6),
    longest.run.max = rep(5, 6),
    stringsAsFactors = FALSE
  )
}

# Tids-y-akse fixture: vaerdier i kanoniske minutter, UI-enhed "time_hours".
# CL = 150 minutter -> 2.5 timer i UI-enhed.
fixture_qic_data_time_hours <- function() {
  data.frame(
    x = seq.Date(as.Date("2024-01-01"), by = "day", length.out = 5),
    y = c(120, 140, 160, 180, 130), # minutter
    cl = rep(150, 5),
    ucl = rep(200, 5),
    lcl = rep(100, 5),
    part = rep(1L, 5),
    runs.signal = c(FALSE, FALSE, FALSE, FALSE, FALSE),
    n.crossings = rep(2, 5),
    n.crossings.min = rep(1, 5),
    longest.run = rep(2, 5),
    longest.run.max = rep(4, 5),
    stringsAsFactors = FALSE
  )
}

# Original_data fixture med kommentar- og naevner-kolonner (matcher
# fixture_qic_data_3_parts dvs. 12 raekker).
fixture_original_data_3_parts <- function() {
  data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    Antal = c(8, 9, 10, 11, 5, 4, 5, 6, 2, 3, 15, 4),
    Patienter = rep(100, 12),
    Kommentar = c(
      "", "", "Personalemangel", "",
      "", "", "", "",
      "", "", "Influenza-udbrud", ""
    ),
    stringsAsFactors = FALSE
  )
}

# Metadata fixture matchende collect_metadata-output for 3-parts P-chart.
fixture_metadata_3_parts <- function() {
  list(
    chart_type = "p",
    target_value = "0.05",
    centerline_value = "",
    y_axis_unit = "count",
    x_column = "Dato",
    y_column = "Antal",
    n_column = "Patienter",
    skift_column = "",
    frys_column = "",
    kommentar_column = "Kommentar",
    indicator_title = "Test-indikator",
    indicator_description = "",
    unit_type = "",
    unit_select = "",
    unit_custom = ""
  )
}

# Metadata for tids-y-akse-fixture (timer)
fixture_metadata_time_hours <- function() {
  list(
    chart_type = "i",
    target_value = "",
    centerline_value = "",
    y_axis_unit = "time_hours",
    x_column = "Dato",
    y_column = "Ventetid",
    n_column = "",
    skift_column = "",
    frys_column = "",
    kommentar_column = "",
    indicator_title = "Ventetid",
    indicator_description = "",
    unit_type = "",
    unit_select = "",
    unit_custom = ""
  )
}
