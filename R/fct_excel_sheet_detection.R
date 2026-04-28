# ==============================================================================
# FCT_EXCEL_SHEET_DETECTION.R
# ==============================================================================
# FORMÅL: Pure helpers til detektion af Excel-ark og biSPCharts gem-format.
#         Anvendes af upload-observer til at afgøre om sheet-picker skal vises.
#
# ANVENDES AF:
#   - utils_server_paste_data.R (direct_file_upload observer)
#
# RELATERET:
#   - fct_file_parse_pure.R (parse_excel_file har sin egen biSPCharts-detektion)
# ==============================================================================

#' List ark i Excel-fil
#'
#' Wrapper omkring `readxl::excel_sheets()` med fejl-håndtering.
#' Returnerer NULL hvis filen er korrupt eller ikke kan læses.
#'
#' @param path Sti til Excel-fil (.xlsx eller .xls)
#'
#' @return Character vector af ark-navne, eller NULL ved fejl
#'
#' @noRd
list_excel_sheets <- function(path) {
  if (is.null(path) || !is.character(path) || length(path) != 1) {
    return(NULL)
  }
  if (!file.exists(path)) {
    return(NULL)
  }
  tryCatch(
    readxl::excel_sheets(path),
    error = function(e) {
      log_debug(
        paste("Kunne ikke læse Excel-ark:", conditionMessage(e)),
        .context = "EXCEL_SHEET_DETECTION"
      )
      NULL
    }
  )
}

#' Detekter tomme ark i Excel-fil
#'
#' Per ark: læser første række (n_max=1) og returnerer TRUE hvis ingen
#' data-rækker findes. Effektivt selv for store filer.
#'
#' @param path Sti til Excel-fil
#' @param sheets Character vector af ark-navne (typisk fra `list_excel_sheets()`)
#'
#' @return Logical vector samme længde som `sheets`. TRUE = tomt ark.
#'         Ved fejl per ark: TRUE (konservativt, signaleres som tomt).
#'
#' @noRd
detect_empty_sheets <- function(path, sheets) {
  if (is.null(path) || is.null(sheets) || length(sheets) == 0) {
    return(logical(0))
  }
  vapply(sheets, function(sheet_name) {
    tryCatch(
      {
        preview <- readxl::read_excel(
          path = path,
          sheet = sheet_name,
          n_max = 1,
          col_names = TRUE,
          .name_repair = "minimal"
        )
        nrow(preview) == 0
      },
      error = function(e) {
        log_debug(
          paste0(
            "Preflight fejlede for ark '", sheet_name, "': ",
            conditionMessage(e)
          ),
          .context = "EXCEL_SHEET_DETECTION"
        )
        TRUE
      }
    )
  }, logical(1), USE.NAMES = FALSE)
}

#' Genkend biSPCharts gem-format
#'
#' biSPCharts gem-format kræver tilstedeværelse af både `Data`- og
#' `Indstillinger`-ark. Tredje ark (fx `SPC-analyse`) er valgfrit.
#'
#' @param sheets Character vector af ark-navne
#'
#' @return TRUE hvis biSPCharts-format, ellers FALSE
#'
#' @noRd
is_bispchart_excel_format <- function(sheets) {
  if (is.null(sheets) || length(sheets) == 0) {
    return(FALSE)
  }
  "Data" %in% sheets && "Indstillinger" %in% sheets
}
