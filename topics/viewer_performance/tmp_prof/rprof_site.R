## Temporary: profile only the viewer server (it has PERF_PORT), not run.R or Chrome tooling.
local({
  if (nzchar(Sys.getenv("PERF_PORT")) && nzchar(Sys.getenv("CEREBRO_RPROF_DIR"))) {
    out <- file.path(
      Sys.getenv("CEREBRO_RPROF_DIR"),
      sprintf("rprof-%s-%d.out", format(Sys.time(), "%H%M%S"), Sys.getpid())
    )
    Rprof(out, interval = 0.005)
  }
})
