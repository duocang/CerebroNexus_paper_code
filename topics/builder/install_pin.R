## Install the CerebroNexus revision of topics/cerebronexus.pin into a library and stamp the commit on it.
##
## The pinned commit may exist only in a local clone, so it is installed from `git archive`, which carries
## no commit id; the stamp (<lib>/CerebroNexus/PIN_COMMIT) is what build_crbs.R checks.
##
## Usage (from any directory):
##   Rscript --vanilla install_pin.R <cerebronexus_clone> <r_library>

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
repo <- normalizePath(args[[1L]], mustWork = TRUE)
lib <- args[[2L]]
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
lib <- normalizePath(lib, mustWork = TRUE)

here <- local({
  file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
  dirname(normalizePath(file, mustWork = TRUE))
})
pin <- local({
  d <- here
  while (!file.exists(file.path(d, "cerebronexus.pin"))) {
    if (identical(dirname(d), d)) stop("cerebronexus.pin not found above ", here)
    d <- dirname(d)
  }
  lines <- trimws(readLines(file.path(d, "cerebronexus.pin"), warn = FALSE))
  lines <- lines[nzchar(lines) & !startsWith(lines, "#")]
  kv <- regmatches(lines, regexpr("=", lines), invert = TRUE)
  stats::setNames(vapply(kv, `[`, "", 2L), vapply(kv, `[`, "", 1L))
})

src <- tempfile("cerebronexus-src-")
dir.create(src)
tarball <- tempfile(fileext = ".tar")
on.exit(unlink(c(src, tarball), recursive = TRUE), add = TRUE)
stopifnot(system2("git", c("-C", shQuote(repo), "archive", "--format=tar", "-o", shQuote(tarball), pin[["commit"]])) == 0L)
utils::untar(tarball, exdir = src, tar = "internal")
stopifnot(system2(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", "--no-docs", "--no-multiarch",
                                                    paste0("--library=", shQuote(lib)), shQuote(src))) == 0L)
writeLines(pin[["commit"]], file.path(lib, "CerebroNexus", "PIN_COMMIT"))
cat("Installed", pin[["commit"]], "(pin version", pin[["version"]], ") into", lib, "\n")
