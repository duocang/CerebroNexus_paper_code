# Usage: cerebronexus_serve.R <crb> <port>
# launchCerebro() of the merged build (tmp/应急, 6.0.0) has no expression_matrix_* arguments: an H5 sidecar next to the .crb is found by the Viewer.
# launchCerebro() returns a shiny app object; its `...` go to shiny::shinyApp, so host/port go to runApp.
a <- commandArgs(TRUE)
suppressMessages(library(CerebroNexus))
stopifnot(as.character(packageVersion("CerebroNexus")) == "6.0.0")
app <- launchCerebro(mode = "closed", crb_file_to_load = a[1])
shiny::runApp(
  app,
  host = "127.0.0.1",
  port = as.integer(a[2]),
  launch.browser = FALSE
)
