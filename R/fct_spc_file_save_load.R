#' Fil-baseret gem og indlæs
#'
#' To rene funktioner til at skrive og læse biSPCharts Excel-filer.
#' Filen har to ark: "Data" (de rå rækker) og "Indstillinger" (alle
#' UI-indstillinger som Felt/Værdi-tabel), svarende til hvad
#' collect_metadata() returnerer.
#'
#' Hvis `qic_data` leveres, tilføjes desuden et tredje ark "SPC-analyse"
#' med pre-beregnede SPC-statistikker (centrallinje, kontrolgrænser,
#' Anhøj-regler per part, special cause-punkter). Arket er informational
#' og parses ikke af `parse_spc_excel()` — round-trip-egenskaben påvirkes
#' ikke.
#'
#' @name fct_spc_file_save_load
NULL

# Antal header-rækker i Indstillinger-arket (kommentar + tom linje).
# build_spc_excel() skriver metadata fra startRow = INDSTILLINGER_HEADER_ROWS + 1L.
# parse_spc_excel() bruger skip = INDSTILLINGER_HEADER_ROWS.
INDSTILLINGER_HEADER_ROWS <- 2L

# Sheet-navn for SPC-analyse (informational).
SPC_ANALYSIS_SHEET_NAME <- "SPC-analyse"

#' Byg biSPCharts Excel-fil med Data-, Indstillinger- og evt. SPC-analyse-ark
#'
#' @param data data.frame med brugerens data
#' @param metadata Named list svarende til collect_metadata()-output
#' @param qic_data data.frame eller NULL. Hvis ikke-NULL og indeholder
#'   gyldige rækker, tilføjes "SPC-analyse"-ark med pre-beregnede
#'   statistikker.
#' @param original_data data.frame eller NULL. Brugerens rå data; bruges
#'   til opslag af dato og notes i sektion D af SPC-analyse-arket. Kan
#'   være identisk med `data`-argumentet.
#' @param analysis_options Named list. Valgfrie inputs til
#'   `build_spc_analysis_sheet()` (fx `freeze_position`, `phase_names`,
#'   `pkg_versions`).
#' @return Karakter-streng: sti til midlertidig .xlsx-fil
#' @keywords internal
build_spc_excel <- function(data,
                            metadata,
                            qic_data = NULL,
                            original_data = NULL,
                            analysis_options = list()) {
  wb <- openxlsx::createWorkbook()

  # --- Ark 1: Data ---
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, sheet = "Data", x = data, rowNames = FALSE)

  # --- Ark 2: Indstillinger ---
  openxlsx::addWorksheet(wb, "Indstillinger")

  # Forklarende kommentar i celle A1
  kommentar <- paste0(
    "Dette ark bruges af biSPCharts til at gendanne dine indstillinger. ",
    "Du kan redigere værdierne, men undgå at slette arket."
  )
  openxlsx::writeData(wb,
    sheet = "Indstillinger",
    x = data.frame(Besked = kommentar), startRow = 1, colNames = FALSE
  )

  meta_df <- data.frame(
    Felt = names(metadata),
    Værdi = vapply(metadata, function(x) {
      if (is.null(x) || (length(x) == 0)) {
        return("")
      }
      x_clean <- x[!is.na(x)]
      if (length(x_clean) == 0) "" else paste(x_clean, collapse = ", ")
    }, character(1)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  openxlsx::writeData(wb,
    sheet = "Indstillinger",
    x = meta_df, startRow = INDSTILLINGER_HEADER_ROWS + 1L, rowNames = FALSE
  )

  # --- Ark 3: SPC-analyse (kun hvis qic_data er gyldig) ---
  if (!is.null(qic_data)) {
    safe_operation(
      operation_name = "Build SPC-analyse sheet",
      code = {
        sections <- build_spc_analysis_sheet(
          qic_data = qic_data,
          metadata = metadata,
          original_data = original_data %||% data,
          options = analysis_options
        )
        if (!is.null(sections)) {
          .write_spc_analysis_sheet(wb, sections)
          log_debug(
            .context = "EXCEL_EXPORT",
            message = "SPC-analyse-ark bygget",
            details = list(
              n_parts = nrow(sections$anhoej),
              n_obs = nrow(qic_data),
              n_special_cause = nrow(sections$special_cause)
            )
          )
        } else {
          log_warn(
            .context = "EXCEL_EXPORT",
            message = "SPC-analyse-ark sprunget over (qic_data tom eller invalid)"
          )
        }
        invisible(NULL)
      },
      fallback = function(e) {
        log_warn(
          .context = "EXCEL_EXPORT",
          message = paste("SPC-analyse-ark fejlede:", e$message),
          details = list(error = e$message)
        )
        invisible(NULL)
      },
      error_type = "processing"
    )
  }

  # Gem til temp-fil
  temp_path <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, temp_path, overwrite = TRUE)
  temp_path
}

# Skriv sektioner til "SPC-analyse"-ark med blank-rækker imellem.
# Hver sektion får sin egen header-række med sektionsnavn.
.write_spc_analysis_sheet <- function(wb, sections) {
  sheet_name <- SPC_ANALYSIS_SHEET_NAME
  openxlsx::addWorksheet(wb, sheet_name)

  current_row <- 1L

  write_section <- function(header, df) {
    openxlsx::writeData(wb,
      sheet = sheet_name,
      x = data.frame(X = header), startRow = current_row, colNames = FALSE
    )
    current_row <<- current_row + 1L
    if (nrow(df) > 0L) {
      openxlsx::writeData(wb,
        sheet = sheet_name,
        x = df, startRow = current_row, rowNames = FALSE
      )
      current_row <<- current_row + nrow(df) + 1L
    } else {
      openxlsx::writeData(wb,
        sheet = sheet_name,
        x = data.frame(X = "Ingen data"), startRow = current_row, colNames = FALSE
      )
      current_row <<- current_row + 1L
    }
    # Blank-række mellem sektioner
    current_row <<- current_row + 1L
  }

  write_section("A. Oversigt", sections$overview)
  write_section("B. Per-part statistik", sections$per_part)
  write_section("C. Anhøj-regler per part", sections$anhoej)

  # Sektion D: special-case for tom = vis besked i stedet for "Ingen data".
  openxlsx::writeData(wb,
    sheet = sheet_name,
    x = data.frame(X = "D. Special cause-punkter"),
    startRow = current_row, colNames = FALSE
  )
  current_row <- current_row + 1L
  if (nrow(sections$special_cause) > 0L) {
    openxlsx::writeData(wb,
      sheet = sheet_name,
      x = sections$special_cause, startRow = current_row, rowNames = FALSE
    )
  } else {
    openxlsx::writeData(wb,
      sheet = sheet_name,
      x = data.frame(X = "Ingen special cause-punkter detekteret"),
      startRow = current_row, colNames = FALSE
    )
  }
  invisible(NULL)
}

#' Læs Indstillinger-ark fra biSPCharts Excel-fil
#'
#' @param file_path Sti til Excel-filen
#' @return Named list svarende til collect_metadata()-output, eller NULL
#'   hvis arket mangler eller er korrupt
#' @keywords internal
parse_spc_excel <- function(file_path, sheets = NULL) {
  tryCatch(
    {
      if (is.null(sheets)) sheets <- readxl::excel_sheets(file_path)
      if (!"Indstillinger" %in% sheets) {
        return(NULL)
      }

      # skip = INDSTILLINGER_HEADER_ROWS: matcher startRow i build_spc_excel()
      raw <- suppressMessages(
        readxl::read_excel(file_path,
          sheet = "Indstillinger",
          skip = INDSTILLINGER_HEADER_ROWS, col_names = TRUE
        )
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
    },
    error = function(e) {
      log_warn(paste("Kunne ikke parse Indstillinger-ark:", e$message),
        .context = "FILE_SAVE_LOAD"
      )
      NULL
    }
  )
}
