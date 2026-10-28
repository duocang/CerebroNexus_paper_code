## CerebroNexus release recovery after a killed build: builder_discover_recovery()
## and, when recovery is required, builder_recover_release(action = "restore").
## Usage: cn_recover.R <release>   (prints "state=<before> -> <after>")
a <- commandArgs(TRUE)
bv <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))),
                              "..", "..", "..", "..", "builder_validation"))
setwd(bv)
## common.R finds its topic from the running script's path; run it as if
## started from builder_validation/scripts.
commandArgs <- function(trailingOnly = FALSE) {
  if (trailingOnly) a else paste0("--file=", file.path(bv, "scripts", "common.R"))
}
source(file.path(bv, "scripts", "common.R"))
rm(commandArgs)
rt <- bv_load_runtime()
d <- tryCatch(rt$builder_discover_recovery(a[1]), error = function(e) list(state = paste("error:", conditionMessage(e))))
after <- d$state
if (identical(d$state, "recovery_required")) {
  r <- tryCatch(rt$builder_recover_release(a[1], action = "restore"), error = function(e) list(state = paste("error:", conditionMessage(e))))
  after <- r$state %||% "restored"
}
cat(sprintf("state=%s -> %s\n", d$state %||% "none", after %||% "none"))
