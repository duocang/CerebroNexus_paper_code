# Build the figures of every topic, or only the topics named on the command line:
#   Rscript make.R
#   Rscript make.R expression_backends
projects <- setdiff(names(yaml::read_yaml("_targets.yaml")), "main")
requested <- commandArgs(TRUE)
if (length(requested)) {
  unknown <- setdiff(requested, projects)
  if (length(unknown)) stop("Unknown topic: ", paste(unknown, collapse = ", "), call. = FALSE)
  projects <- requested
}
for (project in projects) {
  message("==> ", project)
  Sys.setenv(TAR_PROJECT = project)
  targets::tar_make()
}
