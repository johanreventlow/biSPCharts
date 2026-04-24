# verify_rag.R
# Manuel test script til at verificere RAG integration

# Source required files (development mode)
source("R/utils_error_handling.R") # For safe_getenv()
source("R/config_log_contexts.R")
source("R/utils_logging.R")
source("R/utils_ragnar_integration.R")

cat("=== RAG Integration Verification ===\n\n")

# 1. Check if RAG is enabled in config
cat("1. Checking RAG configuration...\n")
rag_config <- get_rag_config()
cat("   RAG enabled:", rag_config$enabled, "\n")
cat("   n_results:", rag_config$n_results, "\n")
cat("   method:", rag_config$method, "\n\n")

# 2. Check if Ragnar store exists (development mode)
cat("2. Checking Ragnar store location...\n")
dev_store_path <- "inst/ragnar_store"
if (file.exists(dev_store_path)) {
  cat("   ✓ Ragnar store found at:", dev_store_path, "\n")

  # Try to connect to store directly
  if (requireNamespace("ragnar", quietly = TRUE)) {
    store <- tryCatch(
      ragnar::ragnar_store_connect(location = dev_store_path),
      error = function(e) {
        cat("   ✗ Store exists but couldn't connect:", e$message, "\n")
        NULL
      }
    )

    if (!is.null(store)) {
      cat("   ✓ Successfully connected to Ragnar store\n\n")
    } else {
      cat("\n")
    }
  } else {
    cat("   (ragnar package not installed - can't verify connection)\n\n")
    store <- NULL
  }
} else {
  cat("   ✗ Ragnar store not found at:", dev_store_path, "\n")
  cat("   Run: Rscript data-raw/build_ragnar_store.R\n\n")
  store <- NULL
}

# 3. Test knowledge query (development mode)
if (!is.null(store) && requireNamespace("ragnar", quietly = TRUE)) {
  cat("3. Testing knowledge query...\n")

  # Ensure API key is set (fallback from GOOGLE_API_KEY)
  if (Sys.getenv("GEMINI_API_KEY") == "") {
    google_key <- Sys.getenv("GOOGLE_API_KEY")
    if (google_key != "") {
      Sys.setenv(GEMINI_API_KEY = google_key)
      cat("   (Using GOOGLE_API_KEY as GEMINI_API_KEY)\n")
    } else {
      cat("   ✗ GEMINI_API_KEY not set - query will fail\n")
      cat("   Set in .Renviron: GOOGLE_API_KEY=your_key\n\n")
    }
  }

  # Build test query
  test_query <- "Chart type: run. Signals detected: Serielængde. How to interpret?"

  results <- tryCatch(
    ragnar::ragnar_retrieve(
      store = store,
      text = test_query,
      top_k = 2
    ),
    error = function(e) {
      cat("   ✗ Query failed:", e$message, "\n")
      NULL
    }
  )

  if (!is.null(results) && nrow(results) > 0) {
    context <- paste(results$text, collapse = "\n\n")
    cat("   ✓ Knowledge retrieved successfully\n")
    cat("   Chunks retrieved:", nrow(results), "\n")
    cat("   Context length:", nchar(context), "characters\n")
    cat("   Preview:", substr(context, 1, 100), "...\n\n")
  } else {
    cat("   ✗ No knowledge chunks retrieved\n\n")
  }
} else {
  cat("3. Skipping knowledge query (store not available)\n\n")
}

cat("=== Verification Complete ===\n")
cat("\nTo enable RAG:\n")
cat("1. Install ragnar: install.packages('ragnar')\n")
cat("2. Build knowledge store: source('data-raw/build_ragnar_store.R')\n")
cat("3. Ensure GOOGLE_API_KEY is set in .Renviron\n")
cat("4. Restart R session\n")
