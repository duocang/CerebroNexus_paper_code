## Experiment E: authorization boundary and data leakage of generated Apps.
##
## Builds three Apps through the headless Builder route (scripts/apps.R):
## Visium + H&E with login (accounts alice, bob), PBMC Seurat with login
## (accounts alice with another password, carol) and Visium + H&E without
## login. Each App runs as a deployment would (shiny::runApp, no test mode)
## in a separate R process without CerebroNexus on its library path. Tests use
## plain HTTP (curl --path-as-is, so ".." is sent as typed) and headless Chrome
## through CDP, which records every websocket frame and request. Each test is
## one row of results/E_security.csv; evidence files are in results/E_evidence/.
##
## Threat model and scope: THREAT_MODEL.md.
##
## Usage: Rscript scripts/E_security.R
## The test passwords below are generated test values for these local Apps.

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
source(file.path(bv_root, "scripts", "viewer.R"))
source(file.path(bv_root, "scripts", "apps.R"))
source(file.path(bv_root, "scripts", "browser.R"))

root <- file.path(bv_data, "E")
evidence <- file.path(bv_root, "results", "E_evidence")
dir.create(root, recursive = TRUE, showWarnings = FALSE)
dir.create(evidence, recursive = TRUE, showWarnings = FALSE)
logs <- file.path(root, "logs")
rt <- bv_load_runtime()
set.seed(7)

pw <- list(
  alice = "alice-visium-7f3k2",
  bob = "bob-visium-9q8w1",
  alice_pbmc = "alice-pbmc-4m6n0",
  carol = "carol-pbmc-2z5x8"
)
inputs <- file.path(bv_data, "inputs")
visium_rds <- file.path(inputs, "visium_anterior1.rds")
visium_png <- file.path(inputs, "visium_anterior1_he.png")
visium_image <- function() {
  ins <- rt$builder_read_image(visium_png)
  d <- dim(png::readPNG(visium_png))
  lowres <- 0.05163511
  rec <- rt$builder_alignment_record(
    source = list(name = basename(visium_png), type = ins$mime, size = ins$bytes),
    base_bounds = list(xmin = 0, xmax = d[2] / lowres, ymin = 0, ymax = d[1] / lowres),
    section = list(id = "anterior1", kind = "spatial"),
    source_path = ins$source_path
  )
  rec$source_content_md5 <- ins$source_content_md5
  list(images = list(anterior1 = rec))
}

## ---- build -------------------------------------------------------------------
build_log <- file.path(logs, "build.log")
dir.create(logs, showWarnings = FALSE, recursive = TRUE)
zz <- file(build_log, open = "wt")
sink(zz, type = "output"); sink(zz, type = "message")
apps <- list(
  visium_login = bv_build_app(rt, "visium", "Visium anterior1", visium_rds,
                              work = file.path(root, "visium_login", "work"),
                              release = file.path(root, "visium_login", "release"),
                              configure = visium_image(),
                              accounts = bv_accounts(alice = pw$alice, bob = pw$bob)),
  pbmc_login = bv_build_app(rt, "pbmc", "PBMC", file.path(inputs, "pbmc_seurat.rds"),
                            work = file.path(root, "pbmc_login", "work"),
                            release = file.path(root, "pbmc_login", "release"),
                            accounts = bv_accounts(alice = pw$alice_pbmc, carol = pw$carol)),
  visium_public = bv_build_app(rt, "visium", "Visium anterior1", visium_rds,
                               work = file.path(root, "visium_public", "work"),
                               release = file.path(root, "visium_public", "release"),
                               configure = visium_image())
)
sink(type = "message"); sink(type = "output"); close(zz)
for (a in apps) cat(a$id, a$app_dir, round(a$seconds, 1), "s\n")

## ---- what counts as data ------------------------------------------------------
crb <- readCerebro(apps$visium_login$crb)
barcodes <- crb$getCellNames()
genes <- crb$getGeneNames()
terms <- unique(c(
  sample(barcodes, 200),
  sample(genes[nchar(genes) >= 5], 200),
  "Visium anterior1"
))
pbmc_crb <- readCerebro(apps$pbmc_login$crb)
pbmc_terms <- unique(c(sample(pbmc_crb$getCellNames(), 50), "PBMC"))

rows <- list()
record <- function(test, app, expected, observed, result, evidence_file = "") {
  cat(sprintf("[%s] %s: %s\n", result, test, observed))
  rows[[length(rows) + 1L]] <<- data.frame(
    test = test, app = app, expected = expected, observed = bv_one_line(observed, 600),
    result = result, evidence = evidence_file, stringsAsFactors = FALSE)
}
pass_if <- function(ok) if (isTRUE(ok)) "pass" else "fail"

## ---- HTTP helpers ---------------------------------------------------------------
curl_get <- function(url, out = tempfile()) {
  code <- suppressWarnings(system2("curl", c("--path-as-is", "-s", "-o", shQuote(out),
    "-w", "'%{http_code}'", "--max-time", "20", shQuote(url)), stdout = TRUE))
  list(status = as.integer(gsub("'", "", code)), file = out,
       bytes = if (file.exists(out)) file.size(out) else 0)
}
private_files <- function(app_dir) {
  f <- list.files(app_dir, recursive = TRUE, all.files = TRUE, full.names = FALSE)
  f[grepl("^(private-data/|viewer-auth\\.env$|cerebro_config\\.rds$|app\\.R$)", f)]
}
probe_paths <- function(app, app_dir, html) {
  www_prefix <- regmatches(html, regexpr("cerebro_www[_0-9]*", html))
  www_prefix <- if (length(www_prefix)) www_prefix else "cerebro_www"
  files <- private_files(app_dir)
  release_files <- c("build-report.json", ".cerebro-builder-release-v1")
  paths <- character()
  for (f in files) {
    enc <- gsub("/", "%2f", f, fixed = TRUE)
    paths <- c(paths,
      paste0("/", f),
      paste0("/cerebro_app/", f),
      paste0("//", f),
      paste0("/./", f),
      paste0("/", www_prefix, "/../../", f),
      paste0("/", www_prefix, "/%2e%2e/%2e%2e/", f),
      paste0("/", www_prefix, "/..%2f..%2f", enc),
      paste0("/", www_prefix, "/%252e%252e/%252e%252e/", f),
      paste0("/", www_prefix, "/..\\..\\", gsub("/", "\\", f, fixed = TRUE)),
      paste0("/shinymanager/../../", f),
      paste0("/shared/../", f))
  }
  paths <- c(paths, paste0("/", release_files), paste0("/../", release_files),
             "/viewer/shiny_server.R", "/viewer/auth.R")
  sizes <- stats::setNames(file.size(file.path(app_dir, files)), files)
  sums <- stats::setNames(vapply(file.path(app_dir, files), function(p) unname(tools::md5sum(p)), ""), files)
  out <- lapply(unique(paths), function(p) {
    r <- curl_get(paste0(app$url, p))
    md5 <- if (r$bytes > 0) unname(tools::md5sum(r$file)) else ""
    data.frame(path = p, status = r$status, bytes = r$bytes,
               equals_private_file = md5 %in% sums, stringsAsFactors = FALSE)
  })
  do.call(rbind, out)
}

## ---- one login App: HTTP, pre-login, wrong passwords, login, replay, logout ----
login_app_tests <- function(key, user, password, other_user, other_password, gene, data_terms,
                            spatial = FALSE) {
  a <- apps[[key]]
  app <- bv_start_app(a$app_dir, key, logs)
  on.exit(bv_stop_app(app), add = TRUE)
  if (!identical(app$status, 200L)) {
    record("E00 App starts", key, "HTTP 200", paste("status", app$status, bv_read_text(app$stderr)), "fail")
    return(invisible(NULL))
  }
  ## E01 unauthenticated GET /
  root_page <- curl_get(paste0(app$url, "/"), file.path(evidence, paste0(key, "_root.html")))
  html <- bv_read_text(root_page$file)
  hits <- bv_hits(html, data_terms)
  record("E01 unauthenticated GET / shows only the login form", key,
         "HTTP 200, login form, no dataset content",
         sprintf("HTTP %d, %d bytes, login form %s, Viewer UI %s, data terms found %d of %d",
                 root_page$status, root_page$bytes, grepl("auth-user_pwd", html),
                 grepl("shiny-tab-geneExpression", html), length(hits), length(data_terms)),
         pass_if(root_page$status == 200L && grepl("auth-user_pwd", html) &&
                 !grepl("shiny-tab-geneExpression", html) && !length(hits)),
         paste0("E_evidence/", key, "_root.html"))
  ## E02 direct URLs and path traversal to every private file
  probes <- probe_paths(app, a$app_dir, html)
  pf <- paste0("E_evidence/", key, "_http_probes.csv")
  utils::write.csv(probes, file.path(bv_root, "results", pf), row.names = FALSE)
  leaked <- probes[probes$equals_private_file | probes$status == 200L, , drop = FALSE]
  record("E02 private files by direct URL and path traversal (unauthenticated)", key,
         "no private file is served (CRB, sidecars, images, credentials, viewer-auth.env, config)",
         sprintf("%d requests over %d private files: status %s; responses equal to a private file: %d",
                 nrow(probes), length(private_files(a$app_dir)),
                 paste(names(table(probes$status)), table(probes$status), sep = " x", collapse = ", "),
                 sum(probes$equals_private_file)),
         pass_if(!nrow(leaked)), pf)

  ## Browser: pre-login
  p <- bv_browser(key)
  on.exit(bv_close(p), add = TRUE)
  p$log$phase <- "prelogin"
  bv_goto(p, app$url)
  bv_wait_js(p, paste(bv_login_form, "&&", bv_socket_open), 30)
  pre_token <- bv_js(p, "Shiny.shinyapp.config.sessionId")
  ## Inputs a client could send before login: Viewer page, a gene, a selection.
  bv_js(p, paste0(
    "(function(){Shiny.setInputValue('sidebar','geneExpression');",
    "Shiny.setInputValue('expression_genes_input',", jsonlite::toJSON(gene), ");",
    "Shiny.setInputValue('coordviews_selection',{cells:", jsonlite::toJSON(utils::head(barcodes, 3)), "});",
    "Shiny.setInputValue('.shinymanager_timeout', 1);return true;})()"))
  bv_idle(3)
  ## A registered image or gene list URL guessed with the pre-login session token.
  guesses <- c(
    sprintf("/session/%s/dataobj/cerebro-gene-choices-1", pre_token),
    if (spatial) sprintf("/session/%s/dataobj/cerebro-image-%s", pre_token,
                         unname(tools::md5sum(visium_png))))
  guess_status <- vapply(guesses, function(g) curl_get(paste0(app$url, g))$status, 1L)
  pre <- bv_frames_text(p, "prelogin", dir = "in")
  hits <- bv_hits(pre, data_terms)
  writeLines(pre, file.path(evidence, paste0(key, "_frames_prelogin.txt")))
  record("E03 nothing of the dataset reaches the browser before login", key,
         "no expression, metadata, barcode or gene in websocket messages; injected inputs ignored; dataobj URLs 404",
         sprintf("%d frames received (%d bytes); data terms found %d of %d; dataobj guesses with the pre-login session token: %s",
                 length(pre), sum(nchar(pre)), length(hits), length(data_terms),
                 paste(guess_status, collapse = "/")),
         pass_if(!length(hits) && all(guess_status != 200L)),
         paste0("E_evidence/", key, "_frames_prelogin.txt"))

  ## E04-E07 failed logins
  for (case in list(
    list("E04 wrong password", user, "not-the-password-1"),
    list("E05 empty password", user, ""),
    list("E06 empty username", "", password),
    list("E07 SQL-like username", "' OR '1'='1", "' OR '1'='1"),
    list("E07b valid password of another account", user, other_password)
  )) {
    p$log$phase <- case[[1]]
    t0 <- Sys.time()
    state <- bv_login(p, case[[2]], case[[3]], timeout = 20)
    fr <- bv_frames_text(p, case[[1]], dir = "in")
    hits <- bv_hits(fr, data_terms)
    record(case[[1]], key, "rejected with the provider's error, no data sent",
           sprintf("result %s after %.1f s; data terms in %d frames: %d", state,
                   as.numeric(difftime(Sys.time(), t0, units = "secs")), length(fr), length(hits)),
           pass_if(identical(state, "error") && !length(hits)))
  }
  ## E08 repeated failures, then the right password
  p$log$phase <- "burst"
  t0 <- Sys.time()
  states <- vapply(seq_len(25), function(i) bv_login(p, user, paste0("wrong-", i, "-xyz"), timeout = 20), "")
  burst_s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  ## the right password straight after the failures, then after the wait
  ## the Viewer announces (30 s from the fifth failure of this client)
  during <- bv_login(p, user, password, timeout = 20)
  waited <- 0
  state <- during
  if (!identical(during, "app")) {
    t1 <- Sys.time()
    bv_idle(31)
    p$log$phase <- "login"
    state <- bv_login(p, user, password)
    waited <- as.numeric(difftime(Sys.time(), t1, units = "secs"))
  }
  p$log$phase <- "login"
  record("E08 lockout or rate limit after repeated failures", key,
         "repeated failures are throttled or the account is locked",
         sprintf("25 wrong passwords rejected (%s) in %.1f s; the right password straight after: %s; after waiting %.0f s: %s",
                 paste(names(table(states)), table(states), collapse = ", "), burst_s, during, waited, state),
         pass_if(identical(during, "error") && identical(state, "app")))
  ## E09 positive control: after login the dataset does reach the browser
  shown <- bv_show_gene(p, gene)
  if (spatial) {
    bv_js(p, "document.querySelector('a[href=\"#shiny-tab-spatial\"]') && document.querySelector('a[href=\"#shiny-tab-spatial\"]').click()")
    bv_wait_js(p, "performance.getEntriesByType('resource').some(function(e){return e.name.indexOf('cerebro-image-')>=0;})", 60)
    bv_idle(2)
  }
  post <- bv_frames_text(p, "login", dir = "in")
  hits <- bv_hits(post, data_terms)
  token_doc <- grep("token=", p$log$documents, value = TRUE)
  token <- if (length(token_doc)) sub(".*token=%22([0-9a-f]+)%22.*", "\\1", token_doc[[1]]) else NA_character_
  record("E09 positive control: right password opens the Viewer and data reaches the browser", key,
         "Viewer UI, gene shown, data terms detected in frames",
         sprintf("login %s, gene %s shown %s, data terms found %d of %d, provider token in URL: %s",
                 state, gene, shown, length(hits), length(data_terms), !is.na(token)),
         pass_if(identical(state, "app") && shown && length(hits) > 0))
  data_urls <- unique(grep("/session/[0-9a-f]+/dataobj/|/cerebro-[a-z-]+-[0-9a-f]+-[0-9]+/",
                           p$log$requests, value = TRUE))
  writeLines(data_urls, file.path(evidence, paste0(key, "_data_urls.txt")))
  ## E10 data URLs are bearer URLs while the session lives
  live <- vapply(data_urls, function(u) curl_get(u)$status, 1L)
  record("E10 session data URLs fetched by another client (no cookies) while the session is open", key,
         "unguessable per-session URLs; reachable only with the URL",
         sprintf("%d data URLs (%s); status from curl: %s", length(data_urls),
                 paste(unique(sub(".*/(dataobj/[a-z-]+|cerebro-[a-z-]+)-?.*", "\\1", data_urls)), collapse = ", "),
                 paste(names(table(live)), table(live), sep = " x", collapse = ", ")),
         "info", paste0("E_evidence/", key, "_data_urls.txt"))
  ## E11 provider token replay
  replay_curl <- if (is.na(token)) NA else {
    r <- curl_get(sprintf("%s/?token=%%22%s%%22", app$url, token))
    grepl("shiny-tab-geneExpression", bv_read_text(r$file))
  }
  q <- bv_browser(paste0(key, "-replay"))
  q$log$phase <- "replay"
  bv_goto(q, sprintf("%s/?token=%%22%s%%22&language=%%22en%%22", app$url, token))
  replay_state <- if (bv_wait_js(q, paste(bv_viewer_ui, "&&", bv_socket_open), 20)) "app" else
    if (bv_wait_js(q, bv_login_form, 5)) "login form" else "neither"
  replay_shown <- identical(replay_state, "app") && bv_show_gene(q, gene, timeout = 30)
  rfr <- bv_frames_text(q, "replay", dir = "in")
  rhits <- bv_hits(rfr, data_terms)
  bv_close(q)
  record("E11 replay of the login token from another client while the session is open", key,
         "token not accepted by a second client",
         sprintf("curl GET /?token=<token>: Viewer UI %s; new browser with the token URL: %s, gene shown %s, data terms in its frames %d",
                 replay_curl, replay_state, replay_shown, length(rhits)),
         pass_if(!isTRUE(replay_curl) && !identical(replay_state, "app") && !length(rhits)))
  ## E12 logout
  p$log$phase <- "logout"
  bv_js(p, "document.getElementById('.shinymanager_logout').click()")
  form_back <- bv_wait_js(p, paste(bv_login_form, "&&", bv_socket_open), 30)
  bv_idle(2)
  after <- vapply(data_urls, function(u) curl_get(u)$status, 1L)
  lfr <- bv_frames_text(p, "logout", dir = "in")
  lhits <- bv_hits(lfr, data_terms)
  replay_after <- if (is.na(token)) NA else {
    r <- curl_get(sprintf("%s/?token=%%22%s%%22", app$url, token))
    grepl("shiny-tab-geneExpression", bv_read_text(r$file))
  }
  ## a message for the old session after logout
  bv_js(p, paste0("Shiny.setInputValue('expression_genes_input',", jsonlite::toJSON(gene), ");true"))
  bv_idle(2)
  lfr2 <- bv_frames_text(p, "logout", dir = "in")
  record("E12 logout ends the session and stops data outputs", key,
         "login form back; session data URLs 404; token no longer valid; no data after logout",
         sprintf("login form back %s; data URLs after logout: %s; token replay shows Viewer %s; data terms in frames after logout %d (also after an injected gene input: %d)",
                 form_back, paste(names(table(after)), table(after), sep = " x", collapse = ", "),
                 replay_after, length(lhits), length(bv_hits(lfr2, data_terms))),
         pass_if(form_back && all(after != 200L) && !isTRUE(replay_after) &&
                 !length(lhits) && !length(bv_hits(lfr2, data_terms))))
  list(token = token, app_url = app$url, stdout = app$stdout, stderr = app$stderr)
}

v <- login_app_tests("visium_login", "alice", pw$alice, "bob", pw$bob, "Ttr", terms, spatial = TRUE)
pb <- login_app_tests("pbmc_login", "carol", pw$carol, "alice", pw$alice, "CD3E", pbmc_terms)

## ---- E13 inactivity timeout (copy with a 1-minute timeout) --------------------
timeout_app_dir <- file.path(root, "visium_login_timeout1", "cerebro_app")
unlink(dirname(timeout_app_dir), recursive = TRUE)
dir.create(dirname(timeout_app_dir), recursive = TRUE)
file.copy(apps$visium_login$app_dir, dirname(timeout_app_dir), recursive = TRUE, copy.mode = TRUE)
cfg <- readRDS(file.path(timeout_app_dir, "cerebro_config.rds"))
cfg$.viewer_auth$timeout_minutes <- 1L
saveRDS(cfg, file.path(timeout_app_dir, "cerebro_config.rds"))
local({
  app <- bv_start_app(timeout_app_dir, "visium_timeout1", logs)
  on.exit(bv_stop_app(app), add = TRUE)
  p <- bv_browser("timeout")
  on.exit(bv_close(p), add = TRUE)
  bv_goto(p, app$url)
  state <- bv_login(p, "alice", pw$alice)
  shown <- bv_show_gene(p, "Ttr")
  urls <- unique(grep("/session/[0-9a-f]+/dataobj/", p$log$requests, value = TRUE))
  t0 <- Sys.time()
  p$log$phase <- "idle"
  back <- FALSE
  while (as.numeric(difftime(Sys.time(), t0, units = "secs")) < 150) {
    if (isTRUE(tryCatch(bv_js(p, bv_login_form), error = function(e) FALSE))) { back <- TRUE; break }
    bv_idle(2)
  }
  waited <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  after <- vapply(urls, function(u) curl_get(u)$status, 1L)
  record("E13 inactivity timeout ends the session", "visium_login (copy, timeout 1 min)",
         "after 1 min without activity the login form returns and session URLs 404 (the Builder sets 15 min)",
         sprintf("login %s, gene shown %s; login form back after %.0f s idle: %s; data URLs then: %s",
                 state, shown, waited, back, paste(names(table(after)), table(after), sep = " x", collapse = ", ")),
         pass_if(back && waited >= 55 && all(after != 200L)))
})

## ---- E14 two concurrent sessions ---------------------------------------------
local({
  app <- bv_start_app(apps$visium_login$app_dir, "visium_concurrent", logs)
  on.exit(bv_stop_app(app), add = TRUE)
  a <- bv_browser("alice"); b <- bv_browser("bob")
  on.exit({ bv_close(a); bv_close(b) }, add = TRUE)
  bv_goto(a, app$url); bv_goto(b, app$url)
  sa <- bv_login(a, "alice", pw$alice); sb <- bv_login(b, "bob", pw$bob)
  ## one session after the other; a second attempt if the first page was slow
  ## Headless Chrome pauses animation frames in a background tab: bring each
  ## page to the front for its own steps.
  a$b$Page$bringToFront()
  ga <- bv_show_gene(a, "Ttr") || bv_show_gene(a, "Ttr")
  b$b$Page$bringToFront()
  gb <- bv_show_gene(b, "Mbp") || bv_show_gene(b, "Mbp")
  host <- "document.getElementById('expression_projection_cell_view_host').innerText"
  ta <- bv_js(a, host); tb <- bv_js(b, host)
  ## Linked views: a selection in A must not appear in B.
  for (pg in list(a, b)) {
    pg$b$Page$bringToFront()
    bv_js(pg, "document.querySelector('a[href=\"#shiny-tab-coordinated_views\"]').click()")
    bv_wait_js(pg, "!!(window.cerebroLinkedViewsState && cerebroLinkedViewsState.ready())", 90)
  }
  ## Select the first 25 cells in A through the Linked views workspace API.
  a$b$Page$bringToFront()
  bv_js(a, "(function(){var c=cerebroLinkedViewsState.capture();var idx=[];for(var i=0;i<25;i++)idx.push(i);cerebroLinkedViewsState.apply(c,null,idx);return true;})()")
  bv_idle(3)
  sel_a <- bv_js(a, "cerebroLinkedViewsState.summary().selectedCells")
  sel_b <- bv_js(b, "cerebroLinkedViewsState.summary().selectedCells")
  tokens <- c(bv_js(a, "Shiny.shinyapp.config.sessionId"), bv_js(b, "Shiny.shinyapp.config.sessionId"))
  a_urls <- unique(grep("/session/", a$log$requests, value = TRUE))
  b_hits_a <- sum(grepl(tokens[[1]], b$log$requests, fixed = TRUE))
  record("E14 two concurrent sessions keep their own state", "visium_login",
         "each session shows its own gene and selection; no URL of one session used by the other",
         sprintf("logins %s/%s; gene views ready A %s, B %s; A shows Ttr %s (Mbp %s), B shows Mbp %s (Ttr %s); Linked views selection A %s cells, B %s; requests of B with A's session token: %d",
                 sa, sb, ga, gb, grepl("Ttr", ta), grepl("Mbp", ta), grepl("Mbp", tb), grepl("Ttr", tb),
                 sel_a, sel_b, b_hits_a),
         pass_if(identical(sa, "app") && identical(sb, "app") && grepl("Ttr", ta) && !grepl("Mbp", ta) &&
                 grepl("Mbp", tb) && !grepl("Ttr", tb) && identical(as.integer(sel_a), 25L) &&
                 identical(as.integer(sel_b), 0L) && b_hits_a == 0))
})

## ---- E15 accounts and tokens of another App ------------------------------------
local({
  app <- bv_start_app(apps$visium_login$app_dir, "visium_crossapp", logs)
  on.exit(bv_stop_app(app), add = TRUE)
  p <- bv_browser("crossapp")
  on.exit(bv_close(p), add = TRUE)
  bv_goto(p, app$url)
  carol <- bv_login(p, "carol", pw$carol, timeout = 20)
  alice_pbmc <- bv_login(p, "alice", pw$alice_pbmc, timeout = 20)
  r <- curl_get(sprintf("%s/?token=%%22%s%%22", app$url, pb$token))
  record("E15 an account or token of another App (PBMC) on the Visium App", "visium_login",
         "rejected: each App has its own credentials database and tokens",
         sprintf("carol (PBMC only): %s; alice with her PBMC password: %s; PBMC token on Visium shows Viewer: %s",
                 carol, alice_pbmc, grepl("shiny-tab-geneExpression", bv_read_text(r$file))),
         pass_if(identical(carol, "error") && identical(alice_pbmc, "error") &&
                 !grepl("shiny-tab-geneExpression", bv_read_text(r$file))))
})

## ---- E16-E19 credentials at rest, passphrase, plaintext, logs -----------------
app_dir <- apps$visium_login$app_dir
db <- file.path(app_dir, "private-data", "auth", "credentials.sqlite")
env_file <- file.path(app_dir, "viewer-auth.env")
passphrase <- sub("^CEREBRO_AUTH_PASSPHRASE=", "", readLines(env_file))
raw_db <- readBin(db, "raw", file.size(db))
raw_text <- rawToChar(raw_db[raw_db != as.raw(0)])
plain <- c("alice", "bob", pw$alice, pw$bob)
in_db <- plain[vapply(plain, function(x) grepl(x, raw_text, fixed = TRUE), logical(1))]
con <- DBI::dbConnect(RSQLite::SQLite(), db)
tables <- DBI::dbListTables(con)
cred_raw <- DBI::dbReadTable(con, "credentials")
DBI::dbDisconnect(con)
dec <- shinymanager::read_db_decrypt(db, name = "credentials", passphrase = passphrase)
wrong <- tryCatch({ shinymanager::read_db_decrypt(db, name = "credentials", passphrase = strrep("0", 64)); "decrypted" },
                  error = function(e) "error")
record("E16 credentials database at rest", "visium_login",
       "tables encrypted; no username or password in the file; passwords hashed",
       sprintf("tables %s; credentials table stored as %s; usernames/passwords found in raw bytes: %s; with a wrong key: %s; decrypted with the App key: users %s, is_hashed_password %s, stored password equals plaintext %s",
               paste(tables, collapse = ","), paste(class(cred_raw[[1]]), collapse = "/"),
               if (length(in_db)) paste(in_db, collapse = ",") else "none", wrong,
               paste(dec$user, collapse = ","), paste(dec$is_hashed_password, collapse = ","),
               any(dec$password %in% c(pw$alice, pw$bob))),
       pass_if(!length(in_db) && identical(wrong, "error") && all(dec$is_hashed_password %in% TRUE) &&
               !any(dec$password %in% c(pw$alice, pw$bob))))
all_files <- function(dir) list.files(dir, recursive = TRUE, all.files = TRUE, full.names = TRUE)
grep_files <- function(files, needle) {
  files[vapply(files, function(f) {
    if (!file.exists(f) || dir.exists(f) || file.size(f) == 0) return(FALSE)
    x <- readBin(f, "raw", file.size(f))
    length(grepRaw(needle, x, fixed = TRUE)) > 0
  }, logical(1))]
}
release_files <- all_files(apps$visium_login$release)
work_files <- all_files(apps$visium_login$work)
key_hits <- grep_files(c(release_files, work_files), passphrase)
mode <- sprintf("%o", file.info(env_file)$mode)
record("E17 the database key is not in the App files", "visium_login",
       "key supplied outside the App (environment), not stored next to the database",
       sprintf("key stored in %s (mode %s) in the App root, next to private-data/auth/credentials.sqlite (mode %s); files containing the key: %s",
               basename(env_file), mode, sprintf("%o", file.info(db)$mode),
               paste(sub(paste0(bv_data, "/"), "", key_hits, fixed = TRUE), collapse = ", ")),
       pass_if(!length(key_hits)))
pw_hits <- grep_files(c(release_files, work_files, all_files(file.path(root, "pbmc_login"))),
                      pw$alice)
pw_hits <- c(pw_hits, unlist(lapply(c(pw$bob, pw$carol, pw$alice_pbmc), function(x)
  grep_files(c(release_files, all_files(file.path(root, "pbmc_login"))), x))))
record("E18 no plaintext password in App, release or Builder work files", "visium_login, pbmc_login",
       "no plaintext password in any file", sprintf("files with a plaintext password: %s",
                                                    if (length(pw_hits)) paste(basename(pw_hits), collapse = ", ") else "none"),
       pass_if(!length(pw_hits)))
log_files <- list.files(logs, full.names = TRUE)
secrets <- c(unlist(pw), passphrase, v$token, pb$token)
log_hits <- unlist(lapply(secrets, function(s) basename(grep_files(log_files, s))))
record("E19 logs do not print credentials", "all",
       "no password, key or login token in the build log or the App stdout/stderr",
       sprintf("%d log files (build, every App run); files with a secret: %s", length(log_files),
               if (length(log_hits)) paste(unique(log_hits), collapse = ", ") else "none"),
       pass_if(!length(log_hits)))

## ---- E20-E24 startup checks on copies of the login App ------------------------
start_case <- function(test, mutate, expected_start, env = character()) {
  dir <- file.path(root, "startup", gsub("[^A-Za-z0-9]+", "_", test), "cerebro_app")
  unlink(dirname(dir), recursive = TRUE)
  dir.create(dirname(dir), recursive = TRUE)
  file.copy(apps$visium_login$app_dir, dirname(dir), recursive = TRUE, copy.mode = TRUE)
  mutate(dir)
  label <- paste0("startup_", substr(test, 1, 3))
  app <- bv_start_app(dir, label, logs, env = env)
  ok_http <- identical(app$status, 200L)
  login <- NA
  if (ok_http) {
    p <- bv_browser(label); bv_goto(p, app$url)
    login <- bv_login(p, "alice", pw$alice, timeout = 30); bv_close(p)
  }
  bv_stop_app(app)
  err <- bv_read_text(app$stderr)
  msg <- regmatches(err, regexpr("Error[^\n]*(\n[^\n]+)?", err))
  observed <- sprintf("HTTP %s, login %s; error: %s", app$status, login,
                      if (length(msg)) bv_one_line(msg, 300) else "none")
  ok <- if (expected_start) ok_http && identical(login, "app") else !ok_http && length(msg) > 0
  record(test, "visium_login (copy)", if (expected_start) "starts, login works" else
    "refuses to start with an explicit error", observed, pass_if(ok))
}
start_case("E20 viewer-auth.env readable by others (0644)",
           function(d) Sys.chmod(file.path(d, "viewer-auth.env"), "0644", use_umask = FALSE), FALSE)
start_case("E21 wrong database key in viewer-auth.env",
           function(d) writeLines(paste0("CEREBRO_AUTH_PASSPHRASE=", strrep("ab", 32)), file.path(d, "viewer-auth.env")), FALSE)
start_case("E22 viewer-auth.env removed, no key in the environment",
           function(d) unlink(file.path(d, "viewer-auth.env")), FALSE)
start_case("E23 viewer-auth.env replaced by a symbolic link",
           function(d) {
             f <- file.path(d, "viewer-auth.env"); tgt <- file.path(dirname(d), "key.env")
             file.rename(f, tgt); file.symlink(tgt, f)
           }, FALSE)
start_case("E24 viewer-auth.env removed, key given in the process environment",
           function(d) unlink(file.path(d, "viewer-auth.env")), TRUE,
           env = c(CEREBRO_AUTH_PASSPHRASE = passphrase))
start_case("E24b credentials database removed",
           function(d) unlink(file.path(d, "private-data", "auth", "credentials.sqlite")), FALSE)

## ---- E25 App without login ---------------------------------------------------
local({
  a <- apps$visium_public
  app <- bv_start_app(a$app_dir, "visium_public", logs)
  on.exit(bv_stop_app(app), add = TRUE)
  r <- curl_get(paste0(app$url, "/"))
  html <- bv_read_text(r$file)
  probes <- probe_paths(app, a$app_dir, html)
  pf <- "E_evidence/visium_public_http_probes.csv"
  utils::write.csv(probes, file.path(bv_root, "results", pf), row.names = FALSE)
  p <- bv_browser("public"); on.exit(bv_close(p), add = TRUE)
  bv_goto(p, app$url)
  shown <- bv_show_gene(p, "Ttr")
  record("E25 App without login", "visium_public",
         "anyone who reaches the server sees the Viewer (by design); private files still not served by URL",
         sprintf("GET / Viewer UI %s; Viewer opens without login and shows a gene %s; %d private-file requests, responses equal to a private file %d, HTTP 200 %d; viewer-auth.env and credentials absent: %s",
                 grepl("shiny-tab-geneExpression", html), shown, nrow(probes),
                 sum(probes$equals_private_file), sum(probes$status == 200L),
                 !file.exists(file.path(a$app_dir, "viewer-auth.env")) &&
                   !dir.exists(file.path(a$app_dir, "private-data", "auth"))),
         pass_if(shown && !any(probes$equals_private_file) && !any(probes$status == 200L)), pf)
})

out <- do.call(rbind, rows)
utils::write.csv(out, file.path(bv_root, "results", Sys.getenv("E_OUT", "E_security.csv")), row.names = FALSE)
print(table(out$result))
