# fct_spc_bfh_facade.R
# BFHchart Service Layer Facade
#
# Hovedorkestrator for SPC-beregning via BFHcharts.
# Implementerer adapter-mønstret for at isolere biSPCharts fra BFHcharts API.
#
# Design: Facade-funktion der koordinerer:
# 1. Input validering
# 2. Parameter transformation (via fct_spc_bfh_params)
# 3. BFHcharts invocation (via fct_spc_bfh_invocation)
# 4. Output standardization (via fct_spc_bfh_output)
# 5. Anhøj metadata beregning (via fct_spc_bfh_signals)


#' Compute SPC Results Using BFHchart Backend
#'
#' Primary facade function that wraps BFHchart functionality with biSPCharts conventions.
#' This function provides a stable interface that isolates the application from
#' BFHchart API changes, handles parameter mapping, validates inputs, and standardizes
#' output format for seamless integration with existing biSPCharts plot rendering.
#'
#' @details
#' **Architectural Role:** Service layer facade implementing adapter pattern.
#' Coordinates validation, transformation, BFHchart invocation, and output formatting.
#'
#' **Workflow:**
#' 1. Input validation using existing biSPCharts validators
#' 2. Parameter transformation (biSPCharts conventions → BFHchart API)
#' 3. Safe BFHchart invocation with error handling
#' 4. Output standardization (match qicharts2 format)
#' 5. Structured logging and cache management
#'
#' **Error Handling:** All operations wrapped in `safe_operation()` with graceful
#' fallback. Errors logged with structured context for debugging.
#'
#' @section Notes Column Mapping:
#' The `notes_column` parameter maps to BFHchart's comment/notes system. If BFHchart
#' does not provide native notes support, biSPCharts applies comments as a ggrepel layer
#' after BFHchart rendering (existing pattern). Comment handling includes:
#' - Row ID stability via `.original_row_id` injection
#' - XSS sanitization with Danish character support (æøå)
#' - Intelligent truncation (40 char display, 100 char max)
#' - Collision avoidance with `ggrepel::geom_text_repel()`
#'
#' @param data data.frame. Input dataset with SPC data. Required.
#' @param x_var character. Name of x-axis variable (time/sequence column). Required.
#' @param y_var character. Name of y-axis variable (measure/value column). Required.
#' @param chart_type character. SPC chart type. One of: "run", "i", "mr", "p", "pp",
#'   "u", "up", "c", "g". Required. Use qicharts2-style codes (lowercase).
#' @param n_var character. Name of denominator variable for rate-based charts
#'   (P, P', U, U' charts). Default NULL. Required for charts with denominators.
#' @param cl_var character. Name of control limit override variable. Allows custom
#'   centerline per data point. Default NULL (auto-calculate).
#' @param freeze_var character. Name of freeze period indicator variable. Marks
#'   baseline period for control limit calculation. Default NULL (no freeze).
#' @param part_var character. Name of part/subgroup/phase variable. Enables
#'   per-phase control limit calculation and Anhøj rule application. Default NULL.
#' @param notes_column character. Name of notes/comment column to display on plot.
#'   Maps to BFHchart notes parameter or biSPCharts ggrepel layer. Default NULL.
#' @param multiply numeric. Multiplier applied to y-axis values for display scaling.
#'   Common use: convert decimal proportions to percentages (multiply = 100).
#'   Default 1 (no scaling).
#' @param use_cache logical. Enable caching for SPC computation results. Default TRUE.
#'   Set to FALSE to force fresh computation (useful for debugging or testing).
#' @param app_state Application state object. Required for cache access. If NULL,
#'   caching is disabled. Default NULL.
#' @param ... Additional arguments passed to BFHchart backend. Allows flexibility
#'   for BFHchart-specific parameters without breaking biSPCharts interface.
#'
#' @return list with three components:
#'   \describe{
#'     \item{plot}{ggplot2 object. Rendered SPC chart with control limits, centerline,
#'       and optional annotations. Compatible with biSPCharts plot customization functions.}
#'     \item{qic_data}{tibble. Standardized data frame with SPC calculations. Columns:
#'       \itemize{
#'         \item x: X-axis values (dates or observation numbers)
#'         \item y: Y-axis values (original or scaled measures)
#'         \item cl: Centerline per data point (may vary by phase)
#'         \item ucl: Upper control limit per data point
#'         \item lcl: Lower control limit per data point
#'         \item part: Phase/subgroup indicator (integer, starting at 1)
#'         \item signal: Combined Anhøj signal (logical, TRUE if runs OR crossings violation)
#'         \item .original_row_id: Row identifier for stable comment mapping
#'       }
#'     }
#'     \item{metadata}{list. Chart configuration and diagnostic information:
#'       \itemize{
#'         \item chart_type: Chart type used
#'         \item n_points: Number of data points processed
#'         \item n_phases: Number of phases (if part_var specified)
#'         \item freeze_applied: Logical indicating if freeze was applied
#'         \item signals_detected: Count of Anhøj rule violations
#'         \item bfh_version: BFHchart package version used
#'         \item anhoej_rules: list with Anhøj rules metadata (runs_detected, crossings_detected, longest_run, n_crossings, n_crossings_min)
#'       }
#'     }
#'   }
#'   Returns NULL on error (with structured logging).
#' @examples
#' \dontrun{
#' # Basic run chart
#' result <- compute_spc_results_bfh(
#'   data = hospital_data,
#'   x_var = "month",
#'   y_var = "infections",
#'   chart_type = "run"
#' )
#' print(result$plot)
#' summary(result$qic_data)
#'
#' # P-chart with denominator and freeze period
#' result <- compute_spc_results_bfh(
#'   data = surgical_data,
#'   x_var = "date",
#'   y_var = "complications",
#'   n_var = "procedures",
#'   chart_type = "p",
#'   freeze_var = "baseline_indicator",
#'   multiply = 100
#' )
#'
#' # Multi-phase I-chart with comments
#' result <- compute_spc_results_bfh(
#'   data = quality_data,
#'   x_var = "week",
#'   y_var = "defects",
#'   chart_type = "i",
#'   part_var = "intervention_phase",
#'   notes_column = "comment",
#'   multiply = 1
#' )
#'
#' # Access standardized data
#' print(result$qic_data)
#' # Check metadata
#' print(result$metadata$signals_detected)
#' }
#'
#' @seealso
#' \code{\link{map_to_bfh_params}} for parameter transformation logic
#' \code{\link{transform_bfh_output}} for output standardization
#' @keywords internal
#' @export
compute_spc_results_bfh <- function(
  data,
  x_var,
  y_var,
  chart_type,
  n_var = NULL,
  cl_var = NULL,
  freeze_var = NULL,
  part_var = NULL,
  notes_column = NULL,
  multiply = 1,
  use_cache = TRUE,
  app_state = NULL,
  ...
) {
  # Validering UDEN safe_operation — fejl propagerer som spc_input_error til caller
  req <- validate_spc_request(
    data = if (missing(data)) NULL else data,
    x_var = if (missing(x_var)) NULL else x_var,
    y_var = if (missing(y_var)) NULL else y_var,
    chart_type = if (missing(chart_type)) NULL else chart_type,
    n_var = n_var,
    cl_var = cl_var,
    freeze_var = freeze_var,
    part_var = part_var,
    notes_column = notes_column,
    multiply = multiply,
    ...
  )

  safe_operation(
    operation_name = "BFHchart SPC computation",
    code = {
      # 1. (Validering sker i validate_spc_request() FØR safe_operation)
      # 1b. Cache key generation (before expensive validation)
      # Extract parameters for cache key
      extra_params <- list(...)
      cache_config <- list(
        chart_type = chart_type,
        x_column = x_var,
        y_column = y_var,
        n_column = n_var,
        freeze_position = if (!is.null(freeze_var)) {
          # Extract freeze position from data if available
          NULL # Will be computed after data filtering
        } else {
          NULL
        },
        part_positions = NULL, # Will be computed after data filtering
        target_value = extra_params$target_value,
        centerline_value = extra_params$centerline_value,
        y_axis_unit = extra_params$y_axis_unit,
        multiply_by = multiply,
        # CRITICAL: Include viewport dimensions for context-aware caching
        # Different contexts (analysis, export_preview, export_pdf) have different
        # viewport dimensions which affect label placement in BFHcharts.
        # Without this, plots generated in one context would be incorrectly cached
        # and reused in another context with different dimensions.
        viewport_width = extra_params$width,
        viewport_height = extra_params$height
      )

      # Generate cache key
      cache_key <- if (use_cache) {
        tryCatch(
          {
            if (exists("generate_spc_cache_key", mode = "function")) {
              generate_spc_cache_key(data, cache_config)
            } else {
              NULL
            }
          },
          error = function(e) {
            log_warn(
              paste("Cache key generation failed:", e$message),
              .context = "BFH_SERVICE"
            )
            NULL
          }
        )
      } else {
        NULL
      }

      # 1c. Check cache before expensive computation
      if (!is.null(cache_key) && !is.null(app_state)) {
        qic_cache <- tryCatch(
          {
            if (exists("get_or_init_qic_cache", mode = "function")) {
              get_or_init_qic_cache(app_state)
            } else {
              NULL
            }
          },
          error = function(e) {
            log_warn(
              paste("Cache initialization failed:", e$message),
              .context = "BFH_SERVICE"
            )
            NULL
          }
        )

        if (!is.null(qic_cache)) {
          cached_result <- tryCatch(
            {
              if (exists("get_cached_spc_result", mode = "function")) {
                get_cached_spc_result(cache_key, qic_cache)
              } else {
                NULL
              }
            },
            error = function(e) {
              log_warn(
                paste("Cache retrieval failed:", e$message),
                .context = "BFH_SERVICE"
              )
              NULL
            }
          )

          if (!is.null(cached_result)) {
            log_info(
              paste("Cache hit - returning cached result:", substr(cache_key, 1, 40), "..."),
              .context = "BFH_SERVICE"
            )
            return(cached_result)
          } else {
            log_debug(
              paste("Cache miss - computing fresh result:", substr(cache_key, 1, 40), "..."),
              .context = "BFH_SERVICE"
            )
          }
        }
      }

      # 2+3. Chart type og denominator er valideret i validate_spc_request()
      validated_chart_type <- req$chart_type

      # 4-6c. Filtrer, parser og forbered data
      prepared <- prepare_spc_data(req)
      complete_data <- prepared$data

      # 7. PURE BFHCHARTS WORKFLOW: Direct BFHcharts::bfh_qic() call
      # This eliminates qicharts2 dependency for SPC calculation
      extra_params <- list(...)

      # 7a. Extract parameters
      target_value <- extra_params$target_value
      centerline_value <- extra_params$centerline_value
      y_axis_unit <- extra_params$y_axis_unit %||% "count"

      # Skalér target/centerline til kanoniske minutter hvis y-enheden er
      # en tids-enhed. Brugeren indtaster target i den valgte enhed (fx 90
      # med time_days = 90 dage), men y-data er allerede i minutter efter
      # step 4b. Uden denne skalering ville target = 90 blive plottet som
      # 90 minutter i stedet for 90 dage (= 129600 min).
      if (is_time_unit(y_axis_unit)) {
        if (!is.null(target_value) && length(target_value) > 0) {
          scaled_target <- parse_time_to_minutes(target_value, input_unit = y_axis_unit)
          log_debug(
            paste0(
              "Skalerer target_value ", target_value, " (", y_axis_unit,
              ") -> ", scaled_target, " min"
            ),
            .context = "BFH_SERVICE"
          )
          target_value <- scaled_target
        }
        if (!is.null(centerline_value) && length(centerline_value) > 0) {
          scaled_cl <- parse_time_to_minutes(centerline_value, input_unit = y_axis_unit)
          log_debug(
            paste0(
              "Skalerer centerline_value ", centerline_value, " (", y_axis_unit,
              ") -> ", scaled_cl, " min"
            ),
            .context = "BFH_SERVICE"
          )
          centerline_value <- scaled_cl
        }
      }

      # BFHcharts 0.8.0's y_axis_unit accepterer kun "count", "percent",
      # "rate", "time". Map de nye biSPCharts-enheder (time_minutes/hours/days)
      # til den kanoniske "time" — data er allerede parsed til minutter (se 4b).
      if (is_time_unit(y_axis_unit) && !identical(y_axis_unit, "time")) {
        log_debug(
          paste0(
            "Mapper y_axis_unit='", y_axis_unit,
            "' -> 'time' for BFHcharts (data er i kanoniske minutter)"
          ),
          .context = "BFH_SERVICE"
        )
        y_axis_unit <- "time"
      }
      chart_title <- resolve_bfh_chart_title(
        extra_params$chart_title_reactive %||% extra_params$chart_title
      )
      target_text <- extra_params$target_text

      # Formatér target_text som komposit-tid hvis y-enheden er en tids-enhed.
      # target_text er brugerens rå input (fx "90" eller "<90"). Vi bevarer
      # evt. operator-prefix og erstatter den numeriske del med komposit-format
      # baseret på target_value (skaleret til minutter ovenfor).
      # Eksempel: bruger skriver target=90 med "Tid (dage)" → label viser "90d";
      # 90 timer → label viser "3d 18t".
      original_y_unit <- extra_params$y_axis_unit %||% "count"
      if (is_time_unit(original_y_unit) &&
        !is.null(target_text) &&
        !is.null(target_value) &&
        length(target_value) > 0) {
        operator_match <- regmatches(
          target_text,
          regexpr("^[<>=]+", target_text)
        )
        operator_prefix <- if (length(operator_match) > 0) operator_match else ""
        formatted_value <- format_time_composite(target_value)
        new_target_text <- paste0(operator_prefix, formatted_value)
        log_debug(
          paste0(
            "Formaterer target_text '", target_text, "' -> '",
            new_target_text, "' (y_axis_unit=", original_y_unit, ")"
          ),
          .context = "BFH_SERVICE"
        )
        target_text <- new_target_text
      }

      # Guard: Fjern nævner for chart types der ikke bruger den.
      # Forhindrer at BFHcharts dividerer y med n (giver alle værdier = 1).
      if (!is.null(n_var) && !chart_type_requires_denominator(validated_chart_type)) {
        log_warn(
          paste(
            "n_var fjernet for chart_type=", validated_chart_type,
            "— denne type bruger ikke nævner (n_var var:", n_var, ")"
          ),
          .context = "BFH_SERVICE"
        )
        n_var <- NULL
      }

      # Guard: "percent" kræver nævner — uden nævner er det en fejldetektering
      if (identical(y_axis_unit, "percent") && is.null(n_var)) {
        log_warn(
          paste(
            "y_axis_unit='percent' uden nævner (n_var=NULL) for chart_type=",
            validated_chart_type,
            "— overskriver til 'count' for at undgå forkert normalisering"
          ),
          .context = "BFH_SERVICE"
        )
        y_axis_unit <- "count"
      }

      log_debug(
        paste(
          "Pure BFHcharts workflow parameters:",
          "chart_type =", validated_chart_type,
          ", y_axis_unit =", y_axis_unit,
          ", n_var =", if (is.null(n_var)) "NULL" else n_var,
          ", has_target =", !is.null(target_value),
          ", has_chart_title =", !is.null(chart_title)
        ),
        .context = "BFH_SERVICE"
      )

      # Diagnostisk log af y-værdier sendt til BFHcharts
      log_debug(
        paste(
          "[DEBUG_Y_VALUES] chart_type =", validated_chart_type,
          "| y_axis_unit =", y_axis_unit,
          "| n_var =", if (is.null(n_var)) "NULL" else n_var,
          "| y_col =", y_var,
          "| y_class =", class(complete_data[[y_var]])[1],
          "| y_first5 =", paste(head(complete_data[[y_var]], 5), collapse = ", "),
          "| y_range =", paste(range(complete_data[[y_var]], na.rm = TRUE), collapse = "-")
        ),
        .context = "BFH_SERVICE"
      )

      # 7b. Map parameters to BFHcharts format
      # VIGTIGT: width/height/units forwarded til bfh_qic() for korrekt
      # label-placering (bredde-baseret skalering i BFHcharts)
      bfh_params <- map_to_bfh_params(
        data = complete_data,
        x_var = x_var,
        y_var = y_var,
        chart_type = validated_chart_type,
        n_var = n_var,
        cl_var = cl_var,
        freeze_var = freeze_var,
        part_var = part_var,
        notes_column = notes_column,
        target_value = target_value,
        centerline_value = centerline_value,
        chart_title = chart_title,
        y_axis_unit = y_axis_unit,
        target_text = target_text,
        multiply = multiply,
        width = extra_params$width,
        height = extra_params$height,
        units = extra_params$units,
        # Bevar base_size=14 — uden dette aktiverer width/height
        # calculate_base_size() som giver base_size=8 (for lille)
        base_size = 14
      )

      if (is.null(bfh_params)) {
        stop("Parameter mapping failed")
      }

      # 7c. Call BFHcharts high-level API directly
      t_bfh_start <- Sys.time()
      bfh_result <- call_bfh_chart(bfh_params)
      log_info(paste("Step 7c bfh_qic:", round(difftime(Sys.time(), t_bfh_start, units = "secs"), 2), "sek"), .context = "BFH_TIMING")

      if (is.null(bfh_result)) {
        stop("BFHcharts rendering failed")
      }

      # 7c2. Tilføj tekst-labels på x-aksen til bfh_result (bruges af PDF preview/eksport)
      x_labels_col <- paste0(".x_labels_", x_var)
      if (x_labels_col %in% names(complete_data)) {
        x_labels <- complete_data[[x_labels_col]]
        x_breaks <- seq_along(x_labels)
        x_scale <- ggplot2::scale_x_continuous(breaks = x_breaks, labels = x_labels)
        x_theme <- ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
        # Opdater bfh_result plot (for PDF/PNG eksport)
        if (!is.null(bfh_result$plot)) {
          bfh_result$plot <- bfh_result$plot + x_scale + x_theme
        }
      }

      # 7d. Transform BFHcharts output to standardized format
      t_transform_start <- Sys.time()
      standardized <- transform_bfh_output(
        bfh_result = bfh_result,
        multiply = multiply,
        chart_type = validated_chart_type,
        original_data = complete_data,
        freeze_applied = !is.null(freeze_var) && freeze_var %in% names(complete_data)
      )

      log_info(paste("Step 7d transform:", round(difftime(Sys.time(), t_transform_start, units = "secs"), 2), "sek"), .context = "BFH_TIMING")

      if (is.null(standardized)) {
        stop("Output transformation failed")
      }

      # 7d2. Tilføj tekst-labels på standardized plot (analyse-visning)
      if (x_labels_col %in% names(complete_data) && !is.null(standardized$plot)) {
        standardized$plot <- standardized$plot + x_scale + x_theme
      }

      # 7e. Anhøj metadata: brug BFHcharts' allerede beregnede metadata
      # transform_bfh_output() udtrækker Anhøj-regler fra BFHcharts qic_data.
      # compute_anhoej_metadata_local() (qicharts2::qic) er FJERNET da den var
      # redundant og tog ~24 sek for P-kort pga. intern ggplot rendering.
      # Fallback til qicharts2 kun hvis BFHcharts metadata mangler.
      if (is.null(standardized$metadata$anhoej_rules)) {
        log_warn(
          "BFHcharts Anhøj metadata mangler — falder tilbage til qicharts2",
          .context = "BFH_SERVICE"
        )
        anhoej_metadata_local <- compute_anhoej_metadata_local(
          data = complete_data,
          config = list(
            x_col = x_var,
            y_col = y_var,
            n_col = n_var,
            chart_type = validated_chart_type
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

      # 7g. Add backend flag to indicate BFHcharts workflow
      standardized$metadata$backend <- "bfhcharts"

      # 8. Store result in cache if enabled
      if (!is.null(cache_key) && !is.null(app_state)) {
        tryCatch(
          {
            qic_cache <- if (exists("get_or_init_qic_cache", mode = "function")) {
              get_or_init_qic_cache(app_state)
            } else {
              NULL
            }

            if (!is.null(qic_cache) && exists("cache_spc_result", mode = "function")) {
              # Use 1 hour TTL (3600 seconds) by default
              cache_ttl <- CACHE_CONFIG$default_timeout_seconds %||% 3600
              cache_spc_result(cache_key, standardized, qic_cache, ttl = cache_ttl)

              log_debug(
                paste("Result cached with TTL:", cache_ttl, "seconds"),
                .context = "BFH_SERVICE"
              )
            }
          },
          error = function(e) {
            log_warn(
              paste("Cache storage failed:", e$message),
              .context = "BFH_SERVICE"
            )
          }
        )
      }

      # 9. Log success
      log_info(
        message = "SPC computation completed successfully",
        .context = "BFH_SERVICE",
        details = list(
          chart_type = validated_chart_type,
          n_points = nrow(standardized$qic_data),
          signals_detected = sum(standardized$qic_data$signal, na.rm = TRUE),
          has_notes = !is.null(notes_column),
          cached = !is.null(cache_key)
        )
      )

      # NOTE: Don't use return() inside safe_operation code blocks!
      # R's force() evaluation doesn't handle return() correctly
      standardized
    },
    fallback = NULL,
    show_user = TRUE,
    error_type = "bfh_service"
  )
}


#' Resolve BFHchart Chart Title
#'
#' Helper for resolving reactive or static chart titles. Handles reactiveValues
#' that may be NULL or contain title strings. Internal utility.
#'
#' @param title_candidate Reactive or character. Title value (may be reactive).
#'
#' @return character. Resolved title or NULL.
#'
#' @keywords internal
resolve_bfh_chart_title <- function(title_candidate) {
  safe_operation(
    operation_name = "BFHchart chart title resolution",
    code = {
      # NOTE: Don't use return() inside safe_operation code blocks!
      # Use conditional flow with result variable instead

      # Handle NULL input
      if (is.null(title_candidate)) {
        result <- NULL
      }
      # Handle empty string
      else if (identical(title_candidate, "")) {
        result <- NULL
      }
      # Handle reactive (shiny reactive value)
      else if (is.reactive(title_candidate)) {
        # Try to evaluate reactive if callable
        tryCatch(
          {
            value <- title_candidate()
            if (is.null(value) || identical(value, "")) {
              result <- NULL
            } else {
              result <- as.character(value)
            }
          },
          error = function(e) {
            result <<- NULL
          }
        )
      }
      # Handle character or numeric (convert to string)
      else {
        result <- as.character(title_candidate)
        # Final check for empty result
        if (identical(result, "")) {
          result <- NULL
        }
      }

      result
    },
    fallback = NULL,
    error_type = "title_resolution"
  )
}
