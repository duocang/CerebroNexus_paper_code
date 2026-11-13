# Compare two runs: Rscript topics/app_export/standard/compare.R RUN_A RUN_B   (folder names below runs/)
here <- normalizePath(
  dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
  winslash = "/"
)
a <- commandArgs(TRUE)
read_run <- function(x) {
  utils::read.delim(file.path(dirname(here), "runs", x, "scenarios.tsv"), stringsAsFactors = FALSE)
}
m <- merge(read_run(a[[1L]]), read_run(a[[2L]]), by = "scenario", suffixes = c("_a", "_b"))
# slower / faster: a difference above 20 % + 0.3 s (seconds) or 20 % (memory, size), an indicative line.
flag <- function(x, y, floor) {
  ifelse(y > x * 1.2 + floor, "slower", ifelse(y < x * 0.8 - floor, "faster", ""))
}
for (metric in c("first_s", "repeat_s", "peak_mib", "out_mib")) {
  xa <- m[[paste0(metric, "_a")]]
  xb <- m[[paste0(metric, "_b")]]
  cat("\n", metric, "\n", sep = "")
  print(
    data.frame(
      scenario = m$scenario,
      A = round(xa, 1),
      B = round(xb, 1),
      diff = round(xb - xa, 1),
      note = flag(xa, xb, if (grepl("_s$", metric)) 0.3 else 0)
    ),
    row.names = FALSE
  )
}
