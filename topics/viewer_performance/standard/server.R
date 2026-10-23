# Starts one Viewer for one CRB from an installed CerebroNexus library. Configuration is read
# from environment variables so the measured process has no other inputs:
#   PERF_LIB (library holding the candidate), PERF_CRB, PERF_PORT.
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
app <- CerebroNexus::launchCerebro(mode = "closed", crb_file_to_load = c("Demo dataset" = crb))
shiny::runApp(app, host = "127.0.0.1", port = port, launch.browser = FALSE)
