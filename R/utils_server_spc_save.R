# utils_server_spc_save.R
#
# Faelles helpers for download af biSPCharts Excel-fil med data,
# indstillinger + SPC-analyse-ark. Genbruges af:
#   - Eksportér-trinnet ("Download kopi af data og indstillinger"-knap),
#     se utils_server_wizard_gates.R
#   - Navigation-guard-modal ("Nulstil"-flow med download-opt-in),
#     se utils_server_navigation_guard.R
#
# Begge call-sites skal levere identisk Excel-output: 3-ark (Data +
# Indstillinger + SPC-analyse) + samme filnavn-skema. Tidligere havde
# nav-guard et reduceret 2-ark-output + timestamp-filnavn, hvilket
# overraskede brugere.

#' Generer titel-baseret filnavn til biSPCharts Excel-download
#'
#' Bruger metadata$indicator_title som basis (saniteret + trunkeret til
#' 50 tegn). Falder tilbage til "data_biSPCharts.xlsx" hvis titel ej er
#' angivet eller saniteres til tom streng.
#'
#' @param app_state Hierarchical reactiveValues
#' @param input Shiny input (list eller reactivevalues, kraeves af
#'   collect_metadata)
#' @return Character — filnavn (.xlsx-suffix)
#' @keywords internal
#' @noRd
spc_save_filename <- function(app_state, input) {
  md <- collect_metadata(input, app_state)
  title <- md$indicator_title
  if (is.null(title) || !nzchar(trimws(title))) {
    return("data_biSPCharts.xlsx")
  }
  safe_title <- sanitize_filename(trimws(title))
  if (nchar(safe_title) == 0) {
    return("data_biSPCharts.xlsx")
  }
  safe_title <- stringr::str_trunc(safe_title, 50, ellipsis = "")
  paste0(safe_title, "_biSPCharts.xlsx")
}

#' Byg fuld biSPCharts Excel-fil fra current app_state
#'
#' Producerer 3-ark Excel (Data + Indstillinger + SPC-analyse) via
#' build_spc_excel(). SPC-analyse-arket bygges hvis build_export_plot()
#' kan generere qic_data; ellers logges advarsel og arket droppes
#' gracefully (build_spc_excel haandterer qic_data = NULL).
#'
#' analysis_options inkluderer pkg-versions, computed_at-tidsstempel og
#' freeze_position udledt af data + metadata$frys_column.
#'
#' @param app_state Hierarchical reactiveValues
#' @param input Shiny input (list eller reactivevalues)
#' @param file Optional path. Hvis non-NULL, kopieres genereret xlsx
#'   til denne sti (passende til downloadHandler's content-callback).
#'   Hvis NULL, returneres temp-path direkte (caller skal selv haandtere
#'   oprydning, fx via on.exit/unlink).
#' @return Character — sti til xlsx-fil. Hvis file blev sat, returneres
#'   file-argumentet; ellers returneres en temp-path.
#' @keywords internal
#' @noRd
build_spc_excel_full <- function(app_state, input, file = NULL) {
  shiny::isolate({
    data <- app_state$data$current_data
    metadata <- collect_metadata(input, app_state)

    # Hent qic_data fra senest beregnede SPC-resultat via samme pipeline
    # som UI-grafen. Fejler hvis kolonner ikke er mappet endnu (typisk
    # nav-guard-flowet hvor brugeren forlader trin 2 uden plot) — i det
    # tilfaelde droppes SPC-analyse-arket gracefully.
    qic_data <- NULL
    spc_for_export <- tryCatch(
      build_export_plot(
        app_state = app_state,
        title_input = metadata$indicator_title %||% "",
        dept_input = metadata$export_department %||% "",
        plot_context = "export_pdf"
      ),
      error = function(e) {
        log_warn(
          .context = "EXCEL_EXPORT",
          message = paste(
            "build_export_plot fejlede ved Excel-download;",
            "SPC-analyse-ark springes over:", conditionMessage(e)
          )
        )
        NULL
      }
    )
    has_qic <- !is.null(spc_for_export) && is.list(spc_for_export) &&
      !is.null(spc_for_export$qic_data)
    if (has_qic) {
      qic_data <- spc_for_export$qic_data
    }

    freeze_position <- tryCatch(
      extract_freeze_position(data, metadata$frys_column),
      error = function(e) NULL # nolint: swallowed_error_linter
    )

    analysis_options <- list(
      pkg_versions = list(
        biSPCharts = tryCatch(
          as.character(utils::packageVersion("biSPCharts")),
          error = function(e) ""
        ),
        BFHcharts = tryCatch(
          as.character(utils::packageVersion("BFHcharts")),
          error = function(e) ""
        )
      ),
      computed_at = Sys.time(),
      freeze_position = freeze_position
    )

    temp_path <- build_spc_excel(
      data = data,
      metadata = metadata,
      qic_data = qic_data,
      original_data = data,
      analysis_options = analysis_options
    )

    if (is.null(file)) {
      return(temp_path)
    }

    file.copy(temp_path, file, overwrite = TRUE)
    unlink(temp_path)
    file
  })
}

#' Byg in-memory Excel-blob (raw bytes) til nav-guard-download
#'
#' Wrapper omkring build_spc_excel_full() som returnerer raw bytes,
#' egnet til base64-encoding + sendCustomMessage("download_blob").
#'
#' @param app_state Hierarchical reactiveValues
#' @param input Shiny input
#' @return Raw bytes — XLSX file content
#' @keywords internal
#' @noRd
build_spc_excel_blob <- function(app_state, input) {
  temp_path <- build_spc_excel_full(app_state, input, file = NULL)
  on.exit(unlink(temp_path), add = TRUE)
  readBin(temp_path, what = "raw", n = file.info(temp_path)$size)
}
