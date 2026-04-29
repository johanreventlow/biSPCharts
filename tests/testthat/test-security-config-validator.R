# test-security-config-validator.R
# TDD: Tests for dev/check_security_config.R pre-deploy validator
# Verificerer at scriptet returnerer korrekt exit-kode ved ukendte flag

# Hjælpefunktioner til at parse security-blok fra YAML tekst
extract_security_flags <- function(yaml_text) {
  yaml_lines <- strsplit(yaml_text, "\n")[[1]]
  in_security <- FALSE
  flags <- character(0)
  indent_ref <- NULL

  for (line in yaml_lines) {
    stripped <- trimws(line)

    # Find security:-blok
    if (grepl("^security\\s*:", stripped) && !grepl("^#", stripped)) {
      in_security <- TRUE
      indent_ref <- nchar(line) - nchar(ltrim(line))
      next
    }

    if (!in_security) next

    # Stop naar vi rammer en ny sektion paa samme indenteringsniveau
    current_indent <- nchar(line) - nchar(ltrim(line))
    if (stripped != "" && !grepl("^#", stripped)) {
      if (!is.null(indent_ref) && current_indent <= indent_ref) {
        in_security <- FALSE
        next
      }
      # Ekstraher flagnavne (format: "  flagname: value")
      flag_match <- regmatches(stripped, regexpr("^[a-z_]+(?=\\s*:)", stripped, perl = TRUE))
      if (length(flag_match) > 0 && nchar(flag_match) > 0) {
        flags <- c(flags, flag_match)
      }
    }
  }
  unique(flags)
}

ltrim <- function(s) sub("^\\s+", "", s)

# Flag-whitelist som scriptet accepterer som implementeret
IMPLEMENTED_FLAGS <- c(
  "allow_debug_endpoints", # Styret via golem env-config, ej app-kode
  "hide_error_details", # Ejes af harden-data-protection-and-export (separat PR)
  "session_timeout_minutes" # Implementeret via setup_session_timeout()
)

test_that("extract_security_flags finder korrekte flag i yaml-blok", {
  yaml <- "
production:
  security:
    require_https: true
    allow_debug_endpoints: false
    session_timeout_minutes: 60
  performance:
    enable_caching: true
"
  flags <- extract_security_flags(yaml)
  expect_true("require_https" %in% flags)
  expect_true("allow_debug_endpoints" %in% flags)
  expect_true("session_timeout_minutes" %in% flags)
  expect_false("enable_caching" %in% flags)
})

test_that("ukendte security-flag detekteres korrekt", {
  # Disse flag skal IKKE eksistere efter Phase 2+3 cleanup
  forbidden_flags <- c("require_https", "csrf_protection", "content_security_policy")
  yaml_clean <- "
production:
  security:
    allow_debug_endpoints: false
    session_timeout_minutes: 60
    hide_error_details: true
  performance:
    enable_caching: true
"
  flags <- extract_security_flags(yaml_clean)
  unknown <- setdiff(flags, IMPLEMENTED_FLAGS)
  expect_length(unknown, 0)
})

test_that("check_security_config-logikken fejler paa require_https", {
  # Simuler at require_https stadig er i yml
  yaml_with_bad_flag <- "
production:
  security:
    require_https: true
    allow_debug_endpoints: false
    session_timeout_minutes: 60
    hide_error_details: true
  performance:
    enable_caching: true
"
  flags <- extract_security_flags(yaml_with_bad_flag)
  unknown <- setdiff(flags, IMPLEMENTED_FLAGS)
  expect_gt(length(unknown), 0)
  expect_true("require_https" %in% unknown)
})

test_that("check_security_config-logikken fejler paa csrf_protection", {
  yaml_with_csrf <- "
production:
  security:
    csrf_protection: true
    allow_debug_endpoints: false
    session_timeout_minutes: 60
    hide_error_details: true
"
  flags <- extract_security_flags(yaml_with_csrf)
  unknown <- setdiff(flags, IMPLEMENTED_FLAGS)
  expect_true("csrf_protection" %in% unknown)
})

test_that("check_security_config-logikken fejler paa content_security_policy", {
  yaml_with_csp <- "
production:
  security:
    content_security_policy: strict
    allow_debug_endpoints: false
    session_timeout_minutes: 60
    hide_error_details: true
"
  flags <- extract_security_flags(yaml_with_csp)
  unknown <- setdiff(flags, IMPLEMENTED_FLAGS)
  expect_true("content_security_policy" %in% unknown)
})

test_that("golem-config.yml production-blok indeholder ingen ukendte security-flag", {
  # testthat::test_path() returnerer absolut sti relativt til tests/testthat/
  config_path <- testthat::test_path("..", "..", "inst", "golem-config.yml")

  skip_if_not(file.exists(config_path), "golem-config.yml ikke fundet")

  yaml_text <- paste(readLines(config_path, encoding = "UTF-8"), collapse = "\n")

  # Find production:-blok ved at isolere den sektion
  prod_start <- regexpr("\nproduction:", yaml_text)
  if (prod_start == -1) {
    skip("Ingen production:-sektion i golem-config.yml")
  }

  # Tag fra production: til næste top-level nøgle
  remainder <- substring(yaml_text, prod_start + 1)
  next_section <- regexpr("\n[a-z_]+:", remainder)
  if (next_section > 0) {
    prod_yaml <- substring(remainder, 1, next_section - 1)
  } else {
    prod_yaml <- remainder
  }

  flags <- extract_security_flags(prod_yaml)
  unknown <- setdiff(flags, IMPLEMENTED_FLAGS)

  expect_equal(
    length(unknown), 0L,
    label = paste(
      "Uimplementerede security-flag i production-blok:",
      paste(unknown, collapse = ", "),
      "- Fjern fra golem-config.yml eller implementér i app-kode."
    )
  )
})
