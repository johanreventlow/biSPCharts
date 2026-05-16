# ==============================================================================
# CONFIG_SUPPORT.R
# ==============================================================================
# FORMAAL: Konstanter og helpers for bug-rapportering via mailto.
#          Brugt af mod_report_bug til at generere praefyldte mailto-links
#          mod Dataenhedens support-postkasse.
#
# ANVENDES AF:
#   - mod_report_bug_ui (mailto-knap)
#   - tests/testthat/test-mod_report_bug.R
# ==============================================================================

#' Support-email til bug-rapporter
#'
#' Modtager-adresse for bug-rapporter sendt via "Rapportér fejl"-siden.
#' Ændring kræver kun opdatering af denne konstant.
#'
#' @keywords internal
SUPPORT_EMAIL <- "dataenheden.bispebjerg-frederiksberg-hospitaler@regionh.dk"

#' Standard subject til bug-rapport
#' @keywords internal
SUPPORT_EMAIL_SUBJECT <- "biSPCharts: fejlrapport"

#' Standard body-skabelon til bug-rapport
#'
#' Struktureret skabelon med tomme afsnit brugeren udfylder. Opfordrer til
#' vedhæftning af datasæt (Excel-eksport), graf og/eller skærmbillede.
#'
#' @keywords internal
SUPPORT_EMAIL_BODY <- paste(
  "Hej Dataenhed,",
  "",
  "Jeg vil gerne rapportere en fejl i biSPCharts.",
  "",
  "Hvad skete der?",
  "[Beskriv hvad du oplevede]",
  "",
  "Hvad lavede du, da det skete?",
  "[Beskriv kort hvilke trin du fulgte]",
  "",
  "Hvad havde du forventet?",
  "[Beskriv hvad du regnede med ville ske]",
  "",
  "Vedhæftet:",
  "[ ] Datasæt (.xlsx eksporteret fra Eksportér-fanen)",
  "[ ] Graf (eksporteret fra Eksportér-fanen)",
  "[ ] Skærmbillede",
  "",
  "Andre kommentarer:",
  "[Valgfrit]",
  "",
  "Mvh",
  "[Dit navn + afdeling]",
  sep = "\n"
)

#' Byg mailto-URL til bug-rapport
#'
#' Konstruerer et mailto:-link med URL-encoded subject og body. Brugerens
#' mail-klient åbnes med skabelonen praefyldt - brugeren udfylder felter,
#' vedhæfter filer og sender selv.
#'
#' @param to Character. Modtager-email. Default \code{SUPPORT_EMAIL}.
#' @param subject Character. Subject. Default \code{SUPPORT_EMAIL_SUBJECT}.
#' @param body Character. Body-skabelon. Default \code{SUPPORT_EMAIL_BODY}.
#'
#' @return Character. Komplet mailto-URL klar til \code{href}.
#'
#' @keywords internal
build_bug_report_mailto <- function(to = SUPPORT_EMAIL,
                                    subject = SUPPORT_EMAIL_SUBJECT,
                                    body = SUPPORT_EMAIL_BODY) {
  stopifnot(
    is.character(to), length(to) == 1L, !is.na(to), nzchar(to),
    is.character(subject), length(subject) == 1L, !is.na(subject),
    is.character(body), length(body) == 1L, !is.na(body)
  )

  paste0(
    "mailto:", to,
    "?subject=", utils::URLencode(subject, reserved = TRUE),
    "&body=", utils::URLencode(body, reserved = TRUE)
  )
}
