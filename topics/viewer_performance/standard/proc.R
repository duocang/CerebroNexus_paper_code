# Process helpers shared by sampler.R, measure_session.R and run.R. The CPU and memory of the two trees
# (R server, Chrome) are sampled by one process per session: sampler.R on Linux (/proc), sampler.ps1 on
# Windows. Both write the same CSV; waiting for quiet reads it, so both platforms judge quiet the same way.

on_windows <- .Platform$OS.type == "windows"
r_bin <- function(name) file.path(R.home("bin"), if (on_windows) paste0(name, ".exe") else name)

# ---- Linux: /proc ----------------------------------------------------------------------------------

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

# CPU seconds used so far by the given processes, including their children that have exited (so the sum
# over a tree does not drop when a worker ends). /proc counts in 1/100 s.
proc_cpu_seconds <- function(pids) {
  total <- 0
  for (p in pids) {
    s <- tryCatch(readLines(file.path("/proc", p, "stat"), n = 1L, warn = FALSE), error = function(e) character())
    if (!length(s)) next
    f <- as.numeric(strsplit(sub("^.*\\) ", "", s), " ", fixed = TRUE)[[1L]][12:15])
    total <- total + sum(f) / 100
  }
  total
}

# ---- both platforms ----------------------------------------------------------------------------------

# Start the sampler of this platform; returns the processx handle once the first sample is written.
start_sampler <- function(here, server_pid, chrome_pid, csv, stop_file) {
  s <- if (on_windows) {
    processx::process$new("powershell.exe", c("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", file.path(here, "sampler.ps1"),
                                              server_pid, chrome_pid, csv, stop_file), stderr = "|", cleanup_tree = TRUE)
  } else {
    processx::process$new(r_bin("Rscript"), c("--no-save", "--no-restore", file.path(here, "sampler.R"),
                                              server_pid, chrome_pid, csv, stop_file), stderr = "|", cleanup_tree = TRUE)
  }
  t0 <- Sys.time()
  while (!file.exists(csv) || length(readLines(csv, warn = FALSE)) < 3L) {
    if (!s$is_alive()) stop("the sampler stopped: ", s$read_all_error())
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > 60) stop("the sampler wrote nothing for 60 s")
    Sys.sleep(0.05)
  }
  s
}

# The sampler's CSV as a data frame, from `since_ms` on (all of it when NA). A line still being written is
# dropped. The CPU columns are made non-decreasing: on Windows a tree's sum drops when a child exits.
read_trace <- function(path, since_ms = NA_real_) {
  lines <- readLines(path, warn = FALSE)
  head <- strsplit(lines[[1L]], ",", fixed = TRUE)[[1L]]
  body <- lines[-1L]
  if (!is.na(since_ms) && length(body)) {
    t <- suppressWarnings(as.numeric(sub(",.*", "", body)))
    body <- body[!is.na(t) & t >= since_ms]
  }
  f <- strsplit(body, ",", fixed = TRUE)
  f <- f[lengths(f) == length(head)]
  x <- as.data.frame(matrix(as.numeric(unlist(f)), ncol = length(head), byrow = TRUE, dimnames = list(NULL, head)))
  for (k in intersect(c("r_cpu", "c_cpu"), names(x))) if (nrow(x) > 1L) x[[k]] <- x[[k]][[1L]] + c(0, cumsum(pmax(0, diff(x[[k]]))))
  x
}

# Wait until the R server and Chrome are both quiet: every 1 s window of the last `need` seconds below the
# tree's threshold (quiet_thr in lib.R, CPU seconds per second), judged on the sampler's trace. Returns
#   waited_s      seconds waited
#   quiet_from_ms when the quiet stretch began (epoch ms, not before the call), NA if `max_s` ran out first.
wait_quiet <- function(trace, thr = quiet_thr, need = quiet_need_s, max_s = 120, step = 0.25) {
  t0 <- Sys.time(); t0_ms <- as.numeric(t0) * 1000
  repeat {
    Sys.sleep(step)
    x <- read_trace(trace, since_ms = t0_ms - 2000)
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (nrow(x) >= 2L) {
      q <- quiet_from(x$t_ms, cbind(x$r_cpu, x$c_cpu), thr[c("r", "chrome")], from = t0_ms)
      if (!is.na(q) && x$t_ms[[nrow(x)]] - q >= need * 1000) return(list(waited_s = elapsed, quiet_from_ms = q))
    }
    if (elapsed > max_s) return(list(waited_s = elapsed, quiet_from_ms = NA_real_))
  }
}

# ---- platform facts for run.R --------------------------------------------------------------------------

# "windows", "linux-wsl", "linux", or NA (not supported).
platform_name <- function() {
  if (on_windows) return("windows")
  if (!file.exists("/proc/version")) return(NA_character_)
  if (grepl("microsoft", paste(readLines("/proc/version", warn = FALSE), collapse = " "), ignore.case = TRUE)) "linux-wsl" else "linux"
}

powershell <- function(lines) {
  ps1 <- tempfile(fileext = ".ps1"); writeLines(lines, ps1); on.exit(unlink(ps1))
  suppressWarnings(system2("powershell.exe", c("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps1), stdout = TRUE, stderr = FALSE))
}

pid_alive <- function(pid) {
  if (!on_windows) return(dir.exists(file.path("/proc", pid)))
  any(grepl(sprintf("\b%s\b", pid), suppressWarnings(system2("tasklist", c("/FI", shQuote(sprintf("PID eq %s", pid)), "/NH"), stdout = TRUE))))
}

# Other measured sessions or headless browsers under remote control, which would share the machine.
stray_processes <- function() {
  if (on_windows) {
    x <- powershell("Get-CimInstance Win32_Process | ForEach-Object { \"$($_.ProcessId)`t$($_.CommandLine)\" }")
    pid <- sub("\t.*", "", x); cl <- sub("^[^\t]*\t", "", x)
    hit <- grepl("measure_session[.]R", cl) | (grepl("--headless", cl, fixed = TRUE) & grepl("--remote-debugging-port", cl, fixed = TRUE))
  } else {
    pid <- list.files("/proc", "^[0-9]+$")
    hit <- vapply(pid, function(p) {
      cl <- tryCatch(readBin(file.path("/proc", p, "cmdline"), "raw", 65536L), error = function(e) raw())
      grepl("measure_session[.]R|remote-debugging-port", rawToChar(replace(cl, cl == as.raw(0L), as.raw(32L))))
    }, TRUE)
  }
  setdiff(pid[hit], as.character(Sys.getpid()))
}

# OS, CPU, memory and GPU of the machine, for the manifest.
machine_facts <- function() {
  first <- function(x) if (length(x)) x[[1L]] else NA_character_
  if (on_windows) {
    x <- powershell(c("$o = Get-CimInstance Win32_OperatingSystem",
                      "(Get-CimInstance Win32_Processor | Select-Object -First 1).Name",
                      "$o.Caption + ' ' + $o.Version",
                      "[math]::Round($o.TotalVisibleMemorySize / 1024)",
                      "(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }) -join ' / '"))
    x <- c(x, rep(NA_character_, 4L))
    return(list(cpu = trimws(x[[1L]]), os = x[[2L]], mem_total_mib = x[[3L]], gpu = x[[4L]]))
  }
  rd <- function(f, key) first(grep(key, readLines(f, warn = FALSE), value = TRUE))
  list(cpu = sub("^.*: ", "", rd("/proc/cpuinfo", "^model name")),
       os = first(suppressWarnings(system2("uname", "-sr", stdout = TRUE))),
       mem_total_mib = round(as.numeric(sub("[^0-9]*([0-9]+).*", "\1", rd("/proc/meminfo", "^MemTotal"))) / 1024),
       gpu = "none (software rendering)")
}

load1 <- function() if (on_windows) NA_real_ else as.numeric(strsplit(readLines("/proc/loadavg", warn = FALSE), " ")[[1L]][[1L]])

default_cache <- function() {
  if (on_windows) return(file.path(Sys.getenv("LOCALAPPDATA"), "cerebronexus-viewer-perf"))
  file.path(Sys.getenv("XDG_CACHE_HOME", file.path(Sys.getenv("HOME"), ".cache")), "cerebronexus-viewer-perf")
}
