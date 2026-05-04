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
# rsconnect::writeManifest() fejler hvis pakken er source-installeret.
# Unload + fjern fra library inden writeManifest.
if ("biSPCharts" %in% loadedNamespaces() &&
    requireNamespace("pkgload", quietly = TRUE)) {
  try(pkgload::unload("biSPCharts"), silent = TRUE)
}
bisp_path <- tryCatch(find.package("biSPCharts"), error = function(e) character(0))
if (length(bisp_path) > 0) {
  cat("Fjerner source-installeret biSPCharts fra library:", bisp_path, "\n")
  remove.packages("biSPCharts", lib = dirname(bisp_path))
  cat("biSPCharts fjernet\n")
}

rsconnect::writeManifest(appDir = ".", appFiles = files)
cat("manifest.json regenereret OK\n")
