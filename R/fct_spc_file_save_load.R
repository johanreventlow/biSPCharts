#' Fil-baseret gem og indlæs
#'
#' To rene funktioner til at skrive og læse biSPCharts Excel-filer.
#' Filen har to ark: "Data" (de rå rækker) og "Indstillinger" (alle
#' UI-indstillinger som Felt/Værdi-tabel), svarende til hvad
#' collect_metadata() returnerer.
#'
#' @name fct_spc_file_save_load
NULL

# Antal header-rækker i Indstillinger-arket (kommentar + tom linje).
# build_spc_excel() skriver metadata fra startRow = INDSTILLINGER_HEADER_ROWS + 1L.
# parse_spc_excel() bruger skip = INDSTILLINGER_HEADER_ROWS.
INDSTILLINGER_HEADER_ROWS <- 2L

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
    x = meta_df, startRow = INDSTILLINGER_HEADER_ROWS + 1L, rowNames = FALSE)

  # Gem til temp-fil
  temp_path <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, temp_path, overwrite = TRUE)
  temp_path
}

#' Læs Indstillinger-ark fra biSPCharts Excel-fil
#'
#' @param file_path Sti til Excel-filen
#' @return Named list svarende til collect_metadata()-output, eller NULL
#'   hvis arket mangler eller er korrupt
#' @keywords internal
parse_spc_excel <- function(file_path, sheets = NULL) {
  tryCatch({
    if (is.null(sheets)) sheets <- readxl::excel_sheets(file_path)
    if (!"Indstillinger" %in% sheets) {
      return(NULL)
    }

    # skip = INDSTILLINGER_HEADER_ROWS: matcher startRow i build_spc_excel()
    raw <- suppressMessages(
      readxl::read_excel(file_path, sheet = "Indstillinger",
        skip = INDSTILLINGER_HEADER_ROWS, col_names = TRUE)
    )

    if (ncol(raw) < 2 || nrow(raw) == 0) {
      return(NULL)
    }

    fields <- as.character(raw[[1]])
    values <- as.character(raw[[2]])
    values[is.na(values)] <- ""

    metadata <- as.list(values)
    names(metadata) <- fields

    metadata
  }, error = function(e) {
    log_warn(paste("Kunne ikke parse Indstillinger-ark:", e$message),
      .context = "FILE_SAVE_LOAD")
    NULL
  })
}
