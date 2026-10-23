#!/usr/bin/env Rscript
# Noise calibration from an A/A run (the same revision as baseline and candidate):
#   Rscript calibrate.R RUN_DIR
# Reports how much the verdict inputs vary when nothing changed, and whether the run's own tier policy
# would have failed it. The run must be an A/A run made with that tier (the tier is read from the manifest).
# Re-run it whenever policy.tsv, coverage.tsv or the contract changes: a different plan is a different noise.
a <- commandArgs(trailingOnly = TRUE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])))
source(file.path(here, "lib.R"))
run <- a[[1L]]
raw <- utils::read.delim(file.path(run, "raw.tsv"), stringsAsFactors = FALSE)
man <- utils::read.delim(file.path(run, "manifest.tsv"), stringsAsFactors = FALSE)
get <- function(key) man$value[match(key, man$key)]
policy <- read_policy(file.path(here, "policy.tsv"))
tier <- get("tier"); pol <- policy[[tier]]
plan <- if (file.exists(file.path(run, "plan.tsv"))) utils::read.delim(file.path(run, "plan.tsv"), stringsAsFactors = FALSE) else NULL
cat(sprintf("run %s, tier %s, %d observations, rounds %s, plan md5 %s\n", get("run_id"), tier, nrow(raw), paste(sort(unique(raw$round)), collapse = ","), get("plan_md5")))
cat("status:", paste(names(table(raw$status)), table(raw$status), collapse = ", "), "\n\n")

# Per page and visit, the difference between the two identical measurements. Each page has one dataset.
cells <- cell_table(raw)
w <- merge(cells[cells$label == "base", ], cells[cells$label == "cand", ], by = c("dataset", "page", "visit"), suffixes = c(".b", ".c"))
w <- w[w$ok_frac.b == 1 & w$ok_frac.c == 1, ]
for (m in c("visual_complete_ms", "loader_visible_ms")) {
  d <- w[[paste0(m, ".c")]] - w[[paste0(m, ".b")]]
  b <- w[[paste0(m, ".b")]]
  cat(sprintf("%s over %d page x visit cells: |diff| median %.0f ms, 95%% %.0f ms, max %.0f ms; relative to baseline: 95%% %.0f%%\n",
              m, length(d), med(abs(d)), stats::quantile(abs(d), 0.95, na.rm = TRUE), max(abs(d), na.rm = TRUE),
              100 * stats::quantile(abs(d) / pmax(b, 1), 0.95, na.rm = TRUE)))
}
big <- w[order(-abs(w$visual_complete_ms.c - w$visual_complete_ms.b)), ][1:min(8, nrow(w)), c("dataset", "page", "visit", "visual_complete_ms.b", "visual_complete_ms.c")]
big[, 4:5] <- round(big[, 4:5]); cat("\nlargest differences:\n"); print(big, row.names = FALSE)
cat("\nIdle wait before each measurement (s): median", round(med(raw$idle_wait_s), 1), " max", round(max(raw$idle_wait_s, na.rm = TRUE), 1), "\n")

cat("\nWould the tier policy have failed this A/A run? (it must not)\n")
rounds <- sort(unique(raw$round))
sets <- if (pol$rounds >= length(rounds)) list(rounds) else utils::combn(rounds, pol$rounds, simplify = FALSE)
for (s in sets) {
  sub <- raw[raw$round %in% s, ]; sub$round <- match(sub$round, s)
  res <- judge(sub, pol, "base", "cand", plan = plan)
  fails <- res$table[res$table$verdict == "FAIL", ]
  cat(sprintf("  %s rounds {%s}: %s%s\n", tier, paste(s, collapse = ","), res$verdict,
              if (nrow(fails)) paste0("  <- ", paste(sprintf("%s %s/%s %+.0f%%", fails$metric, fails$scope, fails$visit, fails$delta_pct), collapse = "; ")) else ""))
}
