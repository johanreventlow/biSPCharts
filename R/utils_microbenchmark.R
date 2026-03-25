# Microbenchmark Performance Utilities
# Statistical benchmarking for SPC App critical functions

#' Microbenchmark Wrapper for SPC App Functions
#'
#' Provides statistical benchmarking with integrated logging and reporting.
#' Uses microbenchmark package for precise timing measurements with multiple
#' iterations and statistical analysis.
#'
#' @param expr Expression to benchmark (can be a single expression or list)
#' @param times Number of iterations (default: 100)
#' @param operation_name Descriptive name for the operation
#' @param log_results Whether to log results (default: TRUE)
#' @param return_full_results Return full microbenchmark object (default: FALSE)
#' @param capture_result Capture and return the result of the last expression evaluation (default: FALSE)
#'
#' @return List with summary statistics or full microbenchmark results
#' @examples
#' \dontrun{
#' results <- benchmark_spc_operation(
#'   {
#'     autodetect_engine(test_data, "manual", app_state, emit)
#'   },
#'   operation_name = "autodetect_engine"
#' )
#' }
#' @keywords internal
benchmark_spc_operation <- function(expr, times = 100, operation_name = "unknown_operation",
                                    log_results = TRUE, return_full_results = FALSE,
                                    capture_result = FALSE) {
  # Check if microbenchmark is available
  if (!requireNamespace("microbenchmark", quietly = TRUE)) {
    log_warn("microbenchmark package not available - falling back to basic timing",
      .context = "MICROBENCHMARK"
    )

    # Fallback to basic timing
    # NOTE: eval() is used here intentionally to execute benchmark expressions
    # This is standard R benchmarking practice, not arbitrary code evaluation
    start_time <- Sys.time()
    result <- tryCatch(
      eval(expr),
      error = function(e) {
        log_error(paste("Benchmark execution failed:", e$message), .context = "[BENCHMARK]")
        stop("Benchmark execution failed safely")
      }
    )
    execution_time <- as.numeric(Sys.time() - start_time)

    result_data <- list(
      mean_time = execution_time,
      operation = operation_name,
      fallback = TRUE
    )

    if (capture_result) {
      result_data$captured_result <- result
    }

    return(result_data)
  }

  log_debug(paste("Starting microbenchmark for:", operation_name))

  # Execute microbenchmark
  tryCatch(
    {
      mb_results <- microbenchmark::microbenchmark(
        expr,
        times = times,
        unit = "ms"
      )

      # Extract summary statistics
      summary_stats <- summary(mb_results)

      # Create standardized results structure
      results <- list(
        operation = operation_name,
        times = times,
        min_ms = summary_stats$min,
        q1_ms = summary_stats$lq,
        median_ms = summary_stats$median,
        mean_ms = summary_stats$mean,
        q3_ms = summary_stats$uq,
        max_ms = summary_stats$max,
        timestamp = Sys.time(),
        unit = "milliseconds"
      )

      # Add full results if requested
      if (return_full_results) {
        results$full_benchmark <- mb_results
        results$summary_table <- summary_stats
      }

      # Capture result if requested
      if (capture_result) {
        results$captured_result <- tryCatch(
          eval(expr),
          error = function(e) {
            log_error(paste("Benchmark capture failed:", e$message), .context = "[BENCHMARK]")
            NULL
          }
        )
      }

      # Log results if requested
      if (log_results) {
        .log_benchmark_results(results)
      }

      return(results)
    },
    error = function(e) {
      log_error(paste("Microbenchmark failed for", operation_name, ":", e$message))

      # Fallback to basic timing
      start_time <- Sys.time()
      result <- tryCatch(
        eval(expr),
        error = function(e2) {
          log_error(paste("Benchmark fallback failed:", e2$message), .context = "[BENCHMARK]")
          NULL
        }
      )
      execution_time <- as.numeric(Sys.time() - start_time) * 1000

      error_result <- list(
        operation = operation_name,
        mean_ms = execution_time,
        error = e$message,
        fallback = TRUE
      )

      if (capture_result) {
        error_result$captured_result <- result
      }

      return(error_result)
    }
  )
}

#' Log Benchmark Results (internal)
#'
#' @param results Results from benchmark_spc_operation
#' @param warn_threshold Warning threshold in milliseconds (default: 500ms)
#' @keywords internal
.log_benchmark_results <- function(results, warn_threshold = 500) {
  if (is.null(results$median_ms)) {
    log_debug(paste(
      "BENCHMARK:", results$operation, "-",
      round(results$mean_ms, 2), "ms (fallback)"
    ))
    return()
  }

  log_debug_kv(
    operation = results$operation,
    min_ms = round(results$min_ms, 2),
    median_ms = round(results$median_ms, 2),
    mean_ms = round(results$mean_ms, 2),
    max_ms = round(results$max_ms, 2),
    iterations = results$times
  )

  if (results$median_ms > warn_threshold) {
    log_warn(
      paste(
        "SLOW OPERATION:", results$operation, "median:",
        round(results$median_ms, 2), "ms"
      ),
      "PERFORMANCE_WARNING"
    )
  }

  if (grepl("autodetect|qic|plot", results$operation, ignore.case = TRUE)) {
    log_info(
      paste(
        "BENCHMARK COMPLETE:", results$operation,
        "median:", round(results$median_ms, 2), "ms",
        "range:", round(results$min_ms, 2), "-", round(results$max_ms, 2), "ms"
      ),
      "PERFORMANCE_BENCHMARK"
    )
  }
}
