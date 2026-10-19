# Latest nixpkgs date published by the osmzhlab Attic cache, so both
# environments use a snapshot with binary substitutes. Also returns the BPCells
# revision that cache built for that date.
osmzhlab_reports <- "https://raw.githubusercontent.com/mihem/attic/main/reports"

osmzhlab_latest_date <- function() {
  readme <- readLines(file.path(osmzhlab_reports, "README.md"), warn = FALSE)
  dates <- sort(unique(unlist(regmatches(readme, gregexpr("[0-9]{4}-[0-9]{2}-[0-9]{2}", readme)))))
  latest <- tail(dates, 1)
  if (length(latest) == 0 || is.na(latest)) stop("Could not determine latest osmzhlab cache date")
  cat("Using latest_date:", latest, "\n")
  latest
}

osmzhlab_bpcells_rev <- function(date) {
  pins <- readLines(sprintf("%s/%s/pins.json", osmzhlab_reports, date), warn = FALSE)
  pin_value <- function(name) {
    line <- grep(sprintf('"%s"', name), pins, value = TRUE)
    sub(sprintf('.*"%s"[[:space:]]*:[[:space:]]*"([^"]+)".*', name), "\\1", line)
  }
  if (!identical(pin_value("r_nixpkgs_date"), date)) {
    stop("pins.json date does not match selected osmzhlab cache date")
  }
  sha <- pin_value("bp_cells_rev")
  if (length(sha) != 1 || !grepl("^[0-9a-f]{40}$", sha)) {
    stop("Could not determine BPCells revision from osmzhlab Attic pins.json")
  }
  cat("Using BPCells revision:", sha, "\n")
  sha
}
