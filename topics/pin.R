# Reads topics/cerebronexus.pin: list(ref, commit, version, repo). Sourced by the run scripts of the topics.
read_pin <- function(path = NULL) {
  if (is.null(path)) {
    args <- commandArgs(FALSE)
    file <- sub("^--file=", "", grep("^--file=", args, value = TRUE)[1L])
    start <- if (!is.na(file)) {
      dirname(normalizePath(file, winslash = "/"))
    } else {
      getwd()
    }
    d <- start
    repeat {
      path <- file.path(d, "cerebronexus.pin")
      if (
        file.exists(path) ||
          file.exists(file.path(d, "topics", "cerebronexus.pin"))
      ) {
        break
      }
      if (identical(dirname(d), d)) {
        stop("cerebronexus.pin not found from ", start, call. = FALSE)
      }
      d <- dirname(d)
    }
    if (!file.exists(path)) path <- file.path(d, "topics", "cerebronexus.pin")
  }
  lines <- trimws(readLines(path, warn = FALSE))
  lines <- lines[nzchar(lines) & !startsWith(lines, "#")]
  kv <- strsplit(lines, "=", fixed = TRUE)
  out <- stats::setNames(
    lapply(kv, function(x) paste(x[-1L], collapse = "=")),
    vapply(kv, `[`, "", 1L)
  )
  need <- c("ref", "commit", "version", "repo")
  if (!all(need %in% names(out))) {
    stop(
      "cerebronexus.pin lacks: ",
      paste(setdiff(need, names(out)), collapse = ", "),
      call. = FALSE
    )
  }
  out
}
