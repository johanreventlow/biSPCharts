# ==============================================================================
# mod_spc_chart_compute.R
# ==============================================================================
# SPC COMPUTATION MODULE FOR SPC CHART VISUALIZATION
#
# Purpose: Core SPC computation pipeline. Calls BFHcharts API, computes
#          Anhoej rules via qicharts2, manages plot caching, and handles
#          all state mutations via set_plot_state().
#
# Extracted from: mod_spc_chart_server.R (Stage 4 of Phase 2c refactoring)
# Depends on: spc_inputs reactive (from mod_spc_chart_inputs)
#            app_state (centralized state + set_plot_state/get_plot_state)
#            BFHcharts API (via generateSPCPlot)
#            qicharts2 (via Anhoej rules extraction)
# ==============================================================================

#' Create SPC Results Reactive
#'
#' Core computation pipeline for SPC chart generation. Calls BFHcharts to
#' generate plots, extracts Anhoej rules from qicharts2, and manages cache
#' with context-aware cache keys for plot isolation.
#'
#' @param spc_inputs_reactive Reactive expression returning SPC parameters
#' @param app_state Reactive values object for state mutations
#' @param set_plot_state Function to update plot state (closure over app_state)
#' @param get_plot_state Function to read plot state (closure over app_state)
#'
#' @return Reactive expression returning list with:
#'   - plot: ggplot2 object (or NULL if validation failed)
#'   - qic_data: Data frame with Anhoej rules results
#'   - cache_key: Cache key used for this computation
#'
#' @details
#' Computation flow:
#' 1. Build context-aware cache key including viewport dimensions
#' 2. Validate data against chart requirements
#' 3. Call generateSPCPlot (BFHcharts API)
#' 4. Extract Anhoej rules from qic_data
#' 5. Update plot state and anhoej_results
#' 6. Handle errors with fallback results
#' 7. Cache results using bindCache with context isolation
#'
#' Cache key includes:
#' - Context identifier (ensures separate cache per context)
#' - Data hash (invalidates on data change)
#' - Chart type and column mapping
#' - All visual parameters (target, centerline, baseline, font size)
#' - Viewport dimensions (width, height)
#'
#' @keywords internal
create_spc_results_reactive <- function(
  spc_inputs_reactive,
  app_state,
  set_plot_state,
  get_plot_state
) {
  shiny::reactive({
    inputs <- spc_inputs_reactive()

    # Inkluder kolonnemapping i cache-key for at invalidere ved dropdownaendringer
    config_key <- paste0(
      inputs$config$x_col %||% "NULL", "|",
      inputs$config$y_col %||% "NULL", "|",
      inputs$config$n_col %||% "NULL"
    )

    # M11: Context-aware cache key for plot isolation
    # Issue #62: Separate cache per context to prevent dimension bleeding
    plot_context <- "analysis" # Analyse-side always uses "analysis" context
    vp_dims <- get_viewport_dims(app_state)

    cache_key <- digest::digest(
      list(
        plot_context, # NEW: Context identifier for cache isolation
        inputs$data_hash,
        inputs$chart_type,
        config_key,
        inputs$target_value,
        inputs$target_text, # CRITICAL: Include target_text for operator invalidation
        inputs$centerline_value,
        inputs$skift_hash,
        inputs$frys_hash,
        inputs$title,
        inputs$y_axis_unit,
        inputs$kommentar_column,
        inputs$base_size, # FIX: Invalider cache ved breddeaendring/fuldskaerm
        vp_dims$width, # NEW: Viewport width for dimension-aware caching
        vp_dims$height # NEW: Viewport height for dimension-aware caching
      ),
      algo = "xxhash64"
    )

    # Registrer om baseline/centerline er aendret (inkl. ryddet)
    last_centerline <- shiny::isolate(app_state$visualization$last_centerline_value)
    centerline_changed <- !identical(inputs$centerline_value, last_centerline)

    log_debug(
      sprintf(
        "qic_startup_call chart=%s rows=%d",
        inputs$chart_type,
        nrow(inputs$data)
      ),
      .context = "SPC_PIPELINE"
    )

    set_plot_state("plot_ready", FALSE)
    set_plot_state("plot_warnings", character(0))
    set_plot_state("is_computing", TRUE)
    set_plot_state("plot_generation_in_progress", TRUE)

    on.exit(
      {
        set_plot_state("is_computing", FALSE)
        set_plot_state("plot_generation_in_progress", FALSE)
      },
      add = TRUE
    )

    validation <- validateDataForChart(inputs$data, inputs$config, inputs$chart_type)

    if (!validation$valid) {
      set_plot_state("plot_warnings", validation$warnings)
      set_plot_state("plot_ready", FALSE)
      set_plot_state("anhoej_results", list(
        longest_run = NA_real_,
        longest_run_max = NA_real_,
        n_crossings = NA_real_,
        n_crossings_min = NA_real_,
        out_of_control_count = 0L,
        runs_signal = FALSE,
        crossings_signal = FALSE,
        anhoej_signal = FALSE,
        any_signal = FALSE,
        message = "Validering fejlede - kontroller data",
        has_valid_data = FALSE
      ))
      set_plot_state("plot_object", NULL)
      return(list(plot = NULL, qic_data = NULL, cache_key = cache_key))
    }

    set_plot_state("plot_warnings", character(0))

    computation <- safe_operation(
      "Generate SPC plot",
      code = {
        # M10: Hent viewport dimensions fra centraliseret state
        vp_dims <- get_viewport_dims(app_state)

        # SPRINT 4: Pass QIC cache for performance optimization
        qic_cache <- if (!is.null(app_state) && !is.null(app_state$cache)) {
          get_or_init_qic_cache(app_state)
        } else {
          NULL
        }

        spc_result <- generateSPCPlot(
          data = inputs$data,
          config = inputs$config,
          chart_type = inputs$chart_type,
          target_value = inputs$target_value,
          target_text = inputs$target_text,
          centerline_value = inputs$centerline_value,
          show_phases = inputs$skift_config$show_phases %||% FALSE,
          skift_column = inputs$skift_config$skift_column,
          frys_column = inputs$frys_column,
          chart_title_reactive = NULL, # Will be passed at call site
          y_axis_unit = inputs$y_axis_unit,
          kommentar_column = inputs$kommentar_column,
          base_size = inputs$base_size,
          viewport_width = vp_dims$width,
          viewport_height = vp_dims$height,
          qic_cache = qic_cache,
          plot_context = "analysis" # M11: Analyse-side uses "analysis" context
        )

        # CRITICAL: Skip applyHospitalTheme() for BFHcharts plots
        # BFHcharts applies its own theme and label layers which are incompatible
        # with our theme system. Check metadata$backend flag to determine if plot
        # came from BFHcharts or qicharts2.
        is_bfhcharts <- !is.null(spc_result$metadata$backend) &&
          spc_result$metadata$backend == "bfhcharts"

        # Hospital theming now handled by BFHcharts backend
        # qicharts2 fallback plots returned unstyled (theme handling moved to BFHcharts)
        plot <- spc_result$plot

        qic_data <- spc_result$qic_data

        set_plot_state("plot_object", plot)
        set_plot_state("plot_ready", TRUE)

        if (!is.null(qic_data)) {
          show_phases <- inputs$skift_config$show_phases %||% FALSE
          anhoej <- derive_anhoej_results(qic_data, show_phases = show_phases)

          qic_results <- list(
            any_signal = any(qic_data$sigma.signal, na.rm = TRUE),
            # Konsistent med BFHcharts' PDF-tabel: tael outliers i seneste part.
            out_of_control_count = count_outliers_latest_part(qic_data),
            runs_signal = anhoej$runs_signal,
            crossings_signal = anhoej$crossings_signal,
            anhoej_signal = anhoej$anhoej_signal,
            longest_run = anhoej$longest_run,
            longest_run_max = anhoej$longest_run_max,
            n_crossings = anhoej$n_crossings,
            n_crossings_min = anhoej$n_crossings_min,
            message = if (inputs$chart_type == "run") {
              if (any(qic_data$sigma.signal, na.rm = TRUE)) "S\u00e6rlig \u00e5rsag detekteret" else "Ingen s\u00e6rlige \u00e5rsager fundet"
            } else {
              if (any(qic_data$sigma.signal, na.rm = TRUE)) "Punkter uden for kontrol detekteret" else "Alle punkter inden for kontrol"
            }
          )

          # NA-handling og bevar/opdater-politik centraliseret
          current_anhoej <- get_plot_state("anhoej_results")
          updated_anhoej <- update_anhoej_results(current_anhoej, qic_results, centerline_changed)

          # Log kun naar vi reelt aendrer state (for at reducere stoej)
          if (!identical(updated_anhoej, current_anhoej)) {
            log_debug(
              sprintf(
                "Anhoej update (centerline_changed=%s): longest_run=%s n_crossings=%s",
                as.character(centerline_changed),
                as.character(updated_anhoej$longest_run),
                as.character(updated_anhoej$n_crossings)
              ),
              .context = "VISUALIZATION"
            )
            set_plot_state("anhoej_results", updated_anhoej)
          }
          # Opdater sidste kendte centerline vaerdi EFTER vi har brugt den til changed-detektion
          app_state$visualization$last_centerline_value <- inputs$centerline_value
        } else {
          # No qic_data - set to default state with informative message
          log_info("No qic_data available - setting default anhoej_results", .context = "VISUALIZATION")
          set_plot_state("anhoej_results", list(
            longest_run = NA_real_,
            longest_run_max = NA_real_,
            n_crossings = NA_real_,
            n_crossings_min = NA_real_,
            out_of_control_count = 0L,
            runs_signal = FALSE,
            crossings_signal = FALSE,
            anhoej_signal = FALSE,
            any_signal = FALSE,
            message = "Ingen data at analysere",
            has_valid_data = FALSE
          ))
        }

        list(plot = plot, qic_data = qic_data)
      },
      fallback = function(e) {
        user_msg <- spc_error_user_message(e)
        log_error(
          paste("Graf-generering fejlede:", e$message),
          .context = "SPC_PIPELINE"
        )
        set_plot_state("plot_warnings", user_msg)
        set_plot_state("plot_ready", FALSE)
        set_plot_state("anhoej_results", list(
          longest_run = NA_real_,
          longest_run_max = NA_real_,
          n_crossings = NA_real_,
          n_crossings_min = NA_real_,
          out_of_control_count = 0L,
          runs_signal = FALSE,
          crossings_signal = FALSE,
          anhoej_signal = FALSE,
          any_signal = FALSE,
          message = user_msg,
          has_valid_data = FALSE
        ))
        set_plot_state("plot_object", NULL)
        list(plot = NULL, qic_data = NULL)
      },
      error_type = "processing"
    )

    list(
      plot = computation$plot,
      qic_data = computation$qic_data,
      cache_key = cache_key
    )
  }) |>
    shiny::bindCache({
      inputs <- spc_inputs_reactive()
      # M11: Context-aware cache binding
      # Issue #62: Include context and viewport dimensions for cache isolation
      plot_context <- "analysis"
      vp_dims <- get_viewport_dims(app_state)

      list(
        "spc_results",
        plot_context, # NEW: Context identifier ensures separate cache per context
        inputs$data_hash,
        inputs$chart_type,
        paste0(inputs$config$x_col %||% "NULL", "|", inputs$config$y_col %||% "NULL", "|", inputs$config$n_col %||% "NULL"),
        inputs$target_value,
        inputs$target_text, # CRITICAL: Include target_text for operator invalidation
        inputs$centerline_value,
        inputs$skift_hash,
        inputs$frys_hash,
        inputs$title,
        inputs$y_axis_unit,
        inputs$kommentar_column,
        inputs$base_size, # FIX: Invalider cache ved breddeaendring/fuldskaerm
        vp_dims$width, # NEW: Invalidate cache on viewport width change
        vp_dims$height # NEW: Invalidate cache on viewport height change
      )
    })
}

#' Create SPC Plot Reactive
#'
#' Extracts plot object from spc_results, handling NULL cases gracefully.
#' Includes responsive caching based on cache key and base font size.
#'
#' @param spc_results_reactive Reactive expression returning SPC computation results
#' @param spc_inputs_reactive Reactive expression returning SPC parameters
#' @param app_state Reactive values object (for get_viewport_dims)
#'
#' @return Reactive expression returning ggplot2 object or NULL
#'
#' @keywords internal
create_spc_plot_reactive <- function(
  spc_results_reactive,
  spc_inputs_reactive,
  app_state
) {
  shiny::reactive({
    result <- spc_results_reactive()
    if (is.null(result$plot)) {
      return(NULL)
    }

    log_debug(
      sprintf("ggplot_startup_call cache_key=%s", result$cache_key),
      .context = "SPC_PIPELINE"
    )

    result$plot
  }) |>
    shiny::bindCache({
      result <- spc_results_reactive()
      inputs <- spc_inputs_reactive()
      list(
        "spc_plot",
        result$cache_key %||% "empty",
        inputs$base_size # FIX: Eksplicit breddeafhaengig invalidering
      )
    })
}

#' Register Cache-Aware Observer
#'
#' Ensures anhoej_results are updated even when bindCache short-circuits
#' spc_results reactive body (cache hit). Handles state synchronization
#' and Anhoej signal computation.
#'
#' @param spc_results_reactive Reactive expression returning SPC results
#' @param app_state Reactive values object
#' @param set_plot_state Function to update plot state
#' @param get_plot_state Function to read plot state
#'
#' @return NULL (side effect: registers observer)
#'
#' @keywords internal
register_cache_aware_observer <- function(
  spc_results_reactive,
  app_state,
  set_plot_state,
  get_plot_state,
  skift_config_reactive
) {
  shiny::observeEvent(
    list(spc_results_reactive(), skift_config_reactive()),
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$UI_SYNC,
    {
      result <- spc_results_reactive()
      qic_data <- result$qic_data

      if (is.null(qic_data)) {
        return()
      }

      # Cache hits: bindCache short-circuiter spc_results reactive body,
      # saa set_plot_state("plot_ready", TRUE) kaldes aldrig. Vi har et
      # gyldigt result med qic_data her, saa plot er de-facto klar.
      # Issue #193: Uden dette viser anhoej-bokse "Behandler data og
      # beregner..." permanent efter session restore.
      if (!is.null(result$plot)) {
        set_plot_state("plot_ready", TRUE)
        set_plot_state("is_computing", FALSE)
        set_plot_state("plot_object", result$plot)
      }

      # Hent show_phases fra skift_config reactive
      skift_config <- skift_config_reactive()
      show_phases <- skift_config$show_phases %||% FALSE

      anhoej <- derive_anhoej_results(qic_data, show_phases = show_phases)

      qic_results <- list(
        any_signal = any(qic_data$sigma.signal, na.rm = TRUE),
        # Konsistent med BFHcharts' PDF-tabel: tael outliers i seneste part.
        out_of_control_count = count_outliers_latest_part(qic_data),
        runs_signal = anhoej$runs_signal,
        crossings_signal = anhoej$crossings_signal,
        anhoej_signal = anhoej$anhoej_signal,
        longest_run = anhoej$longest_run,
        longest_run_max = anhoej$longest_run_max,
        n_crossings = anhoej$n_crossings,
        n_crossings_min = anhoej$n_crossings_min
      )

      current_anhoej <- get_plot_state("anhoej_results")

      # Opdater altid naar vi har gyldige metrics, ellers bevar hvis tidligere var gyldige
      updated_anhoej <- update_anhoej_results(current_anhoej, qic_results,
        centerline_changed = FALSE
      )

      if (!identical(updated_anhoej, current_anhoej)) {
        log_debug(
          sprintf(
            "Anhoej refresh (cache-aware): longest_run=%s n_crossings=%s",
            as.character(updated_anhoej$longest_run),
            as.character(updated_anhoej$n_crossings)
          ),
          .context = "VISUALIZATION"
        )
        set_plot_state("anhoej_results", updated_anhoej)
      }
    }
  )
}
