#!/usr/bin/env Rscript
# check_security_config.R
# Pre-deploy validator: sikrer at security-flag i golem-config.yml har
# dokumenteret implementering i app-kode eller infra-dokumentation.
#
# Exit-kode:
#   0 = OK (alle flag kendte)
#   1 = FEJL (ukendte/uimplementerede flag fundet i production-blok)
#
# Brug:
#   Rscript dev/check_security_config.R
#   Rscript dev/check_security_config.R path/to/golem-config.yml
#
# Integration med pre-push hook:
#   Tilfoej `Rscript dev/check_security_config.R` til dev/git-hooks/pre-push
#
# Whitelist-politik:
#   Hvert flag i IMPLEMENTED_FLAGS er enten:
#   (a) Implementeret i app-kode (bevis via grep-reference)
#   (b) Haandteret paa infra-niveau og dokumenteret i docs/DEPLOYMENT.md
#   (c) Ejes af en anden PR (midlertidig whitelist med reference)
#
# Naeste revision: fjern "hide_error_details" naar harden-data-protection-and-export merges.

# ==============================================================================
# Konfiguration
# ==============================================================================

# Flag der er kendte og korrekt haandterede
# Format: navn = forklaring (vises i output ved debug)
IMPLEMENTED_FLAGS <- list(
  allow_debug_endpoints  = "Styret af GOLEM_CONFIG_ACTIVE; debug-endpoints eksponer kun naar allow_debug_endpoints=true",
  hide_error_details     = "Ejes af PR harden-data-protection-and-export (R/fct_file_validation.R linje 390)",
  session_timeout_minutes = "Implementeret via setup_session_timeout() i R/utils_server_session_helpers.R"
)

# Flags der aldrig maa eksistere (configuration theatre elimineret)
FORBIDDEN_FLAGS <- c(
  "require_https",
  "csrf_protection",
  "content_security_policy"
)

DOCS_REF <- "docs/DEPLOYMENT.md#infrastructure-level-security-requirements"

# ==============================================================================
# Hjælpefunktioner
# ==============================================================================

#' Ekstraher security-flag fra en YAML-tekstblok
#'
#' Parser en enkelt environment-blok (fx production:-sektionen) og returnerer
#' navnene paa alle flag under security:-undersektionen.
#'
#' @param yaml_text Character: indhold af YAML-blok som enkelt string
#' @return Character vector med unikke flagnavn
extract_security_flags <- function(yaml_text) {
  lines     <- strsplit(yaml_text, "\n")[[1]]
  flags     <- character(0)
  in_sec    <- FALSE
  sec_indent <- NULL

  ltrim <- function(s) sub("^\\s+", "", s)
  indent_of <- function(s) nchar(s) - nchar(ltrim(s))

  for (line in lines) {
    stripped <- trimws(line)
    ind      <- indent_of(line)

    # Detektion af security:-linje (ikke en kommentar)
    if (!in_sec && grepl("^security\\s*:", stripped) && !startsWith(stripped, "#")) {
      in_sec    <- TRUE
      sec_indent <- ind
      next
    }

    if (!in_sec) next

    # Tom linje: ignorer
    if (stripped == "") next

    # Kommentarlinje: ignorer
    if (startsWith(stripped, "#")) next

    # Ny sektion paa samme/lavere niveau: stop parsing
    if (ind <= sec_indent) {
      in_sec <- FALSE
      next
    }

    # Ekstraher flagnavn (format: "  key: value" eller "  key:")
    m <- regmatches(stripped, regexpr("^[a-zA-Z_][a-zA-Z0-9_]*(?=\\s*:)", stripped, perl = TRUE))
    if (length(m) > 0 && nchar(m) > 0) {
      flags <- c(flags, m)
    }
  }

  unique(flags)
}

#' Isoler en enkelt environment-blok fra golem-config.yml
#'
#' @param yaml_text Character: fuld YAML-filindhold
#' @param env_name Character: environment-navn (fx "production")
#' @return Character: YAML-tekst for den angivne blok, eller NULL
isolate_env_block <- function(yaml_text, env_name) {
  # Soeg baade med og uden foranstaaende newline (haandterer filstart)
  pattern   <- paste0("(^|\n)", env_name, ":")
  m         <- regexpr(pattern, yaml_text, perl = TRUE)
  if (m == -1) return(NULL)

  # Find start af env_name (efter eventuel newline)
  match_str <- regmatches(yaml_text, m)
  offset    <- if (startsWith(match_str, "\n")) 1L else 0L
  start_pos <- m + offset

  remainder <- substring(yaml_text, start_pos)

  # Naeste top-level-key
  next_pos <- regexpr("\n[a-zA-Z_][a-zA-Z0-9_]*:", remainder)
  if (next_pos > 0) {
    substring(remainder, 1, next_pos - 1)
  } else {
    remainder
  }
}

# ==============================================================================
# Hoved-script
# ==============================================================================

# Bestem sti til golem-config.yml
args <- commandArgs(trailingOnly = TRUE)
config_path <- if (length(args) >= 1 && nchar(args[1]) > 0) {
  args[1]
} else {
  "inst/golem-config.yml"
}

if (!file.exists(config_path)) {
  message(sprintf("[check_security_config] FEJL: Fil ikke fundet: %s", config_path))
  quit(status = 1)
}

yaml_text  <- paste(readLines(config_path, encoding = "UTF-8"), collapse = "\n")
prod_block <- isolate_env_block(yaml_text, "production")

if (is.null(prod_block)) {
  message("[check_security_config] FEJL: Ingen 'production:'-sektion fundet i ", config_path)
  quit(status = 1)
}

flags      <- extract_security_flags(prod_block)
known      <- names(IMPLEMENTED_FLAGS)
unknown    <- setdiff(flags, known)
forbidden  <- intersect(flags, FORBIDDEN_FLAGS)

# Rapport
any_error <- FALSE

if (length(forbidden) > 0) {
  any_error <- TRUE
  message(sprintf(
    "\n[check_security_config] FEJL: Forbudte security-flag fundet i production-blok:\n  %s\n",
    paste(forbidden, collapse = "\n  ")
  ))
  message(sprintf(
    "  Disse flag er configuration theatre — de laeses IKKE af app-koden.\n  Fjern dem fra %s\n  Se: %s\n",
    config_path, DOCS_REF
  ))
}

if (length(unknown) > 0) {
  any_error <- TRUE
  message(sprintf(
    "\n[check_security_config] FEJL: Uimplementerede security-flag i production-blok:\n  %s\n",
    paste(unknown, collapse = "\n  ")
  ))
  message("  Hvert security-flag skal enten:")
  message("  (a) Implementeres i app-kode (tilfoej til IMPLEMENTED_FLAGS med kilde-reference)")
  message("  (b) Flyttes til infra-konfiguration og fjernes fra golem-config.yml")
  message(sprintf("  Se: %s\n", DOCS_REF))
}

if (!any_error) {
  message(sprintf(
    "[check_security_config] OK: %d security-flag i production-blok, alle kendte.",
    length(flags)
  ))
  if (length(flags) > 0) {
    for (f in flags) {
      message(sprintf("  ✓ %s: %s", f, IMPLEMENTED_FLAGS[[f]]))
    }
  }
  quit(status = 0)
} else {
  quit(status = 1)
}
