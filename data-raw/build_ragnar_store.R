# build_ragnar_store.R
# Builds Ragnar knowledge store from SPC methodology documentation
# Run during package installation or manually to rebuild store
#
# Requirements:
# - GOOGLE_API_KEY environment variable set
# - ragnar package installed
# - inst/spc_knowledge/*.md files present

# Load required packages -------------------------------------------------------

if (!requireNamespace("ragnar", quietly = TRUE)) {
  stop("ragnar package not installed. Install with: install.packages('ragnar')")
}

if (!requireNamespace("fs", quietly = TRUE)) {
  stop("fs package not installed. Install with: install.packages('fs')")
}

library(ragnar)
library(fs)

# Configuration ----------------------------------------------------------------

# Paths (relative to package root)
store_path <- "inst/ragnar_store"
docs_path <- "inst/spc_knowledge"

# Chunking parameters (Ragnar defaults)
chunk_size <- 1600  # ~1600 characters per chunk
chunk_overlap <- 200  # Overlap for context continuity

# Validation -------------------------------------------------------------------

cat("\n=== Ragnar Knowledge Store Build ===\n\n")

# Check 1: Google API key
api_key <- Sys.getenv("GOOGLE_API_KEY")
if (api_key == "" || api_key == "your_api_key_here") {
  stop(
    "GOOGLE_API_KEY environment variable not set or invalid.\n",
    "Cannot build knowledge store without API key.\n\n",
    "Setup:\n",
    "1. Get API key: https://makersuite.google.com/app/apikey\n",
    "2. Set in .Renviron: GOOGLE_API_KEY=your_actual_key\n",
    "3. Restart R session\n",
    "4. Rerun this script\n"
  )
}

cat("✓ GOOGLE_API_KEY found\n")

# Check 2: Documentation directory exists
if (!dir.exists(docs_path)) {
  stop(
    "Documentation directory not found: ", docs_path, "\n",
    "Expected to find SPC methodology markdown files.\n",
    "Ensure inst/spc_knowledge/ exists with *.md files.\n"
  )
}

cat("✓ Documentation directory found:", docs_path, "\n")

# Check 3: Markdown files present
md_files <- fs::dir_ls(docs_path, glob = "*.md")
if (length(md_files) == 0) {
  stop(
    "No markdown files found in ", docs_path, "\n",
    "Expected *.md files with SPC methodology documentation.\n"
  )
}

cat("✓ Found", length(md_files), "documentation files\n\n")

# Initialize Ragnar Store ------------------------------------------------------

cat("Initializing Ragnar store with Google embeddings...\n")

tryCatch(
  {
    store <- ragnar::ragnar_store(
      store_path = store_path,
      embeddings_provider = ragnar::embeddings_google(
        model = "text-embedding-004",
        api_key = api_key
      )
    )

    cat("✓ Ragnar store initialized\n")
  },
  error = function(e) {
    stop(
      "Failed to initialize Ragnar store:\n",
      e$message, "\n\n",
      "Possible causes:\n",
      "- Invalid GOOGLE_API_KEY\n",
      "- Network connectivity issues\n",
      "- API rate limit exceeded\n"
    )
  }
)

# Prepare Documents ------------------------------------------------------------

cat("\nReading SPC methodology documentation...\n")

documents <- lapply(md_files, function(file) {
  cat("  -", fs::path_file(file), "\n")

  content <- tryCatch(
    {
      readLines(file, warn = FALSE, encoding = "UTF-8")
    },
    error = function(e) {
      warning("Failed to read ", file, ": ", e$message)
      return(NULL)
    }
  )

  if (is.null(content)) {
    return(NULL)
  }

  list(
    content = paste(content, collapse = "\n"),
    source = fs::path_file(file),
    type = "markdown"
  )
})

# Remove any NULL entries (failed reads)
documents <- Filter(Negate(is.null), documents)

if (length(documents) == 0) {
  stop("No documents could be read successfully")
}

cat("✓ Read", length(documents), "documents successfully\n\n")

# Chunk and Insert Documents ---------------------------------------------------

cat("Chunking and indexing documents...\n")
cat("  Chunk size:", chunk_size, "characters\n")
cat("  Overlap:", chunk_overlap, "characters\n\n")

tryCatch(
  {
    ragnar::ragnar_insert(
      store = store,
      documents = documents,
      chunk_size = chunk_size,
      chunk_overlap = chunk_overlap
    )

    cat("✓ Documents chunked and indexed successfully\n\n")
  },
  error = function(e) {
    stop(
      "Failed to insert documents into store:\n",
      e$message, "\n\n",
      "The store may be partially built. ",
      "Delete ", store_path, " and try again.\n"
    )
  }
)

# Completion -------------------------------------------------------------------

cat("=== Knowledge Store Build Complete ===\n\n")
cat("Store location:", normalizePath(store_path, mustWork = FALSE), "\n")
cat("Documents indexed:", length(documents), "\n")
cat("Source files:\n")
for (doc in documents) {
  cat("  -", doc$source, "\n")
}
cat("\nThe knowledge store is ready for use with RAG-enhanced AI suggestions.\n")
