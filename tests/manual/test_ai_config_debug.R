# Direct diagnostic - load package from source
devtools::load_all(quiet = TRUE)

cat("\n=== ENVIRONMENT ===\n")
cat("GOLEM_CONFIG_ACTIVE:", Sys.getenv("GOLEM_CONFIG_ACTIVE"), "\n\n")

cat("=== GOLEM CONFIG READING ===\n")
ai_from_golem <- golem::get_golem_options("ai")
cat("golem::get_golem_options('ai'):\n")
str(ai_from_golem)
cat("\n")

cat("=== AI CONFIG WRAPPER ===\n")
ai_config <- get_ai_config()
cat("get_ai_config() result:\n")
str(ai_config)
cat("\n")

cat("=== VALIDATION CHECK ===\n")
cat("Running validate_gemini_setup()...\n")
setup_valid <- validate_gemini_setup()
cat("Result:", setup_valid, "\n\n")

cat("=== API KEY CHECK ===\n")
api_key <- Sys.getenv("GOOGLE_API_KEY")
cat("API key present:", nchar(api_key) > 0, "\n")
cat("API key length:", nchar(api_key), "chars\n\n")

cat("=== DIAGNOSIS ===\n")
if (!setup_valid) {
  cat("❌ PROBLEM: validate_gemini_setup() returned FALSE\n")
  cat("Checking why...\n\n")
  
  # Check ellmer
  has_ellmer <- requireNamespace("ellmer", quietly = TRUE)
  cat("1. ellmer installed:", has_ellmer, "\n")
  
  # Check API key
  has_key <- api_key != "" && api_key != "your_api_key_here"
  cat("2. API key valid:", has_key, "\n")
  
  # Check config enabled
  cat("3. ai_config$enabled:", ai_config$enabled, "\n")
  cat("4. isTRUE(ai_config$enabled):", isTRUE(ai_config$enabled), "\n\n")
  
  if (!isTRUE(ai_config$enabled)) {
    cat("🎯 ROOT CAUSE: ai_config$enabled is not TRUE!\n")
    cat("   This is why validation fails on line 52 of validate_gemini_setup()\n\n")
  }
} else {
  cat("✓ Validation successful!\n")
}
