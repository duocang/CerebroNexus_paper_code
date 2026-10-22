# Capture the Builder pages Figure 2 uses.
#
#   Rscript scripts/capture_builder.R <builder-url> <out-dir>
#
# The Builder must be running (see run.sh). From a fresh page the script loads
# the three built-in example datasets, captures Configure for the first one,
# marks all three as checked with "Finish Checking" (no setting is changed),
# continues to Review and captures it. Nothing is built. Viewport and pixel ratio are the same
# as for the Viewer captures.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: capture_builder.R <builder-url> <out-dir>", call. = FALSE)
url <- args[[1]]
out <- args[[2]]
topic <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), ".."))
source(file.path(topic, "scripts", "capture_lib.R"))

# The dataset rail keeps a recalculating class while it polls; it is not a
# pending render.
RAIL <- c("ds_ready_list", "ds_import_list")

b <- capture_session(url, 1024, 720)
wait_for(b, "Array.from(document.querySelectorAll('button')).some(e => /Load example datasets/.test(e.innerText))",
  what = "the Builder start page"
)
js(b, "Array.from(document.querySelectorAll('button')).find(e => /Load example datasets/.test(e.innerText)).click()")
wait_for(b, "document.querySelectorAll('[id^=pick_ds]').length === 3 && !/Loading /.test(document.body.innerText)",
  timeout = 600, what = "the three example datasets"
)
wait_idle(b, 5, 600, ignore = RAIL)
page <- js(b, "document.body.innerText")
stopifnot(
  grepl("Configure Complete Viewer demo", page),
  grepl("180\\s+CELLS", page), grepl("164\\s+GENES", page)
)
capture(b, "builder-configure", out)

# "Finish Checking" turns into "Next" and finally into "Continue to Review".
for (i in 1:6) {
  wait_for(b, "Array.from(document.querySelectorAll('#complete_dataset_check, #continue_to_review')).some(e => !e.disabled)",
    timeout = 300, what = "the next Configure action"
  )
  if (isTRUE(js(b, "!!document.getElementById('continue_to_review')"))) break
  click(b, "#complete_dataset_check")
  wait_idle(b, 4, 600, ignore = RAIL)
}
stopifnot(grepl("All datasets checked", js(b, "document.body.innerText")))
click(b, "#continue_to_review")
wait_for(b, "/Review before building/.test(document.body.innerText)", timeout = 300, what = "the Review page")
wait_idle(b, 5, 600, ignore = RAIL)
capture(b, "builder-review", out)
b$close()
