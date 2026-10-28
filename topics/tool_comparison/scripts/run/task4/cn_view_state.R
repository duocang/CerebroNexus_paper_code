## Decode a Linked views View JSON with the App's own server code
## (viewer/coordinated_views/config.R, as "Open JSON" does) against the App's CRB.
## Usage: cn_view_state.R <app dir> <view.json>   (prints the restored cell count)
a <- commandArgs(TRUE)
env <- new.env()
env$`%||%` <- function(x, y) if (is.null(x)) y else x
sys.source(file.path(a[1], "viewer", "coordinated_views", "config.R"), envir = env)
crb <- CerebroNexus::readCerebro(list.files(file.path(a[1], "private-data"), pattern = "[.]crb$", full.names = TRUE)[1])
cells <- crb$getCellNames()
doc <- env$cv_config_decode(paste(readLines(a[2], warn = FALSE), collapse = "\n"), cells = cells,
                            fingerprint = env$cv_config_cell_fingerprint(cells))
cat(length(doc$selection$cells), "\n")
