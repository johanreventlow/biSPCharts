# config_analytics.R
# Konfiguration for analytics og cookie consent

#' Analytics Configuration
#'
#' Centraliserede konstanter for analytics, consent og log rotation.
#'
#' Storage-schema v2 (cookie-consent.js): JSON-objekt under spc_app_consent
#' med felter schema_version, consent_version, timestamp, consented (binær),
#' visitor_id. v1's 4 separate localStorage-keys migreres transparent.
#'
#' Binær consent-model: ét samtykke gater alle ikke-strengt-nødvendige
#' features (shinylogs analytics + performance-metrics + visitor-ID +
#' localStorage-app-state-persistens). "Kun nødvendige" deaktiverer ALT.
#'
#' @format List med foelgende felter:
#' \describe{
#'   \item{consent_version}{Integer — bump for at tvinge re-consent.
#'     v1->v2 bump (2026-05-10): banner erstattet af haard modal +
#'     persistens-gating tilfoejet — kraever fornyet eksplicit valg.}
#'   \item{consent_max_age_days}{Antal dage foer consent udloeber (GDPR)}
#'   \item{log_retention_days}{Antal dage foer log-filer slettes}
#'   \item{log_compress_after_days}{Antal dage foer log-filer komprimeres}
#'   \item{pin_name}{Navn paa pin til Connect Cloud}
#'   \item{enabled}{Feature flag for hele analytics-systemet}
#' }
#' @keywords internal
ANALYTICS_CONFIG <- list(
  consent_version = 2L,
  consent_max_age_days = 365L,
  log_retention_days = 365L,
  log_compress_after_days = 90L,
  pin_name = "spc-analytics-logs",
  enabled = TRUE
)

#' Hent analytics konfiguration
#'
#' Returnerer analytics config. Kan udvides til at laese fra
#' golem-config.yml i fremtiden.
#'
#' @return List med analytics konfiguration
#' @export
get_analytics_config <- function() {
  ANALYTICS_CONFIG
}
