# Compares two runs of builder_performance. Usage (from the root of this repository):
#   Rscript topics/builder_performance/standard/compare.R A B [--out compare.md] [--runs DIR]
# A and B are folders in runs/ (by name) or paths. Prints, per scenario and metric, the medians, the difference,
# the p-value of the exact rank-sum test over the rounds and one of slower / faster / not resolved / too few
# rounds; then the equivalence checks of the two. When A and B are of one revision (`--candidate X --baseline X`)
# the table is the noise of the machine: nothing smaller than it can be claimed. The rule is STANDARD.md section 6.
here <- normalizePath(
  dirname(sub(
    "^--file=",
    "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
  )),
  winslash = "/"
)
topic <- dirname(here)
viewer <- file.path(dirname(topic), "viewer_performance", "standard")
for (f in c("cli.R", "lib.R")) {
  source(file.path(viewer, f))
}
source(file.path(here, "lib.R"))
args <- commandArgs(TRUE)
takes_value <- c("--out", "--runs")
pos <- character()
flags <- character()
i <- 1L
while (i <= length(args)) {
  if (args[[i]] %in% takes_value) {
    flags <- c(flags, args[i:min(i + 1L, length(args))])
    i <- i + 2L
  } else if (startsWith(args[[i]], "--")) {
    flags <- c(flags, args[[i]])
    i <- i + 1L
  } else {
    pos <- c(pos, args[[i]])
    i <- i + 1L
  }
}
opt <- parse_cli(flags)
if (length(pos) != 2L) {
  stop("usage: compare.R A B [--out FILE] [--runs DIR]", call. = FALSE)
}
runs_root <- if (is.null(opt$runs)) file.path(topic, "runs") else opt$runs
resolve <- function(x) {
  if (dir.exists(x)) normalizePath(x) else file.path(runs_root, x)
}
read_run <- function(x) {
  d <- resolve(x)
  if (!dir.exists(d)) {
    stop("no such run: ", x, call. = FALSE)
  }
  m <- read_tsv(file.path(d, "manifest.tsv"))
  list(
    id = basename(d),
    dir = d,
    raw = read_tsv(file.path(d, "raw.tsv")),
    manifest = stats::setNames(m$value, m$key),
    checks = if (file.exists(file.path(d, "checks.tsv"))) {
      read_tsv(file.path(d, "checks.tsv"))
    } else {
      NULL
    }
  )
}
a <- read_run(pos[[1L]])
b <- read_run(pos[[2L]])
mv <- function(r, k) {
  if (k %in% names(r$manifest)) r$manifest[[k]] else NA_character_
}
pair <- function(r) {
  p <- mv(r, "pair_id")
  if (is.na(p)) "" else p
}
paired <- nzchar(pair(a)) && identical(pair(a), pair(b))
same_revision <- !is.na(mv(a, "sha")) && identical(mv(a, "sha"), mv(b, "sha"))
keys <- c(
  "platform",
  "host",
  "cpu",
  "mem_total_mib",
  "r_version",
  "fixtures_md5",
  "scenarios_md5",
  "rounds"
)
differ <- keys[!mapply(function(k) identical(mv(a, k), mv(b, k)), keys)]
cmp <- compare_raw(a$raw, b$raw, paired = paired)
lines <- compare_lines(cmp, a$id, b$id, differ, paired, same_revision)

# Memory and CPU: reported, not judged.
extra <- lapply(c("peak_mib", "cpu_s", "out_mib"), function(m) {
  d <- do.call(
    rbind,
    lapply(union(unique(a$raw$scenario), unique(b$raw$scenario)), function(s) {
      x <- med(a$raw[[m]][a$raw$scenario == s & a$raw$status == "ok"])
      y <- med(b$raw[[m]][b$raw$scenario == s & b$raw$status == "ok"])
      if (is.na(x) && is.na(y)) {
        return(NULL)
      }
      data.frame(
        scenario = s,
        metric = m,
        A = fmt_num(x, 0L),
        B = fmt_num(y, 0L),
        stringsAsFactors = FALSE
      )
    })
  )
  d
})
extra <- do.call(rbind, extra)
if (!is.null(extra) && nrow(extra)) {
  lines <- c(
    lines,
    "Memory, CPU and output size (not judged):",
    "",
    md_table(extra),
    ""
  )
}

# The equivalence checks of both runs; the digest of the H5 content must agree across revisions.
chk <- function(r) if (is.null(r$checks)) NULL else r$checks
if (!is.null(chk(a)) || !is.null(chk(b))) {
  lines <- c(lines, "Equivalence checks:", "")
  for (r in list(a, b)) {
    if (!is.null(r$checks)) {
      lines <- c(
        lines,
        sprintf(
          "- %s: %d of %d passed",
          r$id,
          sum(r$checks$result == "pass"),
          nrow(r$checks)
        )
      )
    }
  }
  da <- a$checks$detail[a$checks$check == "h5_content_digest"]
  db <- b$checks$detail[b$checks$check == "h5_content_digest"]
  if (length(da) && length(db)) {
    lines <- c(
      lines,
      if (identical(da, db)) {
        "- the H5 written by A and by B holds the same data (same digest)"
      } else {
        sprintf(
          "- **the H5 written by A and by B differs**: A %s, B %s",
          da,
          db
        )
      }
    )
  }
  lines <- c(lines, "")
}
if (same_revision) {
  rel <- cmp$delta_pct[
    cmp$metric %in% names(time_metrics) & !is.na(cmp$delta_pct)
  ]
  if (length(rel)) {
    lines <- c(
      lines,
      sprintf(
        "Noise of this machine (one revision against itself): medians differ by %.1f %% at most, %.1f %% typically; %d of %d rows resolve a difference.",
        max(abs(rel)),
        stats::median(abs(rel)),
        sum(cmp$change %in% c("slower", "faster")),
        nrow(cmp)
      ),
      ""
    )
  }
}
cat(lines, sep = "\n")
if (!is.null(opt$out)) {
  writeLines(lines, opt$out)
}
