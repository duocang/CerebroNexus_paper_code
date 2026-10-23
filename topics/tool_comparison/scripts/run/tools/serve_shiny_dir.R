# Usage: serve_shiny_dir.R <app dir> <port>   (ShinyCell-generated app)
a <- commandArgs(TRUE)
shiny::runApp(a[1], host = "127.0.0.1", port = as.integer(a[2]), launch.browser = FALSE)
