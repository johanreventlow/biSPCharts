# utils_font_registration.R
# Font registration utilities for ensuring Roboto fonts are available across all systems

#' Register Roboto Fonts (Medium and Bold)
#'
#' Registrerer bundlede Roboto Medium og Bold fonts med systemfonts pakken.
#' Dette sikrer at fonterne er tilgaengelige paa alle systemer, uanset om
#' Roboto er installeret lokalt.
#'
#' Funktionen koeres automatisk ved app-start for at sikre font-tilgaengelighed.
#' Roboto Medium registreres som "plain" variant og Roboto Bold som "bold" variant,
#' saa marquee kan bruge **bold** markup korrekt.
#'
#' @return NULL (invisible). Registrerer fonts som sideeffekt.
#'
#' @details
#' Roboto Medium og Bold fonts er bundlet i inst/fonts/ mappen og licenseret under
#' Apache License 2.0 (se inst/fonts/LICENSE).
#'
#' Font-registrering haandteres af systemfonts pakken, som er cross-platform
#' kompatibel (Windows, macOS, Linux).
#'
#' @examples
#' \dontrun{
#' # Typisk kaldt fra global.R eller app startup
#' register_roboto_font()
#' }
#'
#' @family font_registration
#' @keywords internal
register_roboto_font <- function() {
  # Guard: Only register once per session
  # Check if already registered to prevent duplicate registrations
  claudespc_env <- get_claudespc_environment()
  if (exists(".roboto_registered", envir = claudespc_env) &&
    isTRUE(get(".roboto_registered", envir = claudespc_env))) {
    return(invisible(NULL))
  }

  # Check if systemfonts package is available
  if (!requireNamespace("systemfonts", quietly = TRUE)) {
    log_warn(
      component = "[FONT_REGISTRATION]",
      message = "systemfonts package ikke tilg\u00e6ngelig - font-registrering sprunget over",
      details = list(fallback = "System vil fors\u00f8ge at bruge lokalt installeret Roboto")
    )
    return(invisible(NULL))
  }

  # Definer font-stier (udvikling vs. installeret pakke)
  font_path_medium <- tryCatch(
    {
      # Forsoeg at finde font i installeret pakke
      system.file("fonts", "Roboto-Medium.ttf", package = "biSPCharts")
    },
    error = function(e) {
      # Fallback til relativ sti i udvikling
      file.path("inst", "fonts", "Roboto-Medium.ttf")
    }
  )

  font_path_bold <- tryCatch(
    {
      system.file("fonts", "Roboto-Bold.ttf", package = "biSPCharts")
    },
    error = function(e) {
      file.path("inst", "fonts", "Roboto-Bold.ttf")
    }
  )

  # Verificer at begge font-filer eksisterer
  if (!file.exists(font_path_medium) || font_path_medium == "") {
    log_error(
      component = "[FONT_REGISTRATION]",
      message = "Roboto-Medium.ttf font-fil ikke fundet",
      details = list(
        expected_path = font_path_medium,
        working_directory = getwd(),
        fallback = "System vil fors\u00f8ge at bruge lokalt installeret Roboto"
      )
    )
    return(invisible(NULL))
  }

  if (!file.exists(font_path_bold) || font_path_bold == "") {
    log_warn(
      component = "[FONT_REGISTRATION]",
      message = "Roboto-Bold.ttf font-fil ikke fundet - forts\u00e6tter kun med Medium",
      details = list(
        expected_path = font_path_bold,
        impact = "Bold text vil ikke vises korrekt i labels"
      )
    )
    # Fortsaet med kun Medium variant
    font_path_bold <- NULL
  }

  # Registrer fonts med systemfonts
  safe_operation(
    "Registrer Roboto fonts (Medium + Bold)",
    code = {
      # Register font family with both Medium (plain) and Bold variants
      if (!is.null(font_path_bold)) {
        systemfonts::register_font(
          name = "Roboto Medium",
          plain = font_path_medium,
          bold = font_path_bold
        )

        log_info(
          component = "[FONT_REGISTRATION]",
          message = "Roboto fonts registreret succesfuldt (Medium + Bold)",
          details = list(
            medium_path = font_path_medium,
            bold_path = font_path_bold,
            medium_size_kb = round(file.size(font_path_medium) / 1024, 1),
            bold_size_kb = round(file.size(font_path_bold) / 1024, 1)
          )
        )
      } else {
        # Fallback: Registrer kun Medium
        systemfonts::register_font(
          name = "Roboto Medium",
          plain = font_path_medium
        )

        log_info(
          component = "[FONT_REGISTRATION]",
          message = "Roboto Medium font registreret (Bold ikke tilg\u00e6ngelig)",
          details = list(
            medium_path = font_path_medium,
            medium_size_kb = round(file.size(font_path_medium) / 1024, 1)
          )
        )
      }

      # Mark as registered to prevent duplicate registrations
      assign(".roboto_registered", TRUE, envir = claudespc_env)
    },
    fallback = function(e) {
      log_warn(
        component = "[FONT_REGISTRATION]",
        message = "Font-registrering fejlede - forts\u00e6tter med system-standard",
        details = list(
          error = e$message,
          fallback = "System vil fors\u00f8ge at bruge lokalt installeret Roboto"
        )
      )
    },
    error_type = "processing"
  )

  return(invisible(NULL))
}

#' Register Mari Fonts (Regular and Bold)
#'
#' Registrerer bundlede Mari fonts med systemfonts pakken.
#' Dette sikrer at BFHtheme vaelger Mari (hoejeste prioritet) i stedet for
#' fallback til Roboto/sans paa systemer hvor Mari ikke er installeret
#' (f.eks. Posit Connect Cloud).
#'
#' @return NULL (invisible). Registrerer fonts som sideeffekt.
#'
#' @details
#' Mari fonts er bundlet i inst/templates/typst/bfh-template/fonts/ mappen.
#' Fonten er proprietaer (Bispebjerg og Frederiksberg Hospital) og maa ikke
#' distribueres i public packages -- derfor ligger den i biSPCharts (private).
#'
#' @family font_registration
#' @keywords internal
register_mari_font <- function() {
  claudespc_env <- get_claudespc_environment()
  if (exists(".mari_registered", envir = claudespc_env) &&
    isTRUE(get(".mari_registered", envir = claudespc_env))) {
    return(invisible(NULL))
  }

  if (!requireNamespace("systemfonts", quietly = TRUE)) {
    return(invisible(NULL))
  }

  # Idempotens-guard: Hvis Mari allerede er installeret som system-font
  # (fx MacOS user fonts), afviser systemfonts::register_font at registrere
  # over -- derfor springer vi over. Undgaar spurious "already exists"-fejl
  # ved gentagne test-sessions paa dev-maskiner hvor Mari er systeminstalleret.
  sys_fonts <- systemfonts::system_fonts()
  if ("Mari" %in% sys_fonts$family) {
    log_debug(
      component = "[FONT_REGISTRATION]",
      message = "Mari allerede tilg\u00e6ngelig som system-font \u2014 registrering sprunget over",
      details = list(variants = sum(sys_fonts$family == "Mari"))
    )
    assign(".mari_registered", TRUE, envir = claudespc_env)
    return(invisible(NULL))
  }

  font_dir <- system.file(
    "templates/typst/bfh-template/fonts",
    package = "biSPCharts"
  )
  if (!nzchar(font_dir) || !dir.exists(font_dir)) {
    font_dir <- file.path("inst", "templates", "typst", "bfh-template", "fonts")
  }

  # Book-varianten matcher Mac system-default for "Mari" (lettere end Regular)
  font_plain <- file.path(font_dir, "MariOffice-Book.ttf")
  font_bold <- file.path(font_dir, "MariOffice-Bold.ttf")

  if (!file.exists(font_plain)) {
    log_warn(
      component = "[FONT_REGISTRATION]",
      message = "MariOffice-Book.ttf ikke fundet \u2014 Mari font-registrering sprunget over",
      details = list(expected_path = font_plain)
    )
    return(invisible(NULL))
  }

  safe_operation(
    "Registrer Mari fonts",
    code = {
      bold_path <- if (file.exists(font_bold)) font_bold else font_plain

      systemfonts::register_font(
        name = "Mari",
        plain = font_plain,
        bold = bold_path
      )

      log_info(
        component = "[FONT_REGISTRATION]",
        message = "Mari font registreret succesfuldt",
        details = list(
          plain_path = font_plain,
          bold_path = bold_path
        )
      )

      assign(".mari_registered", TRUE, envir = claudespc_env)
    },
    fallback = function(e) {
      log_warn(
        component = "[FONT_REGISTRATION]",
        message = "Mari font-registrering fejlede \u2014 BFHtheme vil bruge fallback",
        details = list(error = e$message)
      )
    },
    error_type = "processing"
  )

  return(invisible(NULL))
}
