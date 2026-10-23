# Process-tree helpers over /proc (Linux), shared by sampler.R and measure_session.R.

# Children of every process: a list from parent pid (character) to child pids.
proc_children <- function() {
  pids <- list.files("/proc", "^[0-9]+$")
  ppid <- vapply(pids, function(p) {
    s <- tryCatch(readLines(file.path("/proc", p, "stat"), n = 1L, warn = FALSE), error = function(e) "")
    if (!length(s) || !nzchar(s)) return(NA_character_)
    strsplit(sub("^.*\\) ", "", s), " ", fixed = TRUE)[[1L]][[2L]]
  }, "")
  split(pids, ppid)
}

# The process and all its descendants.
proc_tree <- function(root, kids = proc_children()) {
  seen <- character(); queue <- as.character(root)
  while (length(queue)) {
    p <- queue[[1L]]; queue <- queue[-1L]
    if (p %in% seen) next
    seen <- c(seen, p)
    queue <- c(queue, kids[[p]])
  }
  seen
}

# CPU seconds (user + system) used so far by the given processes. /proc counts in 1/100 s.
proc_cpu_seconds <- function(pids) {
  total <- 0
  for (p in pids) {
    s <- tryCatch(readLines(file.path("/proc", p, "stat"), n = 1L, warn = FALSE), error = function(e) character())
    if (!length(s)) next
    f <- strsplit(sub("^.*\\) ", "", s), " ", fixed = TRUE)[[1L]]
    total <- total + (as.numeric(f[[12L]]) + as.numeric(f[[13L]])) / 100
  }
  total
}

# Wait until the process tree has used less than `thr` CPU seconds per second for `need` seconds in a
# row, so that a measurement starts from a quiet server (prefetching and garbage collection after the
# previous page are finished). Returns the seconds waited, or NA if `max_s` ran out.
wait_tree_idle <- function(root, max_s = 120, need = 3L, thr = 0.05) {
  t0 <- Sys.time(); calm <- 0L
  repeat {
    a <- proc_cpu_seconds(proc_tree(root)); Sys.sleep(1); b <- proc_cpu_seconds(proc_tree(root))
    calm <- if ((b - a) < thr) calm + 1L else 0L
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (calm >= need) return(elapsed)
    if (elapsed > max_s) return(NA_real_)
  }
}
