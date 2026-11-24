# Builds the RESY archive and compressed WORKERFS library images used by
# the RESY App and Maker, with their package dependencies resolved at build time.
#
# RESY is pure R, so a native install is valid in webR once its build metadata
# names the webR platform. fastmatch is taken as the webR binary from
# repo.r-wasm.org. Its src/dummy.c declares R_registerRoutines() and
# R_useDynamicSymbols() as `void f(void)`, so the wasm module imports them with
# type () -> void, which does not match R's exports, and dyn.load() fails with a
# LinkError. dummy() is never called, so the two import names are replaced by
# names of the same length that R does not export; webR then links them to a
# stub and fmatch() itself is unchanged.
#
# Usage: Rscript pkgdown/build_webr_bundle.R [resy_repo] [git_ref|WORKTREE] [webr_r_version]
# Run it from an R whose libraries hold RESY's dependencies (add --vanilla when
# they are in the user library rather than the renv project library). The R
# version must match the webR release imported in pkgdown/assets/webr/resy_core.js.

args <- commandArgs(trailingOnly = TRUE)
resy_repo <- if (length(args) >= 1) args[1] else "."
git_ref <- if (length(args) >= 2) args[2] else "HEAD"
webr_r <- if (length(args) >= 3) args[3] else "4.6.0"

here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))),
                      winslash = "/")
site <- file.path(here, "assets", "webr")
work <- file.path(tempdir(), "resy-bundle")
unlink(work, recursive = TRUE)
lib <- file.path(work, "lib")
dir.create(lib, recursive = TRUE)

if (identical(git_ref, "WORKTREE")) {
  commit <- paste0(system2("git", c("-C", shQuote(resy_repo), "rev-parse", "--short", "HEAD"), stdout = TRUE), "-worktree")
  source_dir <- file.path(work, "RESY")
  dir.create(source_dir)
  inputs <- c("DESCRIPTION", "NAMESPACE", "LICENSE", "R", "data", "inst", "man")
  inputs <- file.path(resy_repo, inputs)
  stopifnot(all(file.copy(inputs[file.exists(inputs)], source_dir, recursive = TRUE)))
} else {
  commit <- system2("git", c("-C", shQuote(resy_repo), "rev-parse", "--short", git_ref), stdout = TRUE)
  src_tar <- file.path(work, "resy-src.tar")
  status <- system2("git", c("-C", shQuote(resy_repo), "archive", "--format=tar", "--prefix=RESY/",
                             "-o", shQuote(src_tar), git_ref))
  stopifnot(status == 0)
  utils::untar(src_tar, exdir = work)
}
# The install sees the libraries of this R session and no user profile, so the
# repository's .Rprofile (renv) does not choose a different library for it.
profile <- file.path(work, "Rprofile")
invisible(file.create(profile))
old_env <- Sys.getenv(c("R_PROFILE_USER", "R_LIBS"), unset = NA)
Sys.setenv(R_PROFILE_USER = profile, R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
install_log <- suppressWarnings(system2(
  file.path(R.home("bin"), "R"),
  c("CMD", "INSTALL", "--no-test-load", "--no-docs", "--no-multiarch",
    paste0("--library=", shQuote(lib)), shQuote(file.path(work, "RESY"))),
  stdout = TRUE, stderr = TRUE
))
for (v in names(old_env)) if (is.na(old_env[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old_env[v]))
if (!is.null(attr(install_log, "status"))) {
  stop("R CMD INSTALL of RESY failed (library paths: ", paste(.libPaths(), collapse = ", "), "):\n",
       paste(utils::tail(install_log, 15), collapse = "\n"), call. = FALSE)
}

meta <- file.path(lib, "RESY", "Meta", "package.rds")
p <- readRDS(meta)
built <- sprintf("R %s; ; %s; unix", webr_r, format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"))
p$Built$R <- package_version(webr_r)
p$Built$Platform <- ""
p$Built$OStype <- "unix"
p$DESCRIPTION[["Built"]] <- built
saveRDS(p, meta)
desc <- file.path(lib, "RESY", "DESCRIPTION")
d <- readLines(desc)
d[startsWith(d, "Built:")] <- paste("Built:", built)
writeLines(d, desc)

# fastmatch webR binary with the two dummy imports renamed.
minor <- sub("^(\\d+\\.\\d+).*", "\\1", webr_r)
repo <- sprintf("https://repo.r-wasm.org/bin/emscripten/contrib/%s", minor)
pkgs <- read.dcf(url(file.path(repo, "PACKAGES")))
fm_version <- pkgs[pkgs[, "Package"] == "fastmatch", "Version"]
fm_tgz <- file.path(work, "fastmatch.tgz")
utils::download.file(sprintf("%s/fastmatch_%s.tgz", repo, fm_version), fm_tgz, mode = "wb", quiet = TRUE)
utils::untar(fm_tgz, exdir = lib)
so <- file.path(lib, "fastmatch", "libs", "fastmatch.so")
bin <- readBin(so, "raw", file.size(so))
rename <- c(R_registerRoutines = "fm_unused_dummy_01", R_useDynamicSymbols = "fm_unused_dummy_002")
for (old in names(rename)) {
  from <- charToRaw(old)
  to <- charToRaw(rename[[old]])
  stopifnot(length(from) == length(to))
  starts <- which(bin == from[1])
  hits <- starts[vapply(starts, function(i) identical(bin[i:(i + length(from) - 1L)], from), logical(1))]
  if (length(hits) != 1L) stop("expected one import named ", old, " in fastmatch.so, found ", length(hits))
  bin[hits:(hits + length(to) - 1L)] <- to
}
writeBin(bin, so)

dir.create(site, recursive = TRUE, showWarnings = FALSE)
out <- file.path(site, "resylib.tar.gz")
old_wd <- setwd(lib)
utils::tar(out, files = c("RESY", "fastmatch"), compression = "gzip", tar = "internal")
setwd(old_wd)

resy_version <- read.dcf(desc, fields = "Version")[1, 1]

# Package dependencies are resolved at build time against the webR repository.
rownames(pkgs) <- pkgs[, "Package"]
dependencies <- function(roots) {
  unique(c(roots, unlist(tools::package_dependencies(roots, db = pkgs,
    which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE), use.names = FALSE)))
}
core <- dependencies(c("data.table", "jsonlite", "rlang", "lifecycle"))
groups <- list(core = core, tables = setdiff(dependencies("tibble"), core))
for (group in names(groups)) {
  target <- file.path(work, group)
  dir.create(target)
  for (pkg in intersect(groups[[group]], rownames(pkgs))) {
    archive <- file.path(work, paste0(pkg, ".tgz"))
    utils::download.file(sprintf("%s/%s_%s.tgz", repo, pkg, pkgs[pkg, "Version"]),
                         archive, mode = "wb", quiet = TRUE)
    utils::untar(archive, exdir = target)
  }
}

# WORKERFS addresses each file by its byte range in an immutable library image.
library_image <- function(directory, name, include = function(x) rep(TRUE, length(x))) {
  files <- sort(list.files(directory, recursive = TRUE, full.names = FALSE,
                           all.files = TRUE, no.. = TRUE))
  files <- files[!file.info(file.path(directory, files))$isdir]
  files <- files[include(files)]
  image <- file.path(work, paste0(name, ".data.gz"))
  con <- gzfile(image, "wb", compression = 9)
  entries <- vector("list", length(files))
  offset <- 0
  tryCatch(for (i in seq_along(files)) {
    path <- file.path(directory, files[i])
    size <- file.size(path)
    writeBin(readBin(path, "raw", size), con)
    entries[[i]] <- list(filename = paste0("/", files[i]), start = offset, end = offset + size)
    offset <- offset + size
  }, finally = close(con))
  hash <- unname(tools::md5sum(image))
  filename <- paste0(name, "-", hash, ".data.gz")
  stopifnot(file.copy(image, file.path(site, filename), overwrite = TRUE))
  list(file = filename, bytes = file.size(image),
       metadata = list(files = entries, remote_package_size = offset))
}
# Runtime packages retain their R databases, shared libraries, namespace and
# package metadata. Documentation and build/test inputs are never read here.
runtime_files <- function(files) {
  !grepl("(^|/)(help|html|doc|tests|demo|po|include|shiny)(/|$)", files) &
    !grepl("(^|/)(NEWS[^/]*|INDEX|SHA256|\\.vfs-index.json)$", files) &
    !grepl("/Meta/(hsearch|links|Rd)\\.rds$", files)
}

# Cached example sites are produced by the runtime harmonisation helper.
loadNamespace("fastmatch")
.libPaths(c(lib, .libPaths()))
source(file.path(site, "resy_page.R"))
si <- read.csv(file.path(lib, "RESY", "extdata", "data_example_sites.csv"), check.names = FALSE)
stopifnot(nrow(si) == 200L, !anyDuplicated(si$PlotObservationID))
write.table(si, file.path(work, "sites.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
invisible(resy_page_set_expert("EUNIS"))
input <- .page_read(file.path(work, "sites.tsv"))
warnings <- character()
sites <- withCallingHandlers(.page_sites(input, TRUE, 5000), warning = function(w) {
  warnings <<- c(warnings, conditionMessage(w))
  invokeRestart("muffleWarning")
})
saveRDS(list(input = .page_site_input(input), sites = sites, warnings = warnings,
             coast_dunes = TRUE, coast_buffer = 5000),
        file.path(lib, "RESY", "extdata", "example-sites.rds"), compress = "xz")

gis <- file.path(work, "gis")
dir.create(gis)
file.copy(list.files(file.path(lib, "RESY", "data"), full.names = TRUE), gis)
# A placeholder keeps the read-only package's data mount point present.
file.create(file.path(lib, "RESY", "data", ".mount"))
images <- list(resy = library_image(lib, "resy", function(x)
                 runtime_files(x) & (!startsWith(x, "RESY/data/") | endsWith(x, "/.mount")) &
                   !endsWith(x, "data_example_altitude.tif") &
                   !grepl("^RESY/extdata/esy_synonym_layer", x)),
               core = library_image(file.path(work, "core"), "core", runtime_files),
               tables = library_image(file.path(work, "tables"), "tables", runtime_files),
               gis = library_image(gis, "gis"))
# The EUNIS-ESy releases in the bundle, newest first, for the release menu.
eunis_versions <- sort(list.dirs(file.path(lib, "RESY", "extdata", "classifications", "EUNIS"),
                                 full.names = FALSE, recursive = FALSE), decreasing = TRUE)
writeLines(jsonlite::toJSON(list(resy = resy_version, commit = commit, r = webr_r,
                                 fastmatch = fm_version, eunis_versions = I(eunis_versions),
                                 images = images),
                            auto_unbox = TRUE),
           file.path(site, "bundle.json"))
cat(sprintf("RESY %s (%s), fastmatch %s, for webR R %s -> %s (%.1f MB)\n", resy_version, commit,
            fm_version, webr_r, out, file.size(out) / 1e6))
for (name in names(images)) cat(sprintf("%s library: %s (%.1f MB)\n", name,
                                      images[[name]]$file, images[[name]]$bytes / 1e6))
