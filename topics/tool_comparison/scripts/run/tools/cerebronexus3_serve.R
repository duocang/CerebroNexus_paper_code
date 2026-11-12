# Usage: cerebronexus3_serve.R <crb> <port>
# Round 3: launchCerebro() of the CerebroNexus the library path puts first (PROTOCOL_round3.md). The H5 sidecar
# next to the .crb is found by the Viewer. The other route, start.R, is run as a script of its own.
a <- commandArgs(TRUE)
suppressMessages(library(CerebroNexus))
stopifnot(packageVersion("CerebroNexus") >= "8.0.1")
app <- launchCerebro(mode = "closed", crb_file_to_load = a[1])
shiny::runApp(
  app,
  host = "127.0.0.1",
  port = as.integer(a[2]),
  launch.browser = FALSE
)
