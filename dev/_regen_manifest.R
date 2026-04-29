#!/usr/bin/env Rscript
# Helper til at regenerere manifest.json med curated appFiles-liste,
# undgår rsconnect's enforceBundleLimits()-fejl pga. .Rcheck/dev/.git.
# Engangsbrug — slet efter brug.

# Tillad lokalt installeret biSPCharts (unknown source) under snapshot.
# biSPCharts er app'en selv, ikke en CRAN/GitHub-dep, så renv kan ikke tracke kilden.
options(renv.config.snapshot.validate = FALSE)

roots <- c("app.R", "DESCRIPTION", "NAMESPACE", "R", "inst", "manifest.json")
files <- character(0)

for (root in roots) {
  if (file.exists(root) && !dir.exists(root)) {
    files <- c(files, root)
  } else if (dir.exists(root)) {
    files <- c(files, list.files(root, recursive = TRUE, all.files = TRUE,
                                 no.. = TRUE, full.names = TRUE))
  }
}

files <- unique(sub("^\\./", "", files))
files <- files[file.exists(files)]

cat("Total files i bundle:", length(files), "\n")

# biSPCharts er app'en selv — skal IKKE indgå som dependency i manifest.
# Unload + remove fra installed library for at undgå "installed from source"-fejl.
if ("biSPCharts" %in% loadedNamespaces() &&
    requireNamespace("pkgload", quietly = TRUE)) {
  try(pkgload::unload("biSPCharts"), silent = TRUE)
}
# Forsøg at fjerne biSPCharts fra .libPaths, så rsconnect ikke ser den som dep
try({
  bisp_lib <- find.package("biSPCharts", quiet = TRUE)
  if (length(bisp_lib) > 0) {
    cat("Bemærk: biSPCharts er installeret i:", bisp_lib, "\n")
    cat("Hvis manifest fejler med 'installed from source', kør:\n")
    cat("  remove.packages('biSPCharts')\n")
    cat("og forsøg igen.\n")
  }
}, silent = TRUE)

rsconnect::writeManifest(appDir = ".", appFiles = files)
cat("manifest.json regenereret OK\n")
