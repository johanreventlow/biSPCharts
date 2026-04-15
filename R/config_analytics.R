# config_analytics.R
# Konfiguration for analytics og cookie consent

#' Analytics Configuration
#'
#' Centraliserede konstanter for analytics, consent og log rotation.
#'
#' @format List med foelgende felter:
#' \describe{
#'   \item{consent_version}{Integer — bump for at tvinge re-consent}
#'   \item{consent_max_age_days}{Antal dage foer consent udloeber (GDPR)}
#'   \item{log_retention_days}{Antal dage foer log-filer slettes}
#'   \item{log_compress_after_days}{Antal dage foer log-filer komprimeres}
#'   \item{pin_name}{Navn paa pin til Connect Cloud}
#'   \item{enabled}{Feature flag for hele analytics-systemet}
#' }
#' @export
ANALYTICS_CONFIG <- list(
  consent_version = 1L,
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
