# The versions of the R packages the comparison uses, one "name = version" line each (for the run's manifest).
for (p in c("ShinyCell", "iSEE", "anndataR")) {
  cat(
    p,
    "=",
    tryCatch(as.character(packageVersion(p)), error = function(e) "missing"),
    "\n"
  )
}
