# utils_export_helpers.R
# Export Module Shared Helpers
#
# Utility functions for export module:
# - Mapping normalization
# - Plot building for export contexts

# CHECK QUARTO CAPABILITY ======================================================

# Session-scoped cache: resultat gemmes første gang og genbruges derefter.
# Quarto ændrer sig ikke i løbet af en R-session, så én opslag pr. session
# er tilstrækkeligt.
.quarto_capability_cache <- local({
  cached <- NULL
  list(
    get = function() cached,
    set = function(val) {
      cached <<- val
    },
    has = function() !is.null(cached)
  )
})

#' Tjek Quarto CLI-kapabilitet
#'
#' Tjekker om Quarto CLI er tilgaengelig paa systemet og om Typst-format
#' understoettes (kraever Quarto >= 1.3.0).
#'
#' Resultatet caches per R-session: Quarto aendrer sig ikke runtime,
#' saa gentagne kald returnerer det cachede resultat uden systemkald.
#'
#' @return Named list med:
#'   \describe{
#'     \item{available}{Logical. TRUE hvis quarto er fundet i PATH.}
#'     \item{quarto_version}{Character. Versionsstrengen, fx "1.4.0", eller NA.}
#'     \item{typst_supported}{Logical. TRUE hvis version >= 1.3.0.}
#'     \item{message}{Character. Dansk status- eller fejlbesked.}
#'   }
#'
#' @keywords internal
check_quarto_capability <- function() {
  # Returnerer cachet resultat hvis allerede tjekket i denne session
  if (.quarto_capability_cache$has()) {
    return(.quarto_capability_cache$get())
  }

  quarto_path <- Sys.which("quarto")

  if (nchar(quarto_path) == 0) {
    result <- list(
      available = FALSE,
      quarto_version = NA_character_,
      typst_supported = FALSE,
      message = "Quarto ikke fundet i PATH. Kontakt administrator."
    )
    .quarto_capability_cache$set(result)
    return(result)
  }

  # Hent version -- quarto --version returnerer typisk "1.4.0" paa en linje
  version_raw <- tryCatch(
    system2(quarto_path, args = "--version", stdout = TRUE, stderr = FALSE),
    error = function(e) NA_character_
  )

  version_str <- if (length(version_raw) > 0 && !is.na(version_raw[1])) {
    trimws(version_raw[1])
  } else {
    NA_character_
  }

  # Tjek om version understøtter Typst (kræver >= 1.3.0)
  typst_supported <- tryCatch(
    {
      parts <- strsplit(version_str, "\\.")[[1]]
      major <- suppressWarnings(as.integer(parts[1]))
      minor <- suppressWarnings(as.integer(parts[2]))
      !is.na(major) && (major > 1L || (major == 1L && !is.na(minor) && minor >= 3L))
    },
    error = function(e) FALSE
  )

  result <- list(
    available = TRUE,
    quarto_version = version_str,
    typst_supported = typst_supported,
    message = if (typst_supported) {
      paste0("Quarto ", version_str, " tilgængelig med Typst-understøttelse.")
    } else {
      paste0(
        "Quarto ", version_str,
        " fundet, men Typst kræver version 1.3+. Kontakt administrator."
      )
    }
  )

  .quarto_capability_cache$set(result)
  result
}

normalize_mapping <- function(value) {
  if (is.null(value) || (is.character(value) && !nzchar(trimws(value)))) {
    NULL
  } else {
    value
  }
}

#' Build Export Plot (Generic Helper)
#'
#' Genererer export plot for given context.
#' Issue #65: Fælles helper for at reducere code duplication.
#' Issue #67: Undebounced, så download handler får fresh plot.
#'
#' @param app_state Reactive values. Global app state
#' @param title_input Character. Export title input
#' @param dept_input Character. Export department input
#' @param plot_context Character. Plot context ("export_preview", "export_pdf")
#' @param override_width_px Optional integer. Override viewport width (for PNG custom sizes)
#' @param override_height_px Optional integer. Override viewport height (for PNG custom sizes)
#' @param override_dpi Optional integer. Override DPI (for PNG export with user-selected DPI)
#' @return Plot object eller NULL ved fejl
#' @keywords internal
build_export_plot <- function(app_state, title_input, dept_input,
                              plot_context = "export_pdf",
                              override_width_px = NULL,
                              override_height_px = NULL,
                              override_dpi = NULL) {
  # Validate required data
  if (is.null(app_state$data$current_data)) {
    log_warn(
      .context = "EXPORT_MODULE",
      message = "build_export_plot: No data available"
    )
    return(NULL)
  }

  x_col <- normalize_mapping(app_state$columns$mappings$x_column) %||%
    normalize_mapping(app_state$columns$auto_detect$results$x_col)
  y_col <- normalize_mapping(app_state$columns$mappings$y_column) %||%
    normalize_mapping(app_state$columns$auto_detect$results$y_col)

  if (is.null(x_col) || is.null(y_col)) {
    log_warn(
      .context = "EXPORT_MODULE",
      message = "build_export_plot: Missing required column mappings (x or y)"
    )
    return(NULL)
  }

  # chart_type can be NULL at startup - use default "run" as fallback
  chart_type <- app_state$columns$mappings$chart_type %||% "run"

  # Normalize all mappings (Issue #68)
  mappings_target_value <- normalize_mapping(
    app_state$columns$mappings$target_value
  )
  mappings_target_text <- normalize_mapping(
    app_state$columns$mappings$target_text
  )
  mappings_centerline_value <- normalize_mapping(
    app_state$columns$mappings$centerline_value
  )
  mappings_skift_column <- normalize_mapping(
    app_state$columns$mappings$skift_column
  )
  mappings_frys_column <- normalize_mapping(
    app_state$columns$mappings$frys_column
  )
  mappings_y_axis_unit <- normalize_mapping(
    app_state$columns$mappings$y_axis_unit
  )
  mappings_kommentar_column <- normalize_mapping(
    app_state$columns$mappings$kommentar_column
  )
  mappings_n_column <- normalize_mapping(
    app_state$columns$mappings$n_column
  )

  # Construct chart title (kun brugerens titel — hospital/afdeling tilføjes
  # som subtitle direkte på plottet i PNG-specifikke kontekster)
  is_png_context <- plot_context %in% c("export_png", "export_preview")
  export_title <- if (!is.null(title_input) && nchar(trimws(title_input)) > 0) {
    gsub("\n", "\\\n", title_input, fixed = TRUE)
  } else if (is_png_context) {
    # PNG/preview: ingen default-titel — tom titel giver rent billede
    NULL
  } else {
    # PDF: instruktiv default-titel
    "Skriv en kort og sigende titel eller\n**konkluder hvad grafen viser**"
  }

  # Regenerate plot with context-specific dimensions
  # This ensures correct label placement for the target context
  safe_operation(
    operation_name = paste("Generate", plot_context, "plot"),
    code = {
      # Get dimensions: use overrides if provided, otherwise context defaults
      context_dims <- get_context_dimensions(plot_context)
      final_width <- override_width_px %||% context_dims$width_px
      final_height <- override_height_px %||% context_dims$height_px

      # Get chart configuration from app_state
      config <- list(
        x_col = x_col,
        y_col = y_col,
        n_col = mappings_n_column
      )

      # Build generateSPCPlot arguments
      spc_args <- list(
        data = app_state$data$current_data,
        config = config,
        chart_type = chart_type,
        target_value = mappings_target_value,
        target_text = mappings_target_text,
        centerline_value = mappings_centerline_value,
        show_phases = !is.null(mappings_skift_column),
        skift_column = mappings_skift_column,
        frys_column = mappings_frys_column,
        chart_title_reactive = export_title,
        y_axis_unit = mappings_y_axis_unit %||% "count",
        kommentar_column = mappings_kommentar_column,
        base_size = 14,
        viewport_width = final_width,
        viewport_height = final_height,
        plot_context = plot_context
      )
      # PNG export: override DPI for correct dimension conversion (Issue #64)
      if (!is.null(override_dpi)) {
        spc_args$override_dpi <- override_dpi
      }

      spc_result <- do.call(generateSPCPlot, spc_args)

      # DEBUG: Log what generateSPCPlot returned
      log_debug(
        .context = "EXPORT_MODULE",
        message = paste(
          "generateSPCPlot returned - is_null:",
          is.null(spc_result),
          "| has_plot:",
          !is.null(spc_result$plot),
          "| class:",
          if (!is.null(spc_result)) paste(class(spc_result), collapse = ",") else "NULL",
          "| names:",
          if (!is.null(spc_result) && is.list(spc_result)) paste(names(spc_result), collapse = ",") else "N/A"
        )
      )

      log_debug(
        .context = "EXPORT_MODULE",
        message = sprintf("Export plot generated for context: %s", plot_context),
        details = list(
          title = export_title,
          context = plot_context,
          width = context_dims$width_px,
          height = context_dims$height_px,
          dpi = context_dims$dpi,
          has_title = nchar(trimws(title_input %||% "")) > 0,
          has_dept = nchar(trimws(dept_input %||% "")) > 0
        )
      )

      # Return full result including bfh_qic_result for exports
      # NOTE: Don't use return() inside safe_operation code blocks!
      # R's force() evaluation doesn't handle return() correctly - just use the value
      spc_result
    },
    fallback = function(e) {
      log_error(
        .context = "EXPORT_MODULE",
        message = sprintf("Failed to generate %s plot", plot_context),
        details = list(error = e$message, context = plot_context)
      )
      NULL
    },
    error_type = "processing"
  )
}
