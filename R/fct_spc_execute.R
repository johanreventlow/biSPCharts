# fct_spc_execute.R
# BFHcharts-invokering for SPC pipeline.

#' Byg BFHcharts-argumenter fra forberedt SPC-data og akseconfig
#'
#' Kortlaegger `spc_prepared` og `spc_axes` til BFHcharts' `bfh_qic()`-format.
#' Anvender denominator-guard (fjerner n_var for chart-typer der ikke bruger den)
#' og konverterer chart_title via `resolve_bfh_chart_title()`. Kaster
#' `spc_render_error` ved kortlaegningsfejl.
#'
#' @param prepared `spc_prepared` objekt fra `prepare_spc_data()`.
#' @param axes `spc_axes` objekt fra `resolve_axis_units()`.
#' @param extra_params list. Ekstra parametre fra `...` (width, height, units,
#'   chart_title, chart_title_reactive).
#'
#' @return Navngivet list klar til `call_bfh_chart()`.
#' @keywords internal
build_bfh_args <- function(prepared, axes, extra_params) {
  n_var <- prepared$n_var
  y_axis_unit <- axes$y_axis_unit

  # Guard: Fjern naevner for chart types der ikke bruger den.
  # Forhindrer at BFHcharts dividerer y med n (giver alle vaerdier = 1).
  if (!is.null(n_var) && !chart_type_requires_denominator(prepared$chart_type)) {
    log_warn(
      paste(
        "n_var fjernet for chart_type=", prepared$chart_type,
        "\u2014 denne type bruger ikke n\u00e6vner (n_var var:", n_var, ")"
      ),
      .context = "BFH_SERVICE"
    )
    n_var <- NULL
    # Re-check: percent uden naevner er ugyldig
    if (identical(y_axis_unit, "percent")) {
      y_axis_unit <- "count"
    }
  }

  log_debug(
    paste(
      "Pure BFHcharts workflow parameters:",
      "chart_type =", prepared$chart_type,
      ", y_axis_unit =", y_axis_unit,
      ", n_var =", if (is.null(n_var)) "NULL" else n_var,
      ", has_target =", !is.null(axes$target_value),
      ", has_chart_title =", !is.null(extra_params$chart_title)
    ),
    .context = "BFH_SERVICE"
  )

  log_debug(
    paste(
      "[DEBUG_Y_VALUES] chart_type =", prepared$chart_type,
      "| y_axis_unit =", y_axis_unit,
      "| n_var =", if (is.null(n_var)) "NULL" else n_var,
      "| y_col =", prepared$y_var,
      "| y_class =", class(prepared$data[[prepared$y_var]])[1],
      "| y_first5 =",
      paste(head(prepared$data[[prepared$y_var]], 5), collapse = ", "),
      "| y_range =",
      paste(range(prepared$data[[prepared$y_var]], na.rm = TRUE), collapse = "-")
    ),
    .context = "BFH_SERVICE"
  )

  chart_title <- resolve_bfh_chart_title(
    extra_params$chart_title_reactive %||% extra_params$chart_title
  )

  # VIGTIGT: width/height/units forwarded til bfh_qic() for korrekt
  # label-placering (bredde-baseret skalering i BFHcharts)
  bfh_params <- map_to_bfh_params(
    data = prepared$data,
    x_var = prepared$x_var,
    y_var = prepared$y_var,
    chart_type = prepared$chart_type,
    n_var = n_var,
    cl_var = prepared$cl_var,
    freeze_var = prepared$freeze_var,
    part_var = prepared$part_var,
    notes_column = prepared$notes_column,
    target_value = axes$target_value,
    centerline_value = axes$centerline_value,
    chart_title = chart_title,
    y_axis_unit = y_axis_unit,
    target_text = axes$target_text,
    multiply = axes$multiply,
    width = extra_params$width,
    height = extra_params$height,
    units = extra_params$units,
    # Bevar base_size=14 -- uden dette aktiverer width/height
    # calculate_base_size() som giver base_size=8 (for lille)
    base_size = 14
  )

  if (is.null(bfh_params)) {
    spc_abort("Parameter mapping failed", class = "spc_render_error")
  }

  bfh_params
}

#' Kald BFHcharts og transformer output til standardiseret format
#'
#' Kalder `call_bfh_chart()` med de mappede parametre og transformer resultatet
#' via `transform_bfh_output()`. Tilfoejer tekst-labels paa x-aksen hvis x-kolonnen
#' var konverteret til numerisk sekvens (se `prepare_spc_data()`). Kaster
#' `spc_render_error` ved rendering- eller transformationsfejl.
#'
#' @param bfh_params list. Parametre fra `build_bfh_args()`.
#' @param prepared `spc_prepared` objekt (bruges til multiply, chart_type og
#'   x_labels-lookup).
#'
#' @return Standardiseret result-list med `$plot`, `$qic_data`, `$metadata`.
#' @keywords internal
execute_bfh_request <- function(bfh_params, prepared) {
  t_bfh_start <- Sys.time()
  bfh_result <- call_bfh_chart(bfh_params)
  # H8 (#454): pipeline-timing skifter fra INFO til DEBUG. Per-render-
  # timing mætter prod-logs (5-10 plots/min) og maskerer state-events.
  log_debug(
    paste(
      "Step 7c bfh_qic:",
      round(difftime(Sys.time(), t_bfh_start, units = "secs"), 2),
      "sek"
    ),
    .context = "BFH_TIMING"
  )

  if (is.null(bfh_result)) {
    spc_abort("BFHcharts rendering failed", class = "spc_render_error")
  }

  # H4 (#450): x_scale + x_theme appliceres ÉN gang efter
  # transform_bfh_output(). Tidligere appliceret to gange (her + efter
  # transform), hvilket gav duplikeret layer-objekt og bloated layer-list.
  x_labels_col <- paste0(".x_labels_", prepared$x_var)
  x_scale <- NULL
  x_theme <- NULL
  if (x_labels_col %in% names(prepared$data)) {
    x_labels <- prepared$data[[x_labels_col]]
    x_breaks <- seq_along(x_labels)
    x_scale <- ggplot2::scale_x_continuous(breaks = x_breaks, labels = x_labels)
    x_theme <- ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
    )
  }

  t_transform_start <- Sys.time()
  standardized <- transform_bfh_output(
    bfh_result = bfh_result,
    multiply = prepared$multiply,
    chart_type = prepared$chart_type,
    original_data = prepared$data,
    freeze_applied = !is.null(prepared$freeze_var) &&
      prepared$freeze_var %in% names(prepared$data)
  )
  log_debug(
    paste(
      "Step 7d transform:",
      round(difftime(Sys.time(), t_transform_start, units = "secs"), 2),
      "sek"
    ),
    .context = "BFH_TIMING"
  )

  if (is.null(standardized)) {
    spc_abort("Output transformation failed", class = "spc_render_error")
  }

  if (!is.null(x_scale) && !is.null(standardized$plot)) {
    standardized$plot <- standardized$plot + x_scale + x_theme
  }

  standardized
}
