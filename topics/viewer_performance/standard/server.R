# Starts one Viewer for one CRB from an installed CerebroNexus library. Configuration is read
# from environment variables so the measured process has no other inputs:
#   PERF_LIB (library holding the candidate), PERF_CRB, PERF_PORT, and PERF_CRB2 (optional: a second
#   CRB, so that the dataset menu appears and switching datasets can be measured).
lib <- normalizePath(Sys.getenv("PERF_LIB"), mustWork = TRUE)
crb <- normalizePath(Sys.getenv("PERF_CRB"), mustWork = TRUE)
port <- as.integer(Sys.getenv("PERF_PORT"))

# The candidate must be the package that is loaded: a copy installed elsewhere would measure
# the wrong code.
installed <- normalizePath(find.package("CerebroNexus"), mustWork = TRUE)
if (!startsWith(installed, lib)) {
  stop("CerebroNexus resolves to ", installed, ", not to the candidate library ", lib, call. = FALSE)
}
cat(sprintf("PERF_INFO version=%s path=%s\n", as.character(utils::packageVersion("CerebroNexus")), installed))

## A named vector: versions before 4.4 fail on an unnamed one.
files <- c("Demo dataset" = crb)
crb2 <- Sys.getenv("PERF_CRB2", "")
if (nzchar(crb2)) files <- c(files, "Second dataset" = normalizePath(crb2, mustWork = TRUE))
app <- CerebroNexus::launchCerebro(mode = "closed", crb_file_to_load = files)
shiny::runApp(app, host = "127.0.0.1", port = port, launch.browser = FALSE)
