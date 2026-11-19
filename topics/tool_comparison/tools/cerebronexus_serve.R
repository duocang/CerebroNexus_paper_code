# Usage: cerebronexus_serve.R <crb> <port>
# Serves a CRB with the CerebroNexus the library path puts first. The H5 sidecar next to the .crb is found by the Viewer.
a <- commandArgs(TRUE)
suppressMessages(library(CerebroNexus))
cat("CerebroNexus version:", as.character(packageVersion("CerebroNexus")), "\n")
app <- launchCerebro(mode = "closed", crb_file_to_load = a[1])
shiny::runApp(
  app,
  host = "127.0.0.1",
  port = as.integer(a[2]),
  launch.browser = FALSE
)
