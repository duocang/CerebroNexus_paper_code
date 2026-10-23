# Tiny command-line parser: "--key value", "--key=value" and bare "--flag" (TRUE).
parse_cli <- function(args) {
  out <- list(); i <- 1L
  while (i <= length(args)) {
    a <- args[[i]]
    if (!startsWith(a, "--")) stop("unexpected argument: ", a, call. = FALSE)
    a <- sub("^--", "", a)
    if (grepl("=", a, fixed = TRUE)) {
      out[[sub("=.*", "", a)]] <- sub("^[^=]*=", "", a)
    } else if (i < length(args) && !startsWith(args[[i + 1L]], "--")) {
      out[[a]] <- args[[i + 1L]]; i <- i + 1L
    } else {
      out[[a]] <- TRUE
    }
    i <- i + 1L
  }
  names(out) <- gsub("-", "_", names(out), fixed = TRUE)
  out
}
