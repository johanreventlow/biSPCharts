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
  # malfortolkning ved boundary-cases. Eksempel: rå cl=0.9005,
  # target>=0.9003 → maal opfyldt; men summary-centerlinje 0.9000 vil
  # forkert give "ikke opfyldt".
  #
  # Sidste raekke matcher eksisterende semantik (sidste fase ved freeze/part).
  qic_data <- bfh_qic_result$qic_data
  if (!is.null(qic_data) && "cl" %in% names(qic_data) && nrow(qic_data) > 0) {
    return(qic_data$cl[nrow(qic_data)])
  }

  # Fallback: summary kun hvis qic_data mangler (degraderet input).
  # Note: summary-vaerdier er afrundede til UI-format; brug ikke til
  # praecisionskritisk logik.
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

build_export_analysis_metadata <- function(bfh_qic_result,
                                           target_value = NULL,
                                           target_text = NULL,
                                           data_definition = "",
                                           chart_title = "",
                                           department = "") {
  y_axis_unit <- bfh_qic_result$config$y_axis_unit %||% ""
  centerline <- resolve_analysis_centerline(bfh_qic_result)
  normalized_target_value <- normalize_mapping(target_value)
  normalized_target_text <- normalize_mapping(target_text) %||% ""
  normalized_department <- trimws(department %||% "")

  list(
    data_definition = data_definition %||% "",
    target = normalized_target_value,
    chart_title = chart_title %||% "",
    department = normalized_department,
    centerline = format_analysis_context_value(centerline, y_axis_unit),
    at_target = compute_at_target(centerline, normalized_target_value, normalized_target_text),
    target_direction = normalized_target_text
  )
}
