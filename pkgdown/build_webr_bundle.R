# Builds pkgdown/assets/webr/resylib.tar.gz for vignettes/articles/app.Rmd: RESY and fastmatch as installed packages that
# webR can put on its library path.
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
# Usage: Rscript --vanilla pkgdown/build_webr_bundle.R [resy_repo] [git_ref] [webr_r_version]
# The R version must match the webR release imported in pkgdown/assets/webr/page.js.

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

# RESY from a git ref, so uncommitted edits in the working tree are left out.
commit <- system2("git", c("-C", shQuote(resy_repo), "rev-parse", "--short", git_ref), stdout = TRUE)
src_tar <- file.path(work, "resy-src.tar")
status <- system2("git", c("-C", shQuote(resy_repo), "archive", "--format=tar", "--prefix=RESY/",
                           "-o", shQuote(src_tar), git_ref))
stopifnot(status == 0)
utils::untar(src_tar, exdir = work)
# The install runs with an empty user profile, so the repository's .Rprofile
# (renv) does not switch it to a project library without RESY's dependencies.
profile <- file.path(work, "Rprofile")
file.create(profile)
Sys.setenv(R_PROFILE_USER = profile)
status <- system2(file.path(R.home("bin"), "R"),
                  c("CMD", "INSTALL", "--no-test-load", "--no-docs", "--no-multiarch",
                    paste0("--library=", shQuote(lib)), shQuote(file.path(work, "RESY"))))
Sys.unsetenv("R_PROFILE_USER")
stopifnot(status == 0)

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
writeLines(jsonlite::toJSON(list(resy = resy_version, commit = commit, r = webr_r,
                                 fastmatch = fm_version), auto_unbox = TRUE),
           file.path(site, "bundle.json"))
cat(sprintf("RESY %s (%s), fastmatch %s, for webR R %s -> %s (%.1f MB)\n", resy_version, commit,
            fm_version, webr_r, out, file.size(out) / 1e6))
