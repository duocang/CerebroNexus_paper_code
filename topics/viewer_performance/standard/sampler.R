# Samples the memory and CPU of two process trees (the R server and Chrome) about every 150 ms from /proc.
# usage: sampler.R SERVER_PID CHROME_PID OUT.csv STOP_FILE
# SERVER_PID 0: the server is not started yet; its id is read from OUT.csv.pid once that file is there.
# Memory columns are bytes; r_cpu and c_cpu are the CPU seconds each tree has used so far. rss counts
# shared pages once per process; pss divides them between the processes that share them, so pss is the
# one to add up across a Chrome process tree.
a <- commandArgs(trailingOnly = TRUE)
server_pid <- a[[1L]]; chrome_pid <- a[[2L]]; out <- a[[3L]]; stop_file <- a[[4L]]
page <- 4096
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])))
source(file.path(here, "proc.R"))

mem_of <- function(pids) {
  rss <- 0; pss <- 0
  for (p in pids) {
    st <- tryCatch(readLines(file.path("/proc", p, "statm"), n = 1L, warn = FALSE), error = function(e) character())
    if (length(st)) rss <- rss + as.numeric(strsplit(st, " ", fixed = TRUE)[[1L]][[2L]]) * page
    sm <- tryCatch(readLines(file.path("/proc", p, "smaps_rollup"), warn = FALSE), error = function(e) character())
    l <- grep("^Pss:", sm, value = TRUE)
    if (length(l)) pss <- pss + as.numeric(strsplit(trimws(sub("^Pss:", "", l[[1L]])), " ", fixed = TRUE)[[1L]][[1L]]) * 1024
  }
  c(rss, pss)
}

con <- file(out, "w")
writeLines("t_ms,r_rss,r_pss,c_rss,c_pss,r_cpu,c_cpu", con)
pid_file <- paste0(out, ".pid")
while (!file.exists(stop_file)) {
  if (identical(server_pid, "0") && file.exists(pid_file)) {
    line <- trimws(readLines(pid_file, n = 1L, warn = FALSE))
    if (length(line) && grepl("^[0-9]+$", line)) server_pid <- line
  }
  t <- round(as.numeric(Sys.time()) * 1000)
  kids <- proc_children()
  rt <- if (identical(server_pid, "0")) character() else proc_tree(server_pid, kids)   # pid 0: every process
  ct <- proc_tree(chrome_pid, kids)
  r <- mem_of(rt); c <- mem_of(ct)
  writeLines(sprintf("%.0f,%.0f,%.0f,%.0f,%.0f,%.2f,%.2f", t, r[[1L]], r[[2L]], c[[1L]], c[[2L]],
                     proc_cpu_seconds(rt), proc_cpu_seconds(ct)), con)
  flush(con)
  Sys.sleep(0.15)
}
close(con)
