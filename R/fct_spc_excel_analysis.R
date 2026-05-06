# fct_spc_excel_analysis.R
# Pure builders til "SPC-analyse"-arket i biSPCharts Excel-export.
#
# Arket er informational (ikke round-trip-able) og indeholder fire sektioner:
#   A. Oversigt: charttype, N obs, parts, freeze, target, ooc, dansk tolkning
#   B. Per-part statistik: CL/UCL/LCL/Mean/Median per part
#   C. Anhoej-regler per part: serielaengde, kryds, signaler, dansk tolkning
#   D. Special cause-punkter: ooc-raekker + runs.signal-raekker
#
# Alle builders er rene: ingen Shiny-afhaengighed, ingen app_state-reads,
# ingen side-effekter. Output er data.frames (orkestratoren returnerer
# named list); skrivning til workbook haandteres af build_spc_excel().

#' Builders til SPC-analyse-arket i Excel-export
#'
#' @name fct_spc_excel_analysis
#' @keywords internal
NULL

# Hjaelpere ====================================================================

# Sikker scalar-extract: returner enkeltvaerdi eller default hvis NULL/tom.
.excel_scalar <- function(x, default = NA) {
  if (is.null(x) || length(x) == 0L) {
    return(default)
  }
  x[[1]]
}

# Konverter numerisk vaerdi i kanoniske minutter til UI-enhed.
# Hvis y_axis_unit ikke er en tids-enhed, returneres input uaendret.
.excel_to_ui_unit <- function(value, y_axis_unit) {
  if (is.null(value) || length(value) == 0L || all(is.na(value))) {
    return(value)
  }
  format_time_from_minutes(value, target_unit = y_axis_unit)
}

# Dansk label til y-akse-enhed (tom hvis count/non-time)
.excel_unit_label <- function(y_axis_unit) {
  switch(y_axis_unit %||% "count",
    time_minutes = "minutter",
    time_hours = "timer",
    time_days = "dage",
    ""
  )
}

# Header-suffix til kolonner med enhed: "(cl, timer)" eller "(cl)" hvis count.
.excel_unit_suffix <- function(qic_field, y_axis_unit) {
  unit_label <- .excel_unit_label(y_axis_unit)
  if (nzchar(unit_label)) {
    paste0("(", qic_field, ", ", unit_label, ")")
  } else {
    paste0("(", qic_field, ")")
  }
}

# Dansk label til chart_type-kode
.excel_chart_type_da <- function(chart_type) {
  switch(chart_type %||% "run",
    run = "Seriediagram (run)",
    i = "I-kort",
    mr = "MR-kort",
    p = "P-kort",
    pp = "P'-kort",
    u = "U-kort",
    up = "U'-kort",
    c = "C-kort",
    g = "G-kort",
    t = "T-kort",
    chart_type
  )
}

# Returner hvilke raekke-indekser der har out-of-limits-signal.
.excel_ooc_rows <- function(qic_data) {
  if (nrow(qic_data) == 0L) {
    return(integer(0))
  }
  has_ucl <- "ucl" %in% names(qic_data)
  has_lcl <- "lcl" %in% names(qic_data)
  has_y <- "y" %in% names(qic_data)
  if (!has_y || (!has_ucl && !has_lcl)) {
    return(integer(0))
  }
  y <- qic_data$y
  above <- if (has_ucl) !is.na(qic_data$ucl) & !is.na(y) & y > qic_data$ucl else logical(nrow(qic_data))
  below <- if (has_lcl) !is.na(qic_data$lcl) & !is.na(y) & y < qic_data$lcl else logical(nrow(qic_data))
  which(above | below)
}

# Saml dansk tolkning paa tvaers af parts.
.excel_overall_anhoej_da <- function(anhoej_per_part) {
  if (length(anhoej_per_part) == 0L) {
    return("Ingen Anh\u00f8j-beregning tilg\u00e6ngelig")
  }
  any_runs <- any(vapply(anhoej_per_part, function(p) isTRUE(p$runs_signal), logical(1)))
  any_cross <- any(vapply(anhoej_per_part, function(p) isTRUE(p$crossings_signal), logical(1)))
  interpret_anhoej_signal_da(list(runs_signal = any_runs, crossings_signal = any_cross))
}

# Hent dato for en given raekke fra original_data (hvis tilgaengelig).
.excel_date_for_row <- function(original_data, row_idx, x_column = NULL) {
  if (is.null(original_data) || row_idx > nrow(original_data) || row_idx < 1L) {
    return(NA_character_)
  }
  if (!is.null(x_column) && x_column %in% names(original_data)) {
    val <- original_data[[x_column]][row_idx]
    if (inherits(val, "Date") || inherits(val, "POSIXct")) {
      return(format(val, "%Y-%m-%d"))
    }
    return(as.character(val))
  }
  NA_character_
}

# SECTION A: OVERSIGT ==========================================================

#' Byg sektion A (Oversigt) til SPC-analyse-arket
#'
#' @param qic_data data.frame. SPC-resultat fra `compute_spc_results_bfh()`.
#' @param metadata named list. Output fra `collect_metadata()`.
#' @param anhoej_per_part list. Output fra `derive_anhoej_per_part()`.
#' @param y_axis_unit Character. UI-valgt y-akse-enhed (fx "time_hours").
#' @param freeze_position Integer eller NULL. Raekke-indeks for freeze-punkt.
#' @param computed_at POSIXct. Beregningsdato.
#' @param pkg_versions named list. Pakke-versioner (fx `list(biSPCharts = "0.x")`).
#' @return data.frame med kolonner `Felt` og `Vaerdi`.
#' @keywords internal
build_overview_section <- function(qic_data,
                                   metadata,
                                   anhoej_per_part,
                                   y_axis_unit = "count",
                                   freeze_position = NULL,
                                   computed_at = Sys.time(),
                                   pkg_versions = list()) {
  stopifnot(is.data.frame(qic_data))
  stopifnot(is.list(metadata))

  chart_type <- .excel_scalar(metadata$chart_type, default = "run")
  n_parts <- length(anhoej_per_part)
  if (n_parts == 0L) n_parts <- 1L

  target_input <- .excel_scalar(metadata$target_value, default = "")
  has_target <- nzchar(as.character(target_input))
  target_canonical <- if (has_target) {
    suppressWarnings(parse_time_to_minutes(target_input, input_unit = y_axis_unit))
  } else {
    NA_real_
  }
  target_ui <- if (!is.na(target_canonical)) .excel_to_ui_unit(target_canonical, y_axis_unit) else NA_real_

  # Delta til CL: brug CL fra foerste part som reference (eller hver part i sektion B).
  first_cl <- if ("cl" %in% names(qic_data) && nrow(qic_data) > 0L) {
    .excel_to_ui_unit(qic_data$cl[1], y_axis_unit)
  } else {
    NA_real_
  }
  delta_cl <- if (has_target && !is.na(target_ui) && !is.na(first_cl)) {
    target_ui - first_cl
  } else {
    NA_real_
  }

  ooc_rows <- .excel_ooc_rows(qic_data)
  ooc_text <- if (length(ooc_rows) == 0L) "" else paste(ooc_rows, collapse = ", ")

  freeze_baseline_text <- ""
  if (!is.null(freeze_position) && !is.na(freeze_position) && freeze_position >= 1L &&
    freeze_position <= nrow(qic_data) && all(c("cl", "ucl", "lcl") %in% names(qic_data))) {
    cl_f <- .excel_to_ui_unit(qic_data$cl[freeze_position], y_axis_unit)
    ucl_f <- .excel_to_ui_unit(qic_data$ucl[freeze_position], y_axis_unit)
    lcl_f <- .excel_to_ui_unit(qic_data$lcl[freeze_position], y_axis_unit)
    freeze_baseline_text <- sprintf(
      "CL=%s, UCL=%s, LCL=%s",
      format(cl_f, digits = 4),
      if (is.na(ucl_f)) "" else format(ucl_f, digits = 4),
      if (is.na(lcl_f)) "" else format(lcl_f, digits = 4)
    )
  }

  unit_label <- .excel_unit_label(y_axis_unit)
  fallback_unit <- as.character(.excel_scalar(metadata$unit_select, default = ""))
  if (is.null(fallback_unit) || is.na(fallback_unit)) fallback_unit <- ""
  unit_display <- if (nzchar(unit_label)) unit_label else fallback_unit

  bispc_ver <- as.character(.excel_scalar(pkg_versions$biSPCharts, default = ""))
  bfhc_ver <- as.character(.excel_scalar(pkg_versions$BFHcharts, default = ""))

  fields <- c(
    "Charttype",
    "Antal observationer",
    "Antal parts",
    "Frozen til r\u00e6kke",
    "Y-akse-enhed",
    "Target",
    "Delta til CL (target - CL part 1)",
    "Out-of-control r\u00e6kker",
    "Freeze-baseline (CL/UCL/LCL ved freeze)",
    "Samlet Anh\u00f8j-tolkning",
    "Beregningsdato",
    "biSPCharts-version",
    "BFHcharts-version"
  )
  values <- c(
    .excel_chart_type_da(chart_type),
    as.character(nrow(qic_data)),
    as.character(n_parts),
    if (is.null(freeze_position) || is.na(freeze_position)) "" else as.character(freeze_position),
    unit_display,
    if (is.na(target_ui)) "" else format(target_ui, digits = 4),
    if (is.na(delta_cl)) "" else format(delta_cl, digits = 4),
    ooc_text,
    freeze_baseline_text,
    .excel_overall_anhoej_da(anhoej_per_part),
    format(computed_at, "%Y-%m-%d %H:%M:%S"),
    bispc_ver,
    bfhc_ver
  )

  df <- data.frame(Felt = fields, Vaerdi = values, check.names = FALSE)
  names(df)[2] <- "V\u00e6rdi"
  df
}

# SECTION B: PER-PART STATISTIK ================================================

#' Byg sektion B (Per-part statistik) til SPC-analyse-arket
#'
#' @param qic_data data.frame.
#' @param y_axis_unit Character.
#' @param target_value Numeric eller NULL. Target i UI-enhed (eller character).
#' @param phase_names Character vektor eller NULL. Hvis sat skal laengden matche
#'   antal parts.
#' @return data.frame med en raekke per part.
#' @keywords internal
build_per_part_section <- function(qic_data,
                                   y_axis_unit = "count",
                                   target_value = NULL,
                                   phase_names = NULL) {
  stopifnot(is.data.frame(qic_data))
  unit_suffix_cl <- .excel_unit_suffix("cl", y_axis_unit)
  unit_suffix_ucl <- .excel_unit_suffix("ucl", y_axis_unit)
  unit_suffix_lcl <- .excel_unit_suffix("lcl", y_axis_unit)
  unit_label <- .excel_unit_label(y_axis_unit)
  mean_label <- if (nzchar(unit_label)) sprintf("Mean (%s)", unit_label) else "Mean"
  median_label <- if (nzchar(unit_label)) sprintf("Median (%s)", unit_label) else "Median"
  target_label <- if (nzchar(unit_label)) sprintf("Target (%s)", unit_label) else "Target"
  delta_label <- if (nzchar(unit_label)) sprintf("Delta til CL (%s)", unit_label) else "Delta til CL"

  empty_df <- data.frame(
    Part = integer(0),
    `Phase-navn` = character(0),
    Fra_raekke = integer(0),
    Til_raekke = integer(0),
    N = integer(0),
    Centrallinje = numeric(0),
    Oevre_graense = numeric(0),
    Nedre_graense = numeric(0),
    Mean = numeric(0),
    Median = numeric(0),
    Target = numeric(0),
    `Delta til CL` = numeric(0),
    check.names = FALSE
  )
  names(empty_df) <- c(
    "Part", "Phase-navn", "Fra (r\u00e6kke)", "Til (r\u00e6kke)", "N",
    paste("Centrallinje", unit_suffix_cl),
    paste("\u00d8vre gr\u00e6nse", unit_suffix_ucl),
    paste("Nedre gr\u00e6nse", unit_suffix_lcl),
    mean_label, median_label, target_label, delta_label
  )

  if (nrow(qic_data) == 0L) {
    return(empty_df)
  }

  # Resolve target i UI-enhed (numerisk)
  target_ui <- NA_real_
  if (!is.null(target_value) && length(target_value) > 0L) {
    raw <- target_value[[1]]
    if (is.numeric(raw)) {
      target_ui <- raw
    } else if (is.character(raw) && nzchar(raw)) {
      canonical <- suppressWarnings(parse_time_to_minutes(raw, input_unit = y_axis_unit))
      target_ui <- .excel_to_ui_unit(canonical, y_axis_unit)
    }
  }

  # Bestem parts (samme algoritme som derive_anhoej_per_part)
  if (!"part" %in% names(qic_data) || all(is.na(qic_data$part))) {
    parts <- 1L
    part_groups <- list(seq_len(nrow(qic_data)))
  } else {
    parts <- unique(qic_data$part[!is.na(qic_data$part)])
    part_groups <- lapply(parts, function(p) which(qic_data$part == p & !is.na(qic_data$part)))
  }

  df <- purrr::map_dfr(seq_along(parts), function(i) {
    p <- parts[[i]]
    idx <- part_groups[[i]]
    sub <- qic_data[idx, , drop = FALSE]
    cl_value <- if ("cl" %in% names(sub)) .excel_to_ui_unit(sub$cl[1], y_axis_unit) else NA_real_
    ucl_value <- if ("ucl" %in% names(sub)) .excel_to_ui_unit(sub$ucl[1], y_axis_unit) else NA_real_
    lcl_value <- if ("lcl" %in% names(sub)) .excel_to_ui_unit(sub$lcl[1], y_axis_unit) else NA_real_
    y_vals <- if ("y" %in% names(sub)) .excel_to_ui_unit(sub$y, y_axis_unit) else rep(NA_real_, nrow(sub))
    mean_value <- if (length(y_vals) > 0L) suppressWarnings(mean(y_vals, na.rm = TRUE)) else NA_real_
    median_value <- if (length(y_vals) > 0L) suppressWarnings(stats::median(y_vals, na.rm = TRUE)) else NA_real_
    if (!is.finite(mean_value)) mean_value <- NA_real_
    if (!is.finite(median_value)) median_value <- NA_real_
    delta_cl <- if (!is.na(target_ui) && !is.na(cl_value)) target_ui - cl_value else NA_real_

    phase_name <- if (!is.null(phase_names) && i <= length(phase_names)) {
      as.character(phase_names[[i]])
    } else {
      ""
    }
    if (is.na(phase_name)) phase_name <- ""

    tibble::tibble(
      Part = as.integer(p),
      `Phase-navn` = phase_name,
      Fra_raekke = as.integer(min(idx)),
      Til_raekke = as.integer(max(idx)),
      N = as.integer(length(idx)),
      Centrallinje = cl_value,
      Oevre_graense = ucl_value,
      Nedre_graense = lcl_value,
      Mean = mean_value,
      Median = median_value,
      Target = if (is.na(target_ui)) NA_real_ else target_ui,
      `Delta til CL` = delta_cl
    )
  })

  names(df) <- c(
    "Part", "Phase-navn", "Fra (r\u00e6kke)", "Til (r\u00e6kke)", "N",
    paste("Centrallinje", unit_suffix_cl),
    paste("\u00d8vre gr\u00e6nse", unit_suffix_ucl),
    paste("Nedre gr\u00e6nse", unit_suffix_lcl),
    mean_label, median_label, target_label, delta_label
  )
  df
}

# SECTION C: ANHOEJ-REGLER PER PART =============================================

#' Byg sektion C (Anhoej-regler per part) til SPC-analyse-arket
#'
#' @param anhoej_per_part list. Output fra `derive_anhoej_per_part()`.
#' @return data.frame med en raekke per part.
#' @keywords internal
build_anhoej_section <- function(anhoej_per_part) {
  stopifnot(is.list(anhoej_per_part))

  cols <- c(
    "Part",
    "L\u00e6ngste serie (longest_run)",
    "Maks tilladt (longest_run_max)",
    "Antal kryds (n_crossings)",
    "Min kr\u00e6vet (n_crossings_min)",
    "Runs-signal",
    "Crossings-signal",
    "Samlet signal",
    "Dansk tolkning"
  )

  if (length(anhoej_per_part) == 0L) {
    df <- tibble::tibble(
      Part = integer(),
      Laengste_serie = numeric(),
      longest_run_max = numeric(),
      n_crossings = numeric(),
      n_crossings_min = numeric(),
      runs_signal = character(),
      crossings_signal = character(),
      anhoej_signal = character(),
      dansk_tolkning = character()
    )
    names(df) <- cols
    return(df)
  }

  to_ja_nej <- function(x) {
    if (isTRUE(x)) "JA" else "NEJ"
  }

  df <- purrr::map_dfr(anhoej_per_part, function(p) {
    tibble::tibble(
      Part = as.integer(p$part %||% 1L),
      Laengste_serie = if (is.na(p$longest_run)) NA_real_ else as.numeric(p$longest_run),
      `Maks tilladt (longest_run_max)` = if (is.na(p$longest_run_max)) NA_real_ else as.numeric(p$longest_run_max),
      `Antal kryds (n_crossings)` = if (is.na(p$n_crossings)) NA_real_ else as.numeric(p$n_crossings),
      Min_kraevet = if (is.na(p$n_crossings_min)) NA_real_ else as.numeric(p$n_crossings_min),
      `Runs-signal` = to_ja_nej(p$runs_signal),
      `Crossings-signal` = to_ja_nej(p$crossings_signal),
      `Samlet signal` = to_ja_nej(p$anhoej_signal),
      `Dansk tolkning` = interpret_anhoej_signal_da(p)
    )
  })

  names(df) <- cols
  df
}

# SECTION D: SPECIAL CAUSE-PUNKTER =============================================

#' Byg sektion D (Special cause-punkter) til SPC-analyse-arket
#'
#' Returnerer en data.frame med raekker hvor enten en Anhoej-violation
#' (runs eller crossings) er aktiv eller punktet er uden for
#' kontrolgraenser. Returnerer en attribut `empty_message` hvis ingen
#' punkter findes - caller kan vise besked.
#'
#' #468: Tidligere blev `qic_data$runs.signal` brugt direkte som
#' "Runs-signal"-rapport, men qicharts2's runs.signal er KOMBINERET
#' Anhoej-signal (sat ved enten runs- ELLER crossings-violation). Vi
#' beregner nu runs- og crossings-signaler separat per raekke ud fra
#' longest.run/longest.run.max og n.crossings/n.crossings.min, og
#' eksponerer dem som separate kolonner.
#'
#' @param qic_data data.frame.
#' @param original_data data.frame eller NULL. Bruges til at slaa dato og notes
#'   op via raekke-indeks.
#' @param y_axis_unit Character.
#' @param x_column,kommentar_column,n_column Character eller NULL. Kolonner i
#'   `original_data` der skal slaas op.
#' @return data.frame; tom hvis ingen punkter (caller fortolker via `nrow()`).
#' @keywords internal
build_special_cause_section <- function(qic_data,
                                        original_data = NULL,
                                        y_axis_unit = "count",
                                        x_column = NULL,
                                        kommentar_column = NULL,
                                        n_column = NULL) {
  stopifnot(is.data.frame(qic_data))
  unit_suffix_cl <- .excel_unit_suffix("cl", y_axis_unit)
  unit_suffix_ucl <- .excel_unit_suffix("ucl", y_axis_unit)
  unit_suffix_lcl <- .excel_unit_suffix("lcl", y_axis_unit)
  unit_label <- .excel_unit_label(y_axis_unit)
  value_label <- if (nzchar(unit_label)) sprintf("V\u00e6rdi (%s)", unit_label) else "V\u00e6rdi"

  cols <- c(
    "R\u00e6kke", "Dato", value_label,
    paste("Centrallinje", unit_suffix_cl),
    paste("\u00d8vre gr\u00e6nse", unit_suffix_ucl),
    paste("Nedre gr\u00e6nse", unit_suffix_lcl),
    "Out-of-limits", "Runs-signal", "Crossings-signal", "Notes", "N\u00e6vner (n)"
  )

  if (nrow(qic_data) == 0L) {
    df <- tibble::tibble(
      Raekke = integer(),
      Dato = as.Date(character()),
      Vaerdi = numeric(),
      Centrallinje = numeric(),
      Oevre_graense = numeric(),
      Nedre_graense = numeric(),
      out_of_limits = character(),
      runs_signal = character(),
      crossings_signal = character(),
      Notes = character(),
      Naevner = numeric()
    )
    names(df) <- cols
    return(df)
  }

  has_y <- "y" %in% names(qic_data)
  has_ucl <- "ucl" %in% names(qic_data)
  has_lcl <- "lcl" %in% names(qic_data)

  # #468: Beregn separate runs- og crossings-signaler per r\u00e6kke.
  # Erstatter tidligere qic_data$runs.signal-direkte-brug der konflaterede
  # de to violations.
  has_run_cols <- "longest.run" %in% names(qic_data) &&
    "longest.run.max" %in% names(qic_data)
  has_cross_cols <- "n.crossings" %in% names(qic_data) &&
    "n.crossings.min" %in% names(qic_data)

  runs_per_row <- if (has_run_cols) {
    !is.na(qic_data$longest.run) & !is.na(qic_data$longest.run.max) &
      qic_data$longest.run > qic_data$longest.run.max
  } else {
    rep(FALSE, nrow(qic_data))
  }

  crossings_per_row <- if (has_cross_cols) {
    !is.na(qic_data$n.crossings) & !is.na(qic_data$n.crossings.min) &
      qic_data$n.crossings < qic_data$n.crossings.min
  } else {
    rep(FALSE, nrow(qic_data))
  }

  ooc_idx <- .excel_ooc_rows(qic_data)
  runs_idx <- which(runs_per_row)
  crossings_idx <- which(crossings_per_row)
  signal_rows <- sort(unique(c(ooc_idx, runs_idx, crossings_idx)))

  if (length(signal_rows) == 0L) {
    df <- tibble::tibble(
      Raekke = integer(),
      Dato = as.Date(character()),
      Vaerdi = numeric(),
      Centrallinje = numeric(),
      Oevre_graense = numeric(),
      Nedre_graense = numeric(),
      out_of_limits = character(),
      runs_signal = character(),
      crossings_signal = character(),
      Notes = character(),
      Naevner = numeric()
    )
    names(df) <- cols
    return(df)
  }

  to_ja_nej <- function(x) {
    if (isTRUE(x)) "JA" else "NEJ"
  }

  df <- purrr::map_dfr(signal_rows, function(i) {
    y_val <- if (has_y) .excel_to_ui_unit(qic_data$y[i], y_axis_unit) else NA_real_
    cl_val <- if ("cl" %in% names(qic_data)) .excel_to_ui_unit(qic_data$cl[i], y_axis_unit) else NA_real_
    ucl_val <- if (has_ucl) .excel_to_ui_unit(qic_data$ucl[i], y_axis_unit) else NA_real_
    lcl_val <- if (has_lcl) .excel_to_ui_unit(qic_data$lcl[i], y_axis_unit) else NA_real_

    is_ooc <- i %in% ooc_idx
    is_runs <- i %in% runs_idx
    is_crossings <- i %in% crossings_idx

    note_val <- ""
    n_val <- NA_real_
    if (!is.null(original_data) && i <= nrow(original_data)) {
      if (!is.null(kommentar_column) && nzchar(kommentar_column) &&
        kommentar_column %in% names(original_data)) {
        raw_note <- original_data[[kommentar_column]][i]
        note_val <- if (is.na(raw_note)) "" else as.character(raw_note)
      }
      if (!is.null(n_column) && nzchar(n_column) && n_column %in% names(original_data)) {
        raw_n <- original_data[[n_column]][i]
        n_val <- suppressWarnings(as.numeric(raw_n))
      }
    }

    tibble::tibble(
      Raekke = as.integer(i),
      Dato = .excel_date_for_row(original_data, i, x_column = x_column),
      Vaerdi = y_val,
      Centrallinje = cl_val,
      Oevre_graense = ucl_val,
      Nedre_graense = lcl_val,
      `Out-of-limits` = to_ja_nej(is_ooc),
      `Runs-signal` = to_ja_nej(is_runs),
      `Crossings-signal` = to_ja_nej(is_crossings),
      Notes = note_val,
      Naevner = n_val
    )
  })

  names(df) <- cols
  df
}

# ORKESTRATOR ==================================================================

#' Byg SPC-analyse-arket som named list af sektioner
#'
#' Orkestrerer de fire sektion-builders og returnerer en named list som
#' `build_spc_excel()` kan iterere over og skrive til workbook'en med
#' blank-raekker mellem sektioner.
#'
#' @param qic_data data.frame fra SPC-pipeline.
#' @param metadata Named list (collect_metadata-output).
#' @param original_data data.frame eller NULL. Brugerens raa data (til
#'   dato- og notes-opslag i sektion D).
#' @param options Named list med valgfrie inputs:
#'   \describe{
#'     \item{y_axis_unit}{Character. Default fra metadata.}
#'     \item{freeze_position}{Integer eller NULL.}
#'     \item{phase_names}{Character vektor eller NULL.}
#'     \item{computed_at}{POSIXct. Default `Sys.time()`.}
#'     \item{pkg_versions}{Named list. Default tom.}
#'   }
#' @return named list med fire data.frames (`overview`, `per_part`, `anhoej`,
#'   `special_cause`), eller `NULL` hvis qic_data tomt/invalid.
#' @keywords internal
build_spc_analysis_sheet <- function(qic_data,
                                     metadata,
                                     original_data = NULL,
                                     options = list()) {
  if (!is.data.frame(qic_data) || nrow(qic_data) == 0L) {
    return(NULL)
  }
  if (!is.list(metadata)) metadata <- list()
  if (!is.list(options)) options <- list()

  y_axis_unit <- options$y_axis_unit %||% .excel_scalar(metadata$y_axis_unit, default = "count")
  freeze_position <- options$freeze_position %||% NULL
  phase_names <- options$phase_names %||% NULL
  computed_at <- options$computed_at %||% Sys.time()
  pkg_versions <- options$pkg_versions %||% list()

  anhoej_per_part <- derive_anhoej_per_part(qic_data)

  overview <- build_overview_section(
    qic_data = qic_data,
    metadata = metadata,
    anhoej_per_part = anhoej_per_part,
    y_axis_unit = y_axis_unit,
    freeze_position = freeze_position,
    computed_at = computed_at,
    pkg_versions = pkg_versions
  )

  per_part <- build_per_part_section(
    qic_data = qic_data,
    y_axis_unit = y_axis_unit,
    target_value = metadata$target_value,
    phase_names = phase_names
  )

  anhoej <- build_anhoej_section(anhoej_per_part)

  special_cause <- build_special_cause_section(
    qic_data = qic_data,
    original_data = original_data,
    y_axis_unit = y_axis_unit,
    x_column = .excel_scalar(metadata$x_column, default = NULL),
    kommentar_column = .excel_scalar(metadata$kommentar_column, default = NULL),
    n_column = .excel_scalar(metadata$n_column, default = NULL)
  )

  list(
    overview = overview,
    per_part = per_part,
    anhoej = anhoej,
    special_cause = special_cause
  )
}
