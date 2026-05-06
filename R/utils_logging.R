# utils_logging.R
# Konfigurerbart logging system til SPC App (Shiny-sikkert)

#' Log levels liste til SPC App logging system
#'
#' Definerer numeriske vaerdier for forskellige log-niveauer til brug i det
#' konfigurerede logging-system. **Lavere tal betyder hoejere prioritet.**
#'
#' @details
#' Log levels:
#' - DEBUG (1): Detaljeret debug-information
#' - INFO  (2): Generel information
#' - WARN  (3): Advarsler
#' - ERROR (4): Fejlbeskeder
#'
#' @format Liste med 4 elementer
#' @keywords internal
LOG_LEVELS <- list(
  DEBUG = 1L,
  INFO  = 2L,
  WARN  = 3L,
  ERROR = 4L
)

# intern hjaelper (ikke-eksporteret)
.level_name <- function(x) {
  inv <- setNames(names(LOG_LEVELS), unlist(LOG_LEVELS, use.names = FALSE))
  inv[as.character(x)] %||% "INFO"
}

# intern hjaelper (ikke-eksporteret)
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || identical(a, "")) b else a

#' Hent aktuel log level fra environment variabel
#'
#' Laeser `SPC_LOG_LEVEL` fra environment og returnerer tilsvarende numeriske vaerdi.
#' Understoetter baade navne (f.eks. `"DEBUG"`) og tal (f.eks. `"1"`).
#' Fald tilbage til `INFO` ved ugyldig vaerdi.
#'
#' @return Heltalsvaerdi svarende til log-niveau (se `LOG_LEVELS`)
#' @examples
#' \dontrun{
#' get_log_level()
#' Sys.setenv(SPC_LOG_LEVEL = "DEBUG")
#' get_log_level()
#' Sys.setenv(SPC_LOG_LEVEL = "1")
#' get_log_level()
#' }
#' @keywords internal
get_log_level <- function() {
  env_raw <- safe_getenv("SPC_LOG_LEVEL", "INFO", "character")
  env_val <- trimws(toupper(as.character(env_raw)))

  lvl_num <-
    if (nzchar(env_val) && !is.na(suppressWarnings(as.integer(env_val)))) {
      as.integer(env_val)
    } else {
      LOG_LEVELS[[env_val]]
    }

  if (is.null(lvl_num) || is.na(lvl_num)) LOG_LEVELS$INFO else lvl_num
}

#' Get effective log level with unified precedence rules
#'
#' Resolves log level following unified precedence rules:
#'
#' **Precedence (highest to lowest):**
#' 1. Environment variable: `SPC_LOG_LEVEL` (override)
#' 2. Golem config YAML: `logging.level` (configuration)
#' 3. Default: `"INFO"` (fallback)
#'
#' This function provides a single source of truth for log level configuration.
#'
#' @return Character string of effective log level ("DEBUG", "INFO", "WARN", "ERROR")
#'
#' @examples
#' \dontrun{
#' # Default behavior: reads from YAML config
#' get_effective_log_level() # Returns "DEBUG" in dev, "ERROR" in prod
#'
#' # Environment variable overrides YAML
#' Sys.setenv(SPC_LOG_LEVEL = "DEBUG")
#' get_effective_log_level() # Always returns "DEBUG" now
#'
#' # Clear override to use YAML again
#' Sys.unsetenv("SPC_LOG_LEVEL")
#' get_effective_log_level() # Back to YAML config
#' }
#'
#' @keywords internal
get_effective_log_level <- function() {
  # Priority 1: Environment variable (highest priority override)
  # #458: typed env access via safe_getenv
  env_override <- safe_getenv("SPC_LOG_LEVEL", "", "character")
  if (nzchar(trimws(env_override))) {
    env_val <- trimws(toupper(env_override))
    # Validate it's a real log level
    if (env_val %in% names(LOG_LEVELS)) {
      return(env_val)
    }
  }

  # Priority 2: Golem config YAML (configuration)
  yaml_level <- tryCatch(
    {
      # Try to read from YAML config
      if (exists("get_golem_config", mode = "function", where = -1) ||
        exists("get_golem_config", mode = "function", inherits = TRUE)) {
        config_val <- get_golem_config("logging")$level
        if (!is.null(config_val) && nzchar(as.character(config_val))) {
          trimws(toupper(as.character(config_val)))
        } else {
          NULL
        }
      } else {
        NULL
      }
    },
    # Silent-fail korrekt: golem-config er ikke tilgaengelig under bootstrap/tests
    error = function(e) NULL # nolint: swallowed_error_linter
  )

  if (!is.null(yaml_level) && yaml_level %in% names(LOG_LEVELS)) {
    return(yaml_level)
  }

  # Priority 3: Default fallback
  "INFO"
}

# intern hjaelper (ikke-eksporteret)
.should_log <- function(level_chr) {
  lvl <- LOG_LEVELS[[toupper(level_chr)]]
  if (is.null(lvl)) {
    return(FALSE)
  }
  # Use get_effective_log_level() for unified precedence
  effective_level <- get_effective_log_level()
  cur <- LOG_LEVELS[[effective_level]]
  if (is.null(cur)) cur <- LOG_LEVELS$INFO
  lvl >= cur
}

# intern hjaelper (ikke-eksporteret)
# Checker om et givet context skal logges baseret paa spc.debug.context option
.should_log_context <- function(context) {
  # Hent den filtrerede context liste fra option
  filtered_contexts <- getOption("spc.debug.context", default = NULL)

  # Hvis option ikke er sat eller er NULL, log alt (default behavior)
  if (is.null(filtered_contexts)) {
    return(TRUE)
  }

  # Hvis der er "__EMPTY__" marker (tom liste), log intet
  if (identical(filtered_contexts, "__EMPTY__")) {
    return(FALSE)
  }

  # Hvis der er en tom vektor (c()), log intet (shouldn't happen due to R options behavior)
  if (length(filtered_contexts) == 0) {
    return(FALSE)
  }

  # Hvis context er NULL/UNSPECIFIED, log kun hvis det er eksplicit tilladt
  if (is.null(context) || context == "UNSPECIFIED") {
    return("UNSPECIFIED" %in% filtered_contexts)
  }

  # Check om context er i listen
  context %in% filtered_contexts
}

# intern hjaelper (ikke-eksporteret)
.safe_format <- function(x) {
  # Direct tryCatch to avoid circular dependency with safe_operation
  tryCatch(
    {
      if (is.null(x)) {
        return("NULL")
      }
      if (is.character(x)) {
        return(paste(x, collapse = " "))
      }
      if (is.atomic(x)) {
        if (length(x) > 10) {
          return(paste0(
            paste(utils::head(x, 10), collapse = " "),
            " \u2026 (n=", length(x), ")"
          ))
        } else {
          return(paste(x, collapse = " "))
        }
      }
      if (is.data.frame(x)) {
        return(sprintf(
          "<data.frame: %d x %d> cols=[%s%s]",
          nrow(x), ncol(x),
          paste(utils::head(names(x), 6), collapse = ", "),
          if (ncol(x) > 6) ", \u2026" else ""
        ))
      }
      if (is.list(x)) {
        nms <- names(x) %||% rep("", length(x))
        shown <- utils::head(seq_along(x), 6)
        keys <- ifelse(nchar(nms[shown]) > 0, nms[shown], shown)
        return(sprintf(
          "<list: %d> [%s%s]",
          length(x),
          paste(keys, collapse = ", "),
          if (length(x) > 6) ", \u2026" else ""
        ))
      }
      paste(capture.output(utils::str(x, max.level = 1, vec.len = 10, give.attr = FALSE)),
        collapse = " "
      )
    },
    error = function(e) {
      paste0("<FORMAT_ERROR: ", conditionMessage(e), ">")
    }
  )
}

# intern hjaelper (ikke-eksporteret)
.safe_collapse <- function(args_list) {
  tryCatch(
    {
      parts <- purrr::map(args_list, .safe_format)
      paste(unlist(parts, use.names = FALSE), collapse = " ")
    },
    error = function(e) {
      paste0("<COLLAPSE_ERROR: ", conditionMessage(e), ">")
    }
  )
}

# intern hjaelper (ikke-eksporteret)
.component_or_fallback <- function(x) x %||% "UNSPECIFIED"

# intern hjaelper (ikke-eksporteret)
.timestamp <- function() format(Sys.time(), "%H:%M:%S")

# intern hjaelper (ikke-eksporteret)
# Redacts values whose key names match common secret patterns.
.redact_secrets <- function(details) {
  if (is.null(details) || length(details) == 0) {
    return(details)
  }
  secret_pattern <- "(?i)(key|token|pat|password|secret|credential)"
  lapply(seq_along(details), function(i) {
    nm <- names(details)[i]
    if (!is.null(nm) && grepl(secret_pattern, nm, perl = TRUE)) {
      "***REDACTED***"
    } else {
      details[[i]]
    }
  }) |> setNames(names(details))
}

#' Primaer logging-funktion med level-filtering
#'
#' Central logging-funktion der haandterer alle log-beskeder med automatisk
#' level-filtering baseret paa `SPC_LOG_LEVEL`.
#'
#' @param message Besked (karakter/string) der skal logges
#' @param level Log-niveau som string. Gyldige vaerdier: `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`
#' @param component Valgfrit komponent-tag for organisering (f.eks. `"AUTO_DETECT"`, `"FILE_UPLOAD"`)
#'
#' @return `invisible(NULL)`. Beskeder skrives til konsol hvis niveauet tillader det.
#' @examples
#' \dontrun{
#' log_msg("System startet", "INFO")
#' log_msg("Data laest", "INFO", "FILE_UPLOAD")
#' Sys.setenv(SPC_LOG_LEVEL = "DEBUG")
#' log_msg("Detaljer", "DEBUG", "DATA_PROC")
#' }
#' @keywords internal
log_msg <- function(message, level = "INFO", component = NULL) {
  if (!.should_log(level)) {
    return(invisible(NULL))
  }

  ts <- .timestamp()
  comp <- .component_or_fallback(component)
  comp_str <- if (!is.null(component)) paste0("[", comp, "] ") else ""

  cat(sprintf(
    "[%s] %s: %s%s\n",
    ts,
    toupper(level),
    comp_str,
    as.character(message)
  ))
  invisible(NULL)
}

#' Log debug-besked (variadisk og Shiny-sikker)
#'
#' Convenience-funktion til logging af DEBUG-beskeder.
#' Accepterer vilkaarligt antal argumenter (`...`) og formaterer dem robust
#' (taaler lister, data.frames m.m.) uden at crashe i Shiny renderers.
#'
#' **Kontekst-filtrering:**
#' Naar `spc.debug.context` option er sat, logges kun debug-beskeder hvis deres
#' `.context` er i listen. Goer det muligt at filtrere debugging-output ned til
#' relevante omraader uden at oege token-forbrug.
#'
#' @param ... Variable argumenter der sammenkaedes til en debug-besked
#' @param .context Valgfri kontekst-tag (f.eks. `"RENDER_PLOT"`, `"AUTO_DETECT"`)
#'
#' @return `invisible(NULL)`.
#' @examples
#' \dontrun{
#' log_debug("Status:", TRUE, .context = "RENDER_PLOT")
#' log_debug("Raekke:", 42, list(a = 1), .context = "DATA_PROC")
#'
#' # Kontekst-filtrering
#' options(spc.debug.context = c("state", "data", "ai"))
#' log_debug("Dette logges", .context = "state") # Log
#' log_debug("Dette logges ikke", .context = "performance") # Skip
#' }
#' @keywords internal
log_debug <- function(..., .context = NULL) {
  if (!.should_log("DEBUG")) {
    return(invisible(NULL))
  }

  # Kontekst-filtrering: Check hvis spc.debug.context option er sat
  if (!.should_log_context(.context)) {
    return(invisible(NULL))
  }

  component <- .component_or_fallback(.context)

  # Direct tryCatch to avoid circular dependency with safe_operation
  tryCatch(
    {
      msg <- .safe_collapse(list(...))
      log_msg(msg, "DEBUG", component = component)
    },
    error = function(e) {
      # Forbedret fejlsikker fallback med debugging information
      try(
        {
          args_count <- length(list(...))
          context_val <- if (is.null(.context)) "NULL" else as.character(.context)
          # Use structured fallback matching log_msg pattern
          ts <- .timestamp()
          cat(sprintf(
            "[%s] DEBUG: [%s] [LOGGING_ERROR] Could not format message (args=%d, error=%s)\n",
            ts, component, args_count, conditionMessage(e)
          ))
        },
        silent = TRUE
      )
    }
  )

  invisible(NULL)
}

#' Log information-besked
#'
#' Convenience-funktion til logging af INFO-beskeder.
#'
#' **Kontekst-filtrering:**
#' Understoetter samme kontekst-filtrering som `log_debug()` via `spc.debug.context` option.
#'
#' @param message Besked der skal logges
#' @param component Valgfri komponent-tag (f.eks. `"FILE_UPLOAD"`) - legacy parameter
#' @param .context Valgfri kontekst-tag (f.eks. `"FILE_UPLOAD"`) - preferred parameter
#' @param details Valgfri liste med struktureret data der skal logges sammen med beskeden
#'
#' @return `invisible(NULL)`.
#' @examples
#' \dontrun{
#' log_info("Fil uploaded succesfuldt", .context = "FILE_UPLOAD")
#' log_info(message = "Data processeret", component = "[DATA_PROCESSING]", details = list(rows = 100))
#' }
#' @keywords internal
log_info <- function(message = NULL, component = NULL, .context = NULL, details = NULL) {
  # Support both component and .context for consistency with log_debug
  context <- .context %||% component

  # Kontekst-filtrering: Check hvis spc.debug.context option er sat
  if (!.should_log_context(context)) {
    return(invisible(NULL))
  }

  # If details are provided, format them as structured data
  if (!is.null(details)) {
    details_formatted <- tryCatch(
      {
        details_safe <- lapply(.redact_secrets(details), function(x) if (is.null(x)) "NULL" else x)
        details_str <- paste(names(details_safe), unlist(details_safe, use.names = FALSE), sep = "=", collapse = ", ")
        paste0(message, " [", details_str, "]")
      },
      error = function(e) {
        paste0(message, " [details_format_error]")
      }
    )
    log_msg(details_formatted, "INFO", context)
  } else {
    log_msg(message, "INFO", context)
  }
}

#' Log warning-besked
#'
#' Convenience-funktion til logging af WARN-beskeder.
#'
#' **Kontekst-filtrering:**
#' Understoetter samme kontekst-filtrering som `log_debug()` via `spc.debug.context` option.
#'
#' @param message Besked der skal logges
#' @param component Valgfri komponent-tag (f.eks. `"DATA_VALIDATION"`) - legacy parameter
#' @param .context Valgfri kontekst-tag (f.eks. `"DATA_VALIDATION"`) - preferred parameter
#' @param details Valgfri liste med struktureret data der skal logges sammen med beskeden
#'
#' @return `invisible(NULL)`.
#' @examples
#' \dontrun{
#' log_warn("Manglende data i kolonne", .context = "DATA_VALIDATION")
#' log_warn(
#'   message = "Input sanitized",
#'   component = "[INPUT_SANITIZATION]",
#'   details = list(original_length = 100)
#' )
#' }
#' @keywords internal
log_warn <- function(message = NULL, component = NULL, .context = NULL, details = NULL) {
  # Support both component and .context for consistency with log_debug
  context <- .context %||% component

  # Kontekst-filtrering: Check hvis spc.debug.context option er sat
  if (!.should_log_context(context)) {
    return(invisible(NULL))
  }

  # If details are provided, format them as structured data
  if (!is.null(details)) {
    details_formatted <- tryCatch(
      {
        details_safe <- lapply(.redact_secrets(details), function(x) if (is.null(x)) "NULL" else x)
        details_str <- paste(names(details_safe), unlist(details_safe, use.names = FALSE), sep = "=", collapse = ", ")
        paste0(message, " [", details_str, "]")
      },
      error = function(e) {
        paste0(message, " [details_format_error]")
      }
    )
    log_msg(details_formatted, "WARN", context)
  } else {
    log_msg(message, "WARN", context)
  }
}

#' Log error-besked
#'
#' Convenience-funktion til logging af ERROR-beskeder. Accepterer ogsaa en
#' `condition` direkte (beskeden udtraekkes med `conditionMessage()`).
#'
#' **Kontekst-filtrering:**
#' Understoetter samme kontekst-filtrering som `log_debug()` via `spc.debug.context` option.
#'
#' @param message Besked eller condition der skal logges
#' @param component Valgfri komponent-tag (f.eks. `"ERROR_HANDLING"`) - legacy parameter
#' @param .context Valgfri kontekst-tag (f.eks. `"ERROR_HANDLING"`) - preferred parameter
#' @param details Valgfri liste med struktureret data der skal logges sammen med beskeden
#'
#' @return `invisible(NULL)`.
#' @examples
#' \dontrun{
#' log_error("Kunne ikke laese fil", .context = "FILE_UPLOAD")
#' log_error(
#'   message = "File validation failed",
#'   component = "[FILE_VALIDATION]",
#'   details = list(filename = "test.txt")
#' )
#' tryCatch(stop("Boom"), error = function(e) log_error(e, .context = "PIPELINE"))
#' }
#' @keywords internal
log_error <- function(message = NULL, component = NULL, .context = NULL, details = NULL) {
  # Support both component and .context for consistency with log_debug
  context <- .context %||% component

  # Kontekst-filtrering: Check hvis spc.debug.context option er sat
  if (!.should_log_context(context)) {
    return(invisible(NULL))
  }

  msg <- if (inherits(message, "condition")) conditionMessage(message) else message

  # If details are provided, format them as structured data
  if (!is.null(details)) {
    details_formatted <- tryCatch(
      {
        details_safe <- lapply(.redact_secrets(details), function(x) if (is.null(x)) "NULL" else x)
        details_str <- paste(names(details_safe), unlist(details_safe, use.names = FALSE), sep = "=", collapse = ", ")
        paste0(msg, " [", details_str, "]")
      },
      error = function(e) {
        paste0(msg, " [details_format_error]")
      }
    )
    log_msg(details_formatted, "ERROR", context)
  } else {
    log_msg(msg, "ERROR", context)
  }
}

#' Log afgraensede debug-blokke (start/stop)
#'
#' Helper-funktion til logging af visuelt afgraensede debug-blokke
#' med separatorlinjer. Erstatter hardcodede separatorer i koden.
#'
#' @param context Kontekst-tag for blokken (f.eks. `"COLUMN_MGMT"`, `"AUTO_DETECT"`)
#' @param action Beskrivelse af handlingen (f.eks. `"Starting column detection"`)
#' @param type Type af markering: `"start"`, `"stop"`, eller `"both"` (default `"start"`)
#'
#' @return `invisible(NULL)`.
#' @examples
#' \dontrun{
#' log_debug_block("COLUMN_MGMT", "Starting column detection")
#' # ... kode ...
#' log_debug_block("COLUMN_MGMT", "Column detection completed", type = "stop")
#' }
#' @keywords internal
log_debug_block <- function(context, action, type = "start") {
  if (!.should_log("DEBUG")) {
    return(invisible(NULL))
  }

  sep <- paste(rep("=", 50), collapse = "")

  ctx <- .component_or_fallback(context)
  t <- match.arg(type, choices = c("start", "stop", "both"))

  if (t %in% c("start", "both")) {
    log_debug(sep, .context = ctx)
    log_debug(action, .context = ctx)
  }
  if (t %in% c("stop", "both")) {
    log_debug(paste0(action, " - completed"), .context = ctx)
    log_debug(sep, .context = ctx)
  }

  invisible(NULL)
}

#' Log strukturerede key-value par (kompakt)
#'
#' Helper-funktion til logging af strukturerede key-value data.
#' Understoetter baade navngivne `...`-argumenter og en liste via `.list_data`.
#' Vaerdier formatteres robust (taaler komplekse objekter) uden at crashe i Shiny.
#'
#' @param ... Navngivne argumenter der logges som key-value (`navn = vaerdi`)
#' @param .context Kontekst-tag (f.eks. `"DATA_PROC"`, `"AUTO_DETECT"`)
#' @param .list_data Valgfri liste med key-value data
#'
#' @return `invisible(NULL)`.
#' @examples
#' \dontrun{
#' log_debug_kv(trigger_value = 1, status = "active", .context = "DATA_TABLE")
#' log_debug_kv(.list_data = list(rows = 100, cols = 5), .context = "DATA_PROC")
#' }
#' @keywords internal
log_debug_kv <- function(..., .context = NULL, .list_data = NULL) {
  if (!.should_log("DEBUG")) {
    return(invisible(NULL))
  }

  ctx <- .component_or_fallback(.context)

  dots <- list(...)
  if (length(dots) > 0) {
    nms <- names(dots) %||% rep("", length(dots))
    for (i in seq_along(dots)) {
      key <- nms[[i]] %||% paste0("..", i)
      val <- .safe_format(dots[[i]])
      log_debug(paste0(key, ": ", val), .context = ctx)
    }
  }

  if (!is.null(.list_data) && is.list(.list_data)) {
    nms <- names(.list_data) %||% rep("", length(.list_data))
    for (i in seq_along(.list_data)) {
      key <- nms[[i]] %||% paste0("..", i)
      val <- .safe_format(.list_data[[i]])
      log_debug(paste0(key, ": ", val), .context = ctx)
    }
  }

  invisible(NULL)
}

#' Convenience functions for common log level configurations
#'
#' Helper functions to easily switch between development and production
#' log level configurations. These set the `SPC_LOG_LEVEL` environment
#' variable for the current R session.
#'
#' @return invisible(NULL). The environment variable is set as a side effect.
#' @examples
#' \dontrun{
#' set_log_level_development() # Enables all DEBUG messages
#' set_log_level_production() # Only WARN and ERROR in production
#' set_log_level_quiet() # Only ERROR messages
#' }
#' @keywords internal
set_log_level_development <- function() {
  Sys.setenv(SPC_LOG_LEVEL = "DEBUG")
  message("[LOG_CONFIG] Log level set to DEBUG (development mode)")
  invisible(NULL)
}

#' @rdname set_log_level_development
#' @keywords internal
set_log_level_production <- function() {
  Sys.setenv(SPC_LOG_LEVEL = "WARN")
  message("[LOG_CONFIG] Log level set to WARN (production mode)")
  invisible(NULL)
}

#' @rdname set_log_level_development
#' @keywords internal
set_log_level_quiet <- function() {
  Sys.setenv(SPC_LOG_LEVEL = "ERROR")
  message("[LOG_CONFIG] Log level set to ERROR (quiet mode)")
  invisible(NULL)
}

#' @rdname set_log_level_development
#' @keywords internal
set_log_level_info <- function() {
  Sys.setenv(SPC_LOG_LEVEL = "INFO")
  message("[LOG_CONFIG] Log level set to INFO (standard mode)")
  invisible(NULL)
}

#' Set custom log level
#'
#' Set any custom log level by name. Validates input and provides helpful
#' error messages for invalid levels.
#'
#' @param level Log level string: "DEBUG", "INFO", "WARN", or "ERROR"
#'
#' @examples
#' \dontrun{
#' set_log_level("DEBUG") # Enable all debug messages
#' set_log_level("WARN") # Only warnings and errors
#' set_log_level("invalid") # Shows available options
#' }
#'
#' @keywords internal
set_log_level <- function(level) {
  valid_levels <- c("DEBUG", "INFO", "WARN", "ERROR")
  level <- toupper(trimws(level))

  if (level %in% valid_levels) {
    Sys.setenv(SPC_LOG_LEVEL = level)
    message(sprintf("[LOG_CONFIG] Log level set to %s", level))
    invisible(NULL)
  } else {
    stop(
      sprintf(
        "Invalid log level '%s'. Valid options: %s",
        level, paste(valid_levels, collapse = ", ")
      ),
      call. = FALSE
    )
  }
}

#' Get current log level name
#'
#' Returns the current log level as a string for easy checking
#' and debugging purposes. Uses the same unified precedence rules as
#' `get_effective_log_level()`.
#'
#' @return Character string of current log level ("DEBUG", "INFO", "WARN", or "ERROR")
#'
#' @examples
#' \dontrun{
#' current_level <- get_log_level_name()
#' cat("Current log level:", current_level)
#' }
#'
#' @keywords internal
get_log_level_name <- function() {
  get_effective_log_level()
}

#' Set debug context filtering
#'
#' Setter den `spc.debug.context` option til at filtrere logging baseret paa context.
#' Dette reducerer token-forbrug ved debugging ved kun at logge relevante omraader.
#'
#' **Eksempler:**
#' - `set_debug_context(c("state", "data"))` - log kun state og data contexts
#' - `set_debug_context(NULL)` - log alt (default behavior)
#' - `set_debug_context(character(0))` - log intet
#'
#' @param contexts Character vector af contexts som skal logges, eller `NULL` for at logge alt
#'
#' @return `invisible(NULL)`. Setter `spc.debug.context` option som en side effect.
#'
#' @examples
#' \dontrun{
#' # Log kun state og AI-relateret debugging
#' set_debug_context(c("state", "ai"))
#' log_debug("Dette logges", .context = "state") # [U+2713] Vises
#' log_debug("Dette logges ikke", .context = "performance") # [U+2717] Skjult
#'
#' # Genop alle logninger
#' set_debug_context(NULL)
#' log_debug("Alt logges nu", .context = "performance") # [U+2713] Vises
#' }
#'
#' @keywords internal
set_debug_context <- function(contexts = NULL) {
  if (is.null(contexts)) {
    options(spc.debug.context = NULL)
    message("[LOG_CONFIG] Debug context filtering disabled - logging all contexts")
  } else if (length(contexts) == 0) {
    # Use a special marker to represent "log nothing" since R options converts empty vector to NULL
    options(spc.debug.context = "__EMPTY__")
    message("[LOG_CONFIG] Debug context filtering enabled with empty context list - logging nothing")
  } else {
    # Validate that contexts are character
    if (!is.character(contexts)) {
      stop("contexts must be a character vector or NULL", call. = FALSE)
    }
    options(spc.debug.context = as.character(contexts))
    message(sprintf(
      "[LOG_CONFIG] Debug context filtering enabled - logging: %s",
      paste(contexts, collapse = ", ")
    ))
  }
  invisible(NULL)
}

#' Get current debug context filter
#'
#' Returnerer den nuvaerende `spc.debug.context` option vaerdi.
#'
#' @return Character vector af de filtrerede contexts, eller `NULL` hvis ingen filtrering er aktiv
#'
#' @examples
#' \dontrun{
#' get_debug_context() # NULL = logging alt
#'
#' set_debug_context(c("state", "data"))
#' get_debug_context() # c("state", "data")
#' }
#'
#' @keywords internal
get_debug_context <- function() {
  getOption("spc.debug.context", default = NULL)
}

#' List available log contexts
#'
#' Returnerer alle tilgaengelige log context-vaerdier fra `LOG_CONTEXTS`.
#' Nyttigt til at finde de rigtige context-navne for `set_debug_context()`.
#'
#' @return Character vector af alle tilgaengelige log contexts
#'
#' @examples
#' \dontrun{
#' all_contexts <- list_available_log_contexts()
#' head(all_contexts) # Se de foerste contexts
#'
#' # Brug til at saette filtrering
#' state_contexts <- grep("^state", all_contexts, value = TRUE)
#' set_debug_context(state_contexts)
#' }
#'
#' @keywords internal
list_available_log_contexts <- function() {
  all_contexts <- character()

  for (category in names(LOG_CONTEXTS)) {
    category_contexts <- LOG_CONTEXTS[[category]]
    all_contexts <- c(
      all_contexts,
      unlist(category_contexts, use.names = FALSE)
    )
  }

  return(unique(all_contexts))
}

#' Print all available debug contexts in organized table
#'
#' Viser alle tilgaengelige log contexts organiseret efter kategori.
#' Nyttigt til at finde de rigtige context-navne for `set_debug_context()`.
#'
#' @return Invisible NULL. Printer en organiseret tabel til konsolen.
#'
#' @examples
#' \dontrun{
#' show_debug_contexts() # See all available contexts organized by category
#' }
#'
#' @keywords internal
show_debug_contexts <- function() {
  cat("\n")
  cat("=== AVAILABLE DEBUG CONTEXTS ===\n")
  cat("Use with: set_debug_context(c(\"context1\", \"context2\"))\n")
  cat("\n")

  for (category in names(LOG_CONTEXTS)) {
    category_contexts <- LOG_CONTEXTS[[category]]
    contexts_list <- unlist(category_contexts, use.names = FALSE)

    cat(sprintf("%-20s:", toupper(category)))
    cat(" ")
    cat(paste(contexts_list, collapse = ", "))
    cat("\n")
  }

  cat("\n")
  cat("Examples:\n")
  cat("  set_debug_context(c(\"state\", \"data\", \"ai\"))\n")
  cat("  set_debug_context(c(\"render_plot\", \"y_axis_scaling\"))\n")
  cat("  set_debug_context(NULL)  # Reset to log everything\n")
  cat("\n")

  invisible(NULL)
}

#' Sanitize session token for logging
#'
#' SECURITY: Uses SHA256 hashing (upgraded from simple masking) to prevent
#' session hijacking if logs are compromised. Returns first 8 characters of
#' SHA256 hash for logging identification.
#'
#' @param session_token Character string containing the session token to sanitize
#'
#' @return First 8 characters of SHA256 hash (e.g., "a1b2c3d4") or "NO_SESSION"
#' @examples
#' \dontrun{
#' sanitize_session_token("abc123def456ghi789")
#' # Returns: "a1b2c3d4" (first 8 chars of SHA256 hash)
#'
#' sanitize_session_token(NULL)
#' # Returns: "NO_SESSION"
#' }
#' @keywords internal
sanitize_session_token <- function(session_token) {
  # Handle NULL or empty tokens
  if (is.null(session_token) || !is.character(session_token) || length(session_token) == 0) {
    return("NO_SESSION")
  }

  # Handle invalid tokens (not character or empty)
  token_str <- as.character(session_token[[1]])
  if (nchar(token_str) == 0) {
    return("INVALID_SESSION")
  }

  # SECURITY: Use SHA256 hash (upgraded from simple masking for stronger protection)
  # Return first 8 characters for logging identification
  substr(digest::digest(token_str, algo = "sha256"), 1, 8)
}
