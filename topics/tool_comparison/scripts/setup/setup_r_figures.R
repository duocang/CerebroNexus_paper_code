# Figure packages (binaries) into env/rlib, with their dependency closure: patchwork, svglite.
lib <- normalizePath("env/rlib", winslash = "/", mustWork = TRUE)
.libPaths(lib)
options(repos = c(CRAN = "https://cloud.r-project.org"))
db <- available.packages(type = "binary")
top <- c("patchwork", "svglite")
all <- setdiff(
  unique(c(
    top,
    unlist(tools::package_dependencies(
      top,
      db = db,
      which = c("Depends", "Imports", "LinkingTo"),
      recursive = TRUE
    ))
  )),
  rownames(installed.packages(priority = "base"))
)
todo <- setdiff(all, rownames(installed.packages(lib.loc = lib)))
cat("to install:", todo, "\n")
if (length(todo)) {
  install.packages(todo, lib = lib, type = "binary", dependencies = FALSE)
}
cat(
  "patchwork",
  as.character(packageVersion("patchwork", lib.loc = lib)),
  "svglite",
  as.character(packageVersion("svglite", lib.loc = lib)),
  "\n"
)
