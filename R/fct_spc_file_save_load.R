#' Fil-baseret gem og indlæs
#'
#' To rene funktioner til at skrive og læse biSPCharts Excel-filer.
#' Filen har to ark: "Data" (de rå rækker) og "Indstillinger" (alle
#' UI-indstillinger som Felt/Værdi-tabel), svarende til hvad
#' collect_metadata() returnerer.
#'
#' @name fct_spc_file_save_load
NULL

#' Byg biSPCharts Excel-fil med Data- og Indstillinger-ark
#'
#' @param data data.frame med brugerens data
#' @param metadata Named list svarende til collect_metadata()-output
#' @return Karakter-streng: sti til midlertidig .xlsx-fil
#' @keywords internal
build_spc_excel <- function(data, metadata) {
  wb <- openxlsx::createWorkbook()

  # --- Ark 1: Data ---
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, sheet = "Data", x = data, rowNames = FALSE)

  # --- Ark 2: Indstillinger ---
  openxlsx::addWorksheet(wb, "Indstillinger")

  # Forklarende kommentar i celle A1
  kommentar <- paste0(
    "Dette ark bruges af biSPCharts til at gendanne dine indstillinger. ",
    "Du kan redigere v\u00e6rdierne, men undg\u00e5 at slette arket."
  )
  openxlsx::writeData(wb, sheet = "Indstillinger",
    x = data.frame(Besked = kommentar), startRow = 1, colNames = FALSE)

  # Metadata som Felt/Vaerdi-tabel fra række 3
  meta_df <- data.frame(
    Felt   = names(metadata),
    Vaerdi = vapply(metadata, function(x) {
      if (is.null(x) || (length(x) == 0)) return("")
      x_clean <- x[!is.na(x)]
      if (length(x_clean) == 0) "" else paste(x_clean, collapse = ", ")
    }, character(1)),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, sheet = "Indstillinger",
    x = meta_df, startRow = 3, rowNames = FALSE)

  # Gem til temp-fil
  temp_path <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, temp_path, overwrite = TRUE)
  temp_path
}
