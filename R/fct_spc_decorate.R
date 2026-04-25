# fct_spc_decorate.R
# Plot-dekoration og metadata-udfyldning for SPC pipeline.

#' Dekorer standardiseret SPC-result med Anhoej-metadata og backend-flag
#'
#' Tjekker om BFHcharts leverede Anhoej-regler; falder ved behov tilbage til
#' qicharts2 som fallback. Saetter `metadata$backend = "bfhcharts"`.
#'
#' @param standardized list. Standardiseret result fra `execute_bfh_request()`.
#' @param prepared `spc_prepared` objekt. Bruges ved Anhoej-fallback.
#'
#' @return Opdateret `standardized` list.
#' @keywords internal
decorate_plot_for_display <- function(standardized, prepared) {
  # 7e. Anhoej metadata: brug BFHcharts' allerede beregnede metadata.
  # transform_bfh_output() udtraekker Anhoej-regler fra BFHcharts qic_data.
  # Fallback til qicharts2 kun hvis BFHcharts metadata mangler.
  if (is.null(standardized$metadata$anhoej_rules)) {
    log_warn(
      "BFHcharts Anh\u00f8j metadata mangler \u2014 falder tilbage til qicharts2",
      .context = "BFH_SERVICE"
    )
    anhoej_metadata_local <- compute_anhoej_metadata_local(
      data = prepared$data,
      config = list(
        x_col = prepared$x_var,
        y_col = prepared$y_var,
        n_col = prepared$n_var,
        chart_type = prepared$chart_type
      )
    )
    if (!is.null(anhoej_metadata_local)) {
      standardized$metadata$anhoej_rules <- list(
        runs_detected = anhoej_metadata_local$runs_signal,
        crossings_detected = anhoej_metadata_local$crossings_signal,
        longest_run = anhoej_metadata_local$longest_run,
        n_crossings = anhoej_metadata_local$n_crossings,
        n_crossings_min = anhoej_metadata_local$n_crossings_min
      )
    }
  }

  # 7g. Backend-flag til diagnostik og cache-invalidering
  standardized$metadata$backend <- "bfhcharts"

  standardized
}
