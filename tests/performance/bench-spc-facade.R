# bench-spc-facade.R
# Baseline + post-refactor benchmark for compute_spc_results_bfh().
# Run BEFORE and AFTER the refactor-spc-facade changes.
# Budget: p50 regression ≤5%, p99 ≤10%.
#
# Usage:
#   Rscript tests/performance/bench-spc-facade.R [before|after]
#
# Results are written to tests/performance/bench-spc-facade-<label>.rds

args <- commandArgs(trailingOnly = TRUE)
label <- if (length(args) >= 1) args[[1]] else "baseline"

suppressPackageStartupMessages({
  if (!requireNamespace("microbenchmark", quietly = TRUE)) {
    stop("microbenchmark required: install.packages('microbenchmark')")
  }
  devtools::load_all(quiet = TRUE)
})

make_run_data <- function(n) {
  data.frame(
    dato = seq(as.Date("2020-01-01"), by = "week", length.out = n),
    vaerdi = rnorm(n, mean = 50, sd = 5)
  )
}

make_p_data <- function(n) {
  data.frame(
    dato = seq(as.Date("2020-01-01"), by = "week", length.out = n),
    taeller = rbinom(n, size = 100, prob = 0.05),
    naevner = rep(100L, n)
  )
}

make_u_data <- function(n) {
  data.frame(
    dato = seq(as.Date("2020-01-01"), by = "week", length.out = n),
    taeller = rpois(n, lambda = 2),
    naevner = rep(50L, n)
  )
}

make_i_data <- function(n) make_run_data(n)

scenarios <- list(
  list(label = "run_1k", data = make_run_data(1000), chart = "run", x = "dato", y = "vaerdi", n = NULL),
  list(label = "run_10k", data = make_run_data(10000), chart = "run", x = "dato", y = "vaerdi", n = NULL),
  list(label = "p_1k", data = make_p_data(1000), chart = "p", x = "dato", y = "taeller", n = "naevner"),
  list(label = "p_10k", data = make_p_data(10000), chart = "p", x = "dato", y = "taeller", n = "naevner"),
  list(label = "u_1k", data = make_u_data(1000), chart = "u", x = "dato", y = "taeller", n = "naevner"),
  list(label = "i_1k", data = make_i_data(1000), chart = "i", x = "dato", y = "vaerdi", n = NULL)
)

results <- lapply(scenarios, function(s) {
  cat(sprintf("Benchmarking %s...\n", s$label))
  mb <- microbenchmark::microbenchmark(
    compute_spc_results_bfh(
      data       = s$data,
      x_var      = s$x,
      y_var      = s$y,
      chart_type = s$chart,
      n_var      = s$n,
      use_cache  = FALSE
    ),
    times = 10L,
    unit = "ms"
  )
  data.frame(
    scenario = s$label,
    p50 = median(mb$time) / 1e6,
    p99 = quantile(mb$time, 0.99) / 1e6
  )
})

summary_df <- do.call(rbind, results)
cat("\n=== Benchmark results (ms) ===\n")
print(summary_df, row.names = FALSE)

out_file <- file.path("tests/performance", paste0("bench-spc-facade-", label, ".rds"))
saveRDS(summary_df, out_file)
cat(sprintf("\nSaved to %s\n", out_file))
