# utils_font_registration.R
# Font registration utilities for ensuring Roboto fonts are available across all systems

#' Register Roboto Fonts (Medium and Bold)
#'
#' Registrerer bundlede Roboto Medium og Bold fonts med systemfonts pakken.
#' Dette sikrer at fonterne er tilgængelige på alle systemer, uanset om
#' Roboto er installeret lokalt.
#'
#' Funktionen køres automatisk ved app-start for at sikre font-tilgængelighed.
#' Roboto Medium registreres som "plain" variant og Roboto Bold som "bold" variant,
#' så marquee kan bruge **bold** markup korrekt.
#'
#' @return NULL (invisible). Registrerer fonts som sideeffekt.
#'
#' @details
#' Roboto Medium og Bold fonts er bundlet i inst/fonts/ mappen og licenseret under
#' Apache License 2.0 (se inst/fonts/LICENSE).
#'
#' Font-registrering håndteres af systemfonts pakken, som er cross-platform
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
  if (exists(".roboto_registered", envir = .GlobalEnv) &&
    isTRUE(get(".roboto_registered", envir = .GlobalEnv))) {
    return(invisible(NULL))
  }

  # Check if systemfonts package is available
  if (!requireNamespace("systemfonts", quietly = TRUE)) {
    log_warn(
      component = "[FONT_REGISTRATION]",
      message = "systemfonts package ikke tilgængelig - font-registrering sprunget over",
      details = list(fallback = "System vil forsøge at bruge lokalt installeret Roboto")
    )
    return(invisible(NULL))
  }

  # Definer font-stier (udvikling vs. installeret pakke)
  font_path_medium <- tryCatch(
    {
      # Forsøg at finde font i installeret pakke
      system.file("fonts", "Roboto-Medium.ttf", package = "SPCify")
    },
    error = function(e) {
      # Fallback til relativ sti i udvikling
      file.path("inst", "fonts", "Roboto-Medium.ttf")
    }
  )

  font_path_bold <- tryCatch(
    {
      system.file("fonts", "Roboto-Bold.ttf", package = "SPCify")
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
        fallback = "System vil forsøge at bruge lokalt installeret Roboto"
      )
    )
    return(invisible(NULL))
  }

  if (!file.exists(font_path_bold) || font_path_bold == "") {
    log_warn(
      component = "[FONT_REGISTRATION]",
      message = "Roboto-Bold.ttf font-fil ikke fundet - fortsætter kun med Medium",
      details = list(
        expected_path = font_path_bold,
        impact = "Bold text vil ikke vises korrekt i labels"
      )
    )
    # Fortsæt med kun Medium variant
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
          message = "Roboto Medium font registreret (Bold ikke tilgængelig)",
          details = list(
            medium_path = font_path_medium,
            medium_size_kb = round(file.size(font_path_medium) / 1024, 1)
          )
        )
      }

      # Mark as registered to prevent duplicate registrations
      assign(".roboto_registered", TRUE, envir = .GlobalEnv)
    },
    fallback = function(e) {
      log_warn(
        component = "[FONT_REGISTRATION]",
        message = "Font-registrering fejlede - fortsætter med system-standard",
        details = list(
          error = e$message,
          fallback = "System vil forsøge at bruge lokalt installeret Roboto"
        )
      )
    },
    error_type = "processing"
  )

  return(invisible(NULL))
}
