# Helpers shared by the Task 1 scripts (PROTOCOL section 5).
suppressMessages(library(jsonlite))
t1_run <- function(expr_fun) {
  # Runs expr_fun(); returns list(ok, value, error, warnings, messages)
  warns <- character(0); msgs <- character(0)
  val <- tryCatch(
    withCallingHandlers(expr_fun(),
      warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") },
      message = function(m) { msgs <<- c(msgs, trimws(conditionMessage(m))); invokeRestart("muffleMessage") }),
    error = function(e) structure(list(msg = conditionMessage(e)), class = "t1_error"))
  if (inherits(val, "t1_error")) list(ok = FALSE, value = NULL, error = substr(val$msg, 1, 500), warnings = unique(warns), messages = msgs)
  else list(ok = TRUE, value = val, error = NA_character_, warnings = unique(warns), messages = msgs)
}
t1_write <- function(row, path) write(toJSON(row, auto_unbox = TRUE, null = "null", na = "null", pretty = TRUE), path)
