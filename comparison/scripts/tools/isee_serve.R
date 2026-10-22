# Usage: isee_serve.R <sce.rds> <port>
a <- commandArgs(TRUE)
suppressMessages(library(iSEE))
sce <- readRDS(a[1])
app <- iSEE(sce)
shiny::runApp(app, host = "127.0.0.1", port = as.integer(a[2]), launch.browser = FALSE)
