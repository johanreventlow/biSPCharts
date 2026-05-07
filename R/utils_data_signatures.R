# utils_data_signatures.R
# H14: Shared Data Signatures
# Centraliseret signatur-generering til genbrug på tværs af QIC + auto-detect

#' Generate Data Signature (Shared)
#'
#' Opretter en konsistent signatur for data der kan genbruges på tværs af
#' cache-systemer. Bruger xxhash64 for hastighed.
#'
#' @param data Data frame der genereres signatur for
#' @param include_structure Inkludér strukturelle metadata (nrow, ncol, names, types)
#' @param app_state Optional centralized app state (ubrugt, bevaret for API-paritet)
#'
#' @return Character string signatur (xxhash64 digest)
#'
#' @details
#' ## Korrekthed
#'
#' Beregner altid full xxhash64-digest af hele data-frame'en. Sampling-baseret
#' cache-key (Issue #494) er fjernet da den kunne give kollisioner for datasæt
#' med identiske end-point-rækker men forskelle i midten.
#'
#' ## Performance
#'
#' - **Shared signatures**: Samme data hashés én gang, genbruges i QIC + auto-detect
#' - **Fast algorithm**: xxhash64 er 5-10x hurtigere end MD5
#'
#' ## When Signatures Match
#'
#' To datasæt har samme signatur hvis de har:
#' - Samme antal rækker og kolonner
#' - Samme kolonnenavne og typer (hvis include_structure = TRUE)
#' - Identiske dataværdier
#'
#' @examples
#' \dontrun{
#' # Generer signatur
#' sig <- generate_shared_data_signature(my_data)
#'
#' # Genbrug i forskellige kontekster
#' qic_key <- paste0("qic_", sig, "_", param_hash)
#' autodetect_key <- paste0("autodetect_", sig)
#' }
#'
#' @keywords internal
generate_shared_data_signature <- function(data, include_structure = TRUE, app_state = NULL) {
  # Håndtér NULL/tomt data
  if (is.null(data) || nrow(data) == 0) {
    return("empty_data")
  }

  # Beregn altid full digest — ingen sampling-cache (fjernet i #494)
  if (include_structure) {
    signature_components <- list(
      nrow = nrow(data),
      ncol = ncol(data),
      column_names = names(data),
      column_types = purrr::map_chr(data, ~ class(.x)[1]),
      data_hash = digest::digest(data, algo = "xxhash64", serialize = TRUE)
    )
    signature <- digest::digest(signature_components, algo = "xxhash64", serialize = TRUE)
  } else {
    # Data-only signatur (ingen struktur)
    signature <- digest::digest(data, algo = "xxhash64", serialize = TRUE)
  }

  return(signature)
}

#' Generate QIC Cache Key (Optimized)
#'
#' Opretter cache-key for QIC-resultater via shared data signature.
#' Erstatter redundant MD5-hashing med shared xxhash64-signaturer.
#'
#' @param data Data til QIC-beregning
#' @param params QIC-parametre (chart type, kolonner, etc.)
#' @param app_state Optional centralized app state
#'
#' @return Character string cache key
#'
#' @keywords internal
generate_qic_cache_key_optimized <- function(data, params, app_state = NULL) {
  # Brug shared signatur i stedet for re-hashing
  data_signature <- generate_shared_data_signature(data, include_structure = FALSE, app_state = app_state)

  # Hash parametre (letvægt)
  param_digest <- digest::digest(params, algo = "xxhash64")

  paste0("qic_", data_signature, "_", param_digest)
}

#' Generate Auto-Detect Cache Key (Optimized)
#'
#' Opretter cache-key for auto-detect-resultater via shared signaturer.
#'
#' @param data Data til auto-detect
#' @param app_state Optional centralized app state
#'
#' @return Character string cache key
#'
#' @details
#' Bruger samme shared signatur som QIC-cache, sikrer konsistens og undgår
#' redundant hashing når begge systemer cacher samme data.
#'
#' @keywords internal
generate_autodetect_cache_key_optimized <- function(data, app_state = NULL) {
  # Brug shared signatur med struktur-info
  data_signature <- generate_shared_data_signature(data, include_structure = TRUE, app_state = app_state)

  paste0("autodetect_", data_signature)
}

#' Migrate to Shared Signatures
#'
#' Baglæns-kompatibel wrapper for eksisterende kode.
#' Mapper gammel create_data_signature() til ny shared version.
#'
#' @param data Data frame
#'
#' @return Data signatur
#'
#' @details
#' Denne funktion sikrer baglæns-kompatibilitet for kode der bruger den
#' gamle create_data_signature()-funktion. Ny kode bør bruge
#' generate_shared_data_signature() direkte.
#'
#' @keywords internal
create_data_signature <- function(data) {
  generate_shared_data_signature(data, include_structure = TRUE)
}
