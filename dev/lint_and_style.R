# lint_and_style.R
# Development script til code quality checking og formatting
# Kan køres med specifikke filer som argumenter (brugt af pre-commit hook)
# eller uden argumenter for at checke hele projektet

library(lintr)
library(styler)

# Bestem hvilke filer der skal checkes
args <- commandArgs(trailingOnly = TRUE)

if (length(args) > 0) {
  # Pre-commit mode: kun staged filer
  paths_to_check <- args
  cat("🔍 Kører lintr code quality check på staged filer...\n")
} else {
  # Manuel mode: hele projektet
  paths_to_check <- c(
    "global.R",
    "app.R",
    "R/"
  )
  cat("🔍 Kører lintr code quality check på hele projektet...\n")
}

# LINTING ======================================================================

# Kør lintr på specifikke filer og mapper
lint_results <- list()

for (path in paths_to_check) {
  if (file.exists(path)) {
    cat("Checker:", path, "\n")
    if (dir.exists(path)) {
      # For mapper: scan alle .R filer
      r_files <- list.files(path, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
      for (file in r_files) {
        lint_results[[file]] <- lint(file)
      }
    } else {
      # For enkelte filer
      lint_results[[path]] <- lint(path)
    }
  }
}

# Vis resultater
total_issues <- sum(sapply(lint_results, length))
cat("\n📊 Lintr resultater:\n")
cat("Total issues fundet:", total_issues, "\n")

if (total_issues > 0) {
  cat("\n⚠️  Issues fundet:\n")
  for (file in names(lint_results)) {
    issues <- lint_results[[file]]
    if (length(issues) > 0) {
      cat("\n", file, ":\n")
      print(issues)
    }
  }
} else {
  cat("✅ Ingen linting issues fundet!\n")
}

# STYLING ======================================================================

cat("\n🎨 Kører styler code formatting...\n")

for (path in paths_to_check) {
  if (file.exists(path)) {
    cat("Styling:", path, "\n")
    if (dir.exists(path)) {
      style_dir(path, recursive = TRUE)
    } else {
      style_file(path)
    }
  }
}

cat("✅ Code styling færdig!\n")

# SUMMARY ======================================================================

cat("\n📋 SAMMENFATNING:\n")
cat("- Lintr issues:", total_issues, "\n")
cat("- Styling: Komplet\n")

if (total_issues > 0) {
  cat("\n🔧 Næste trin: Ret lintr issues manuelt\n")
} else {
  cat("\n🎉 Code quality check bestået!\n")
}
