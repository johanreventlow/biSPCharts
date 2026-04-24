# utils_error_handling.R
# Centralized error handling utilities for SPC App

#' Safe operation wrapper with error handling
#'
#' Provides a standardized way to execute code with error handling and
#' fallback behavior. Designed to prevent crashes in reactive contexts
#' and provide graceful degradation.
#'
#' @section CRITICAL - Return Value Semantics:
#' **DO NOT use `return()` statements inside the code block!**
#'
#' R's `force()` evaluation does not correctly propagate `return()` values.
#' Using `return(value)` inside the code block will return `NULL` instead
#' of the expected value.
#'
#' **Correct pattern:** Let the last expression in the code block be the
#' value you want to return.
#'
#' ```
#' # WRONG - returns NULL:
#' safe_operation("test", code = {
#'   result <- compute()
#'   return(result)  # BUG: returns NULL!
#' })
#'
#' # CORRECT - returns result:
#' safe_operation("test", code = {
#'   result <- compute()
#'   result  # Works correctly
#' })
#' ```
#'
#' For early exits, use conditional flow with a result variable instead:
#' ```
#' safe_operation("test", code = {
#'   result <- default_value
#'   if (condition) {
#'     result <- compute_result()
#'   }
#'   result
#' })
#' ```
#'
#' @param operation_name Character string describing the operation for logging
#' @param code Expression or code block to execute safely
#' @param fallback Default value to return if operation fails. Default is NULL.
#' @param session Shiny session object for user notifications (optional)
#' @param show_user Logical, whether to show error to user (default FALSE)
#' @param error_type Character string categorizing the error type for logging
#'
#' @return Result of code execution, or fallback value if error occurs
#' @examples
#' \dontrun{
#' # Basic usage
#' result <- safe_operation(
#'   "Data processing",
#'   code = {
#'     process_data(input_data)
#'   },
#'   fallback = empty_data()
#' )
#'
#' # With session and user notification
#' result <- safe_operation(
#'   "File upload",
#'   code = {
#'     read.csv(file_path)
#'   },
#'   fallback = NULL,
#'   session = session,
#'   show_user = TRUE
#' )
#' }
#' @keywords internal
safe_operation <- function(operation_name, code, fallback = NULL, session = NULL, show_user = FALSE, error_type = "general", ...) {
  tryCatch(
    {
      force(code)
    },
    error = function(e) {
      # Basic error message construction
      error_msg <- paste(operation_name, "fejlede:", e$message)

      # Try centralized logging with multi-level fallback strategy
      logging_succeeded <- FALSE

      # LEVEL 1: Try structured log_error() if available
      if (exists("log_error", mode = "function")) {
        tryCatch(
          {
            log_error(
              message = error_msg,
              .context = paste0("ERROR_HANDLING_", toupper(error_type)),
              details = list(
                operation = operation_name,
                error_class = class(e)[1],
                error_message = e$message
              )
            )
            logging_succeeded <- TRUE
          },
          error = function(log_err) {
            # Fall through to next level if log_error fails
            logging_succeeded <<- FALSE
          }
        )
      }

      # LEVEL 2: Try basic log_msg() if log_error failed/unavailable
      if (!logging_succeeded && exists("log_msg", mode = "function")) {
        tryCatch(
          {
            log_msg(
              message = error_msg,
              level = "ERROR",
              component = paste0("ERROR_HANDLING_", toupper(error_type))
            )
            logging_succeeded <- TRUE
          },
          error = function(log_err) {
            # Fall through to final fallback
            logging_succeeded <<- FALSE
          }
        )
      }

      # LEVEL 3: Absolute fallback - minimal output only if all logging failed
      if (!logging_succeeded) {
        # Use minimal structured format matching log_msg pattern
        # This should rarely happen in production
        tryCatch(
          {
            # Use message() for last-resort fallback (standard R approach)
            message(sprintf(
              "[ERROR_HANDLING_%s] %s",
              toupper(error_type),
              error_msg
            ))
          },
          error = function(final_err) {
            # Absolute last resort - completely silent failure to avoid cascade
            # Do nothing - error already occurred, don't make it worse
          }
        )
      }

      # User notification if session provided and requested
      if (!is.null(session) && show_user) {
        tryCatch(
          {
            shiny::showNotification(
              paste("Fejl:", operation_name),
              type = "error",
              duration = 5
            )
          },
          error = function(notification_err) {
            # Silent failure for notifications to avoid cascading errors
          }
        )
      }

      # Handle fallback execution based on type
      if (is.function(fallback)) {
        # Call fallback function with error parameter
        return(fallback(e))
      } else {
        # Return fallback value directly
        return(fallback)
      }
    }
  )
}

#' Validate required objects exist before operation
#'
#' Helper function to check that required objects/variables exist
#' before attempting operations. Prevents common "object not found" errors.
#'
#' @param ... Named arguments where names are variable names and values are environments to check
#' @param error_message Custom error message if validation fails
#'
#' @return TRUE if all objects exist, throws error otherwise
#' @examples
#' \dontrun{
#' validate_exists(
#'   data = environment(),
#'   session = environment(),
#'   error_message = "Required objects missing for data processing"
#' )
#' }
#' @keywords internal
validate_exists <- function(..., error_message = "Required objects not found") {
  args <- list(...)

  for (var_name in names(args)) {
    env <- args[[var_name]]
    if (!exists(var_name, envir = env)) {
      stop(paste(error_message, "- missing:", var_name))
    }
  }

  return(TRUE)
}

#' Safe environment variable retrieval
#'
#' Safely retrieve environment variables with fallback values
#' and type conversion.
#'
#' @param var_name Environment variable name
#' @param default Default value if variable not set
#' @param type Expected type: "character", "logical", "numeric"
#'
#' @return Environment variable value converted to specified type, or default
#' @examples
#' \dontrun{
#' safe_getenv("DEBUG_MODE", FALSE, "logical")
#' safe_getenv("MAX_ROWS", 1000, "numeric")
#' }
#' @keywords internal
safe_getenv <- function(var_name, default = "", type = "character") {
  value <- Sys.getenv(var_name, unset = default)

  safe_operation(
    paste("Environment variable conversion:", var_name),
    code = {
      switch(type,
        "character" = as.character(value),
        "logical" = {
          if (is.logical(default) && value == "") {
            default
          } else if (is.logical(default)) {
            as.logical(value)
          } else {
            as.character(value)
          }
        },
        "numeric" = {
          if (value == "") {
            default
          } else {
            as.numeric(value)
          }
        },
        as.character(value)
      )
    },
    fallback = default,
    error_type = "configuration"
  )
}

#' Typed error helper for SPC pipeline
#'
#' Throws a typed condition that inherits from `spc_error` and `error`.
#' Domain helpers use this instead of `stop()` so callers can distinguish
#' failure modes and the orchestrator can catch by class.
#'
#' @section Error classes:
#' - `spc_input_error`: Ugyldig input (forkert chart_type, manglende kolonner).
#' - `spc_prepare_error`: Data-prep fejl (dato-/talparse, filtrering).
#' - `spc_render_error`: BFHcharts-fejl under rendering.
#' - `spc_cache_error`: Cache-læs/skriv fejl (typisk warn, ikke error).
#'
#' All classes inherit from `"spc_error"` → generic `tryCatch(error = ...)` still works.
#'
#' @param message Character string. Dansk bruger-vendt fejlbesked.
#' @param class Character string. One of `"spc_input_error"`, `"spc_prepare_error"`,
#'   `"spc_render_error"`, `"spc_cache_error"`.
#' @param ... Additional metadata passed to `rlang::abort()` (e.g. `data`, `column`).
#' @param call Environment. Defaults to caller environment for correct traceback.
#'
#' @return Does not return — always throws.
#' @keywords internal
spc_abort <- function(message, class, ..., call = rlang::caller_env()) {
  rlang::abort(
    message = message,
    class = c(class, "spc_error", "error", "condition"),
    ...,
    call = call
  )
}

#' Map SPC pipeline error to Danish user message
#'
#' Converts a typed `spc_error` condition to a short Danish message
#' suitable for display in the Shiny UI (e.g. `set_plot_state("plot_warnings", ...)`).
#'
#' @param e A condition object (typically caught by `tryCatch` or `safe_operation`).
#'
#' @return Character scalar with a Danish user message.
#' @keywords internal
spc_error_user_message <- function(e) {
  if (inherits(e, "spc_input_error")) {
    paste("Ugyldigt input:", conditionMessage(e))
  } else if (inherits(e, "spc_prepare_error")) {
    paste("Datafejl:", conditionMessage(e))
  } else if (inherits(e, "spc_render_error")) {
    "Grafgenerering fejlede. Kontroller venligst dine data og indstillinger."
  } else {
    "Grafgenerering fejlede. Kontroller venligst dine data og indstillinger."
  }
}

#' Guard: kræv valgfri pakke eller kast typed error
#'
#' @param pkg Pakkenavn som character string
#' @param reason Kort beskrivelse af hvad pakken bruges til (dansk)
#' @return Invisible NULL hvis pakke er tilgængelig
#' @keywords internal
require_optional_package <- function(pkg, reason = pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cond <- structure(
      class = c("spc_dependency_error", "spc_error", "error", "condition"),
      list(
        message = paste0(
          "Pakken '", pkg, "' er ikke installeret. ",
          "Den er krævet for: ", reason, ". ",
          "Installer med: install.packages('", pkg, "')"
        ),
        package = pkg,
        call = sys.call(-1)
      )
    )
    stop(cond)
  }
  invisible(NULL)
}

#' Guard: kræv qicharts2 for Anhøj-beregninger
#'
#' @return Invisible NULL hvis qicharts2 er tilgængelig
#' @keywords internal
require_qicharts2 <- function() {
  require_optional_package(
    "qicharts2",
    "Anhøj regler og SPC signal-beregning"
  )
}
