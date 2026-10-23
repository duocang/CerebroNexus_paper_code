# Usage: task1/isee.R <dataset> <route sce|sce-dup> <input orig|rewritten|constructed> <workaround 0|1> <out.json>
a <- commandArgs(TRUE); ds <- a[1]; route <- a[2]; kind <- a[3]; wk <- a[4] == "1"; out <- a[5]
suppressMessages(library(iSEE)); source("scripts/run/task1/common.R"); source("scripts/run/task1/rside.R")
row <- list(tool = "iSEE", dataset = ds, route = route, input = kind, workaround = wk)
stage <- "read"
r <- t1_run(function() {
  sce <- r_object(ds, kind, route)
  stage <<- "iSEE"
  if (wk) sce <- plain_reduced_dims(sce)
  facts <- sce_facts(sce)
  app <- iSEE(sce)
  stopifnot(inherits(app, "shiny.appobj"))
  facts$reduced_dim_classes <- vapply(reducedDimNames(sce), function(n) class(reducedDim(sce, n))[1], character(1))
  facts$app_built <- TRUE
  facts
})
row$status <- if (r$ok) "ok" else "error"; row$error_message <- r$error; row$failed_stage <- if (r$ok) NA else stage; row$warnings <- r$warnings
row$required_args <- "iSEE(se)"
if (r$ok) row <- c(row, r$value)
t1_write(row, out); cat("WROTE", out, row$status, "\n")
