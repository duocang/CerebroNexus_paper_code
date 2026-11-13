# One export session: a fresh R process builds the App twice into the same folder. Started by run.R.
# usage: Rscript worker.R LIB CRB OUT_DIR RESULT_JSON LABEL
a <- commandArgs(TRUE)
lib <- a[[1L]]
crb <- a[[2L]]
out <- a[[3L]]
res <- a[[4L]]
label <- a[[5L]]
suppressPackageStartupMessages(library(CerebroNexus, lib.loc = lib))
export <- function() {
  t0 <- proc.time()[["elapsed"]]
  err <- tryCatch(
    {
      CerebroNexus::createShinyApp(
        stats::setNames(crb, label),
        result_dir = out,
        launch_browser = FALSE,
        quiet = TRUE,
        verbose = FALSE,
        overwrite = TRUE
      )
      NA_character_
    },
    error = function(e) conditionMessage(e)
  )
  list(s = proc.time()[["elapsed"]] - t0, error = err)
}
first <- export()
files <- list.files(out, recursive = TRUE, all.files = TRUE, full.names = TRUE)
bytes <- sum(file.size(files), na.rm = TRUE)
again <- export()
cpu <- proc.time()
## Peak resident memory of this process: Windows keeps the peak working set, Linux VmHWM.
peak_mib <- if (.Platform$OS.type == "windows") {
  ps::ps_memory_info(ps::ps_handle())[["peak_wset"]] / 2^20
} else {
  status <- readLines("/proc/self/status")
  as.numeric(gsub("[^0-9]", "", grep("^VmHWM:", status, value = TRUE))) / 1024
}
writeLines(
  jsonlite::toJSON(
    list(
      first_s = first$s,
      first_error = first$error,
      repeat_s = again$s,
      repeat_error = again$error,
      out_files = length(files),
      out_bytes = bytes,
      cpu_s = cpu[["user.self"]] + cpu[["sys.self"]],
      peak_mib = peak_mib
    ),
    auto_unbox = TRUE,
    na = "null"
  ),
  res
)
