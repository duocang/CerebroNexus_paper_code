#!/usr/bin/env Rscript
# The state of a large fixture's Viewer Pack for one installed revision, as that revision sees it:
#   current        the revision accepts the Pack and finds nothing in it out of date
#   outdated: ...  the revision accepts the Pack but rebuilds part of it at run time (an older repertoire
#                  encoding): its pages take a slower path than with a Pack it built itself
#   invalid: ...   the revision does not use the Pack (another CRB, another schema, a missing file)
#   none           no Pack beside the CRB
#   unsupported    the revision has no Viewer Packs
# usage: pack_state.R LIB CRB   (prints the state on one line)
`%||%` <- function(a, b) if (is.null(a)) b else a
args <- commandArgs(trailingOnly = TRUE)
lib <- args[[1L]]; crb <- args[[2L]]
.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages(library(CerebroNexus))
ns <- asNamespace("CerebroNexus")
state <- if (!exists("validateViewerPack", envir = ns)) {
  "unsupported"
} else if (!dir.exists(sub("[.]crb$", ".viewer", crb))) {
  "none"
} else {
  check <- tryCatch(validateViewerPack(crb, full = FALSE), error = function(e) list(valid = FALSE, reason = conditionMessage(e)))
  outdated <- get0(".viewerPackImmuneOutdated", envir = ns, inherits = FALSE)
  if (!isTRUE(check$valid)) {
    paste("invalid:", check$reason %||% "unknown")
  } else if (is.function(outdated) && isTRUE(outdated(check$manifest))) {
    "outdated: repertoire encoding of another version"
  } else {
    "current"
  }
}
cat(gsub("[\t\r\n]+", " ", state), "\n", sep = "")
