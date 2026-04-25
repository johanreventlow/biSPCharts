#!/usr/bin/env Rscript
# ==============================================================================
# TEST_GEMINI_STANDALONE.R
# ==============================================================================
# Minimal eksempel til at teste Gemini API forbindelse uden Shiny
#
# BRUG:
#   Rscript test_gemini_standalone.R
#
# KRAV:
#   - GOOGLE_API_KEY sat i .Renviron
#   - ellmer pakke installeret
# ==============================================================================

cat("=== GEMINI API TEST (Standalone) ===\n\n")

# 1. Check dependencies
cat("1. Checking dependencies...\n")
if (!requireNamespace("ellmer", quietly = TRUE)) {
  stop("ellmer pakke mangler. Install med: install.packages('ellmer')")
}
cat("   ✓ ellmer pakke tilgængelig\n")

# 2. Check API key
cat("\n2. Checking API key...\n")
api_key <- Sys.getenv("GOOGLE_API_KEY")
if (api_key == "" || api_key == "your_api_key_here") {
  stop("GOOGLE_API_KEY ikke sat. Check .Renviron fil.")
}
cat("   ✓ API key sat (", nchar(api_key), " chars)\n", sep = "")

# 3. Check network connectivity (optional)
cat("\n3. Checking network connectivity...\n")
if (requireNamespace("curl", quietly = TRUE)) {
  dns_result <- tryCatch(
    curl::nslookup("generativelanguage.googleapis.com", error = FALSE),
    error = function(e) NULL
  )
  if (is.null(dns_result) || length(dns_result) == 0) {
    stop("Ingen netværksforbindelse til Gemini API")
  }
  cat("   ✓ DNS lookup OK:", dns_result[1], "\n")
} else {
  cat("   ⚠ curl ikke tilgængelig, springer connectivity check over\n")
}

# 4. Initialize Gemini chat
cat("\n4. Initializing Gemini chat...\n")
chat <- tryCatch(
  {
    ellmer::chat_google_gemini(
      model = "gemini-2.5-flash-lite",
      api_key = api_key
    )
  },
  error = function(e) {
    stop("Kunne ikke initialisere Gemini chat: ", e$message)
  }
)
cat("   ✓ Chat initialiseret\n")

# 5. Send test prompt
cat("\n5. Sending test prompt to Gemini...\n")
prompt <- "Hvem er konge i Danmark"
cat("   Prompt:", prompt, "\n")

response <- tryCatch(
  {
    chat$chat(prompt)
  },
  error = function(e) {
    stop("API kald fejlede: ", e$message)
  }
)

# 6. Display response
cat("\n6. Response from Gemini:\n")
cat("   ---\n")

# Handle different response formats from ellmer
response_text <- if (is.character(response)) {
  response # Response is already a character vector
} else if (is.list(response) && !is.null(response$text)) {
  response$text # Response is a list with $text field
} else {
  as.character(response) # Fallback
}

cat("   ", response_text, "\n", sep = "")
cat("   ---\n")

# 7. Success summary
cat("\n=== TEST SUCCEEDED ===\n")
cat("✓ Gemini API fungerer korrekt\n")
cat("✓ Du kan nu bruge AI-funktionalitet i appen\n\n")
