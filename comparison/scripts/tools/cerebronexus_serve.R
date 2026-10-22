# Usage: cerebronexus_serve.R <crb> <port> <embedded|h5> [h5file]
# launchCerebro() returns a shiny app object; its `...` go to shiny::shinyApp, so host/port go to runApp.
a <- commandArgs(TRUE)
suppressMessages(library(CerebroNexus))
app <- if (a[3] == "h5") {
  launchCerebro(mode = "closed", crb_file_to_load = a[1], expression_matrix_mode = "h5", expression_matrix_h5 = a[4])
} else {
  launchCerebro(mode = "closed", crb_file_to_load = a[1])
}
shiny::runApp(app, host = "127.0.0.1", port = as.integer(a[2]), launch.browser = FALSE)
