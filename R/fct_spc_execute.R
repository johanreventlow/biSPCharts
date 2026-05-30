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

  # Cycle 11 H2-NEW: chart_title resolves nu i compute_spc_results_bfh()
  # FOER cache-key generation (fct_spc_bfh_facade.R). Her er extra_params$chart_title
  # garanteret resolved (string eller NULL). Kald resolve_bfh_chart_title() er
  # idempotent paa strings men bevares som defense-in-depth for andre call-paths.
  chart_title <- resolve_bfh_chart_title(extra_params$chart_title)

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
    ylim = axes$ylim,
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
  #
  # Subsample-strategi: ved >BFH_MAX_X_LABELS_TEXT labels brug
  # BFHcharts::bfh_subsample_label_indices() til at vaelge evenly-spaced
  # subset med foerste+sidste anchored. Holder labels horisontale (ingen
  # rotation) jf. user-praeference. <= maks vises alle labels horisontalt.
  #
  # Akse-linje-anker: ggplot2 4.0 capper axis.line.x ved yderste break.
  # bfh_subsample_label_indices() dropper sidste label naar (n-1) ej er
  # delelig med step (BFHcharts 0.22.1), saa axis.line ellers stopper ved
  # sidste synlige label i stedet for sidste observation. Vi tilfoejer
  # n_labels som ekstra break med tom label -> akse-linjen straekker til
  # sidste datapunkt, uden synlig tick (x-ticks blanket i theme_bfh) eller
  # ekstra label. Grid-aligned n (n_labels allerede i visible_idx) uaendret.
  x_labels_col <- paste0(".x_labels_", prepared$x_var)
  x_scale <- NULL
  x_theme <- NULL
  x_labels <- NULL
  if (x_labels_col %in% names(prepared$data)) {
    x_labels <- prepared$data[[x_labels_col]]
    n_labels <- length(x_labels)
    visible_idx <- BFHcharts::bfh_subsample_label_indices(n_labels)
    axis_breaks <- sort(unique(c(visible_idx, n_labels)))
    axis_labels <- ifelse(
      axis_breaks %in% visible_idx, x_labels[axis_breaks], ""
    )
    x_scale <- ggplot2::scale_x_continuous(
      breaks = axis_breaks,
      labels = axis_labels
    )
    x_theme <- ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 0, hjust = 0.5)
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

  # Applicer x_scale + x_theme paa BEGGE plot-objekter saa tekst-x-labels
  # (fx maanedsnavne) vises korrekt i baade analyse-view OG eksport-paths.
  #
  # standardized$plot er gg-objektet brugt af analyse-view-render.
  # standardized$bfh_qic_result$plot er det raw BFHcharts S3-objekt der bruges
  # af eksport-pipelinen (bfh_export_pdf, bfh_export_png + preview-PNG via
  # ggsave i generate_pdf_preview). Tidligere blev x_scale kun appliceret paa
  # standardized$plot -> eksport viste numerisk fallback (1,2,3,...) for
  # tekst-x i stedet for original-labels (januar, februar, ...).
  if (!is.null(x_scale)) {
    if (!is.null(standardized$plot)) {
      standardized$plot <- standardized$plot + x_scale + x_theme
    }
    if (!is.null(standardized$bfh_qic_result) &&
      !is.null(standardized$bfh_qic_result$plot)) {
      standardized$bfh_qic_result$plot <-
        standardized$bfh_qic_result$plot + x_scale + x_theme
    }
  }

  # Eksporter x_labels-vector saa eksport-callere kan forwarde til
  # BFHcharts::bfh_generate_details(x_labels = ...) og dermed faa Periode-
  # felt "januar - december" frem for "1970-01-01 - 1970-01-12".
  # NULL hvis numerisk x (ingen labels-konvertering noedvendig).
  if (!is.null(x_labels)) {
    standardized$x_labels <- x_labels
  }

  standardized
}
