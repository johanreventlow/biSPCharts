format_analysis_context_value <- function(value, y_axis_unit = NULL) {
  if (is.null(value) || length(value) == 0 || is.na(value) || !is.numeric(value)) {
    return(NULL)
  }

  if (identical(y_axis_unit, "percent") && value <= 1) {
    return(paste0(round(value * 100), "%"))
  }

  if (identical(y_axis_unit, "percent")) {
    return(paste0(round(value), "%"))
  }

  if (value == round(value)) {
    return(as.character(as.integer(value)))
  }

  format(round(value, 1), decimal.mark = ",")
}

resolve_analysis_centerline <- function(bfh_qic_result) {
  if (is.null(bfh_qic_result)) {
    return(NULL)
  }

  # #470: Brug qic_data$cl (raa qicharts2-vaerdi) primaert for at undgaa
  # afrundings-tab i BFHcharts' summary-lag der ellers kan flippe
  # malfortolkning ved boundary-cases. Eksempel: raa cl=0.9005,
  # target>=0.9003 -> maal opfyldt; men summary-centerlinje 0.9000 vil
  # forkert give "ikke opfyldt".
  #
  # Sidste raekke matcher eksisterende semantik (sidste fase ved freeze/part).
  qic_data <- bfh_qic_result$qic_data
  if (!is.null(qic_data) && "cl" %in% names(qic_data) && nrow(qic_data) > 0) {
    return(qic_data$cl[nrow(qic_data)])
  }

  # Fallback: summary kun hvis qic_data mangler (degraderet input).
  # Note: BFHcharts >= 0.15.0 returnerer raw qicharts2-praecision i
  # summary-kolonner — afrundings-bug fra tidligere versioner er fixed.
  # Vi beholder qic_data$cl som primær for at undgaa fremtidig regression
  # hvis BFHcharts genintroducerer rounding (#492 3.4).
  summary_data <- bfh_qic_result$summary
  if (!is.null(summary_data) &&
    "centerlinje" %in% names(summary_data) &&
    nrow(summary_data) > 0) {
    return(summary_data$centerlinje[nrow(summary_data)])
  }

  NULL
}

compute_at_target <- function(centerline, target_value, target_text = NULL) {
  if (is.null(centerline) || is.null(target_value) || is.na(centerline) || is.na(target_value)) {
    return(FALSE)
  }

  if (!is.numeric(centerline) || !is.numeric(target_value)) {
    return(FALSE)
  }

  target_label <- trimws(target_text %||% "")
  tolerance <- max(abs(target_value) * 0.05, 0.01)
  close_enough <- abs(centerline - target_value) <= tolerance

  if (grepl("^\\s*(>|>=|\u2265|\u2191)", target_label)) {
    return(close_enough || centerline >= target_value)
  }

  if (grepl("^\\s*(<|<=|\u2264|\u2193)", target_label)) {
    return(close_enough || centerline <= target_value)
  }

  close_enough
}

# Beregn is_stable fra Anhoej-rules paa bfh_qic_result.
# Stabil = ingen runs-violation OG ingen crossings-violation.
resolve_is_stable <- function(bfh_qic_result) {
  if (is.null(bfh_qic_result)) {
    return(TRUE)
  }
  anhoej <- bfh_qic_result$metadata$anhoej_rules
  if (is.null(anhoej)) {
    return(TRUE)
  }
  runs_detected <- isTRUE(anhoej$runs_detected)
  crossings_detected <- isTRUE(anhoej$crossings_detected)
  !runs_detected && !crossings_detected
}

# Generer handlingsforslag-tekst baseret paa stabilitet og maal.
# Replikerer BFHcharts' fallback_action_text()-logik (6 faste cases).
# Bruges til at holde handlingsforslaget ude af LLM-prompten saa LLM
# ikke gentager dansk fast-tekst i sin generering.
build_action_text <- function(is_stable, has_target, at_target) {
  if (is_stable && has_target && at_target) {
    paste0(
      "Forts\u00e6t den nuv\u00e6rende praksis og overv\u00e5g processen ",
      "l\u00f8bende for at fastholde det gode niveau."
    )
  } else if (is_stable && has_target && !at_target) {
    paste0(
      "Processen er stabil men n\u00e5r ikke m\u00e5let. Forbedring ",
      "kr\u00e6ver en bevidst \u00e6ndring af processen \u2013 den ",
      "nuv\u00e6rende praksis vil levere samme resultat."
    )
  } else if (is_stable && !has_target) {
    paste0(
      "Overvej at fasts\u00e6tte et m\u00e5l for indikatoren for at ",
      "kunne vurdere om det aktuelle niveau er tilfredsstillende og om ",
      "der er behov for forbedring."
    )
  } else if (!is_stable && has_target && at_target) {
    paste0(
      "Selvom m\u00e5let aktuelt er opfyldt, er processen ustabil. ",
      "Identific\u00e9r og adress\u00e9r \u00e5rsagerne til variationen ",
      "for at sikre at niveauet kan fastholdes."
    )
  } else if (!is_stable && has_target && !at_target) {
    paste0(
      "Priorit\u00e9r at identificere og fjerne de s\u00e6rlige ",
      "\u00e5rsager til variationen f\u00f8r yderligere ",
      "forbedringstiltag iv\u00e6rks\u00e6ttes."
    )
  } else {
    paste0(
      "Identific\u00e9r og unders\u00f8g \u00e5rsagerne til den ",
      "us\u00e6dvanlige variation. N\u00e5r processen er bragt under ",
      "kontrol, kan der fasts\u00e6ttes et realistisk m\u00e5l."
    )
  }
}

build_export_analysis_metadata <- function(bfh_qic_result,
                                           target_value = NULL,
                                           target_text = NULL,
                                           data_definition = "",
                                           chart_title = "",
                                           department = "",
                                           footnote = "",
                                           baseline_analysis = "",
                                           signal_examples = "") {
  y_axis_unit <- bfh_qic_result$config$y_axis_unit %||% ""
  centerline_raw <- resolve_analysis_centerline(bfh_qic_result)
  normalized_target_value <- normalize_mapping(target_value)
  normalized_target_text <- normalize_mapping(target_text) %||% ""
  normalized_department <- trimws(department %||% "")

  at_target <- compute_at_target(centerline_raw, normalized_target_value, normalized_target_text)
  is_stable <- resolve_is_stable(bfh_qic_result)
  has_target <- !is.null(normalized_target_value) &&
    !is.na(normalized_target_value) &&
    is.numeric(normalized_target_value) &&
    !is.null(centerline_raw) &&
    !is.na(centerline_raw)

  list(
    data_definition = data_definition %||% "",
    target = normalized_target_value,
    target_display = format_analysis_context_value(normalized_target_value, y_axis_unit),
    chart_title = chart_title %||% "",
    department = normalized_department,
    footnote = footnote %||% "",
    y_axis_unit = y_axis_unit,
    centerline = format_analysis_context_value(centerline_raw, y_axis_unit),
    at_target = at_target,
    target_direction = normalized_target_text,
    action_text = build_action_text(is_stable, has_target, at_target),
    baseline_analysis = baseline_analysis %||% "",
    signal_examples = signal_examples %||% ""
  )
}
