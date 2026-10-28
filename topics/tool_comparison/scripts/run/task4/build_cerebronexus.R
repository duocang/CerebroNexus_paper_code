## CerebroNexus Builder, headless route of topics/builder_validation (profile ->
## plan -> build -> publish "CRB files + Viewer App"), into <release>; an
## existing release is replaced ("Replace existing outputs").
## Usage: build_cerebronexus.R <in.h5ad> <release> <work> [login]
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
source(file.path(bv, "scripts", "apps.R"))
rt <- bv_load_runtime()
if (length(a) >= 4 && a[4] == "login") {
  bv_build_app(rt, "pbmc3k", "pbmc3k", input = a[1], work = a[3], release = a[2],
               accounts = bv_accounts(alice = Sys.getenv("TASK4_PASSWORD")))
} else {
  invisible(bv_route(rt, "pbmc3k", "pbmc3k", input = a[1], work = a[3], release = a[2],
                     overwrite = dir.exists(a[2])))
}
cat("DONE\n")
