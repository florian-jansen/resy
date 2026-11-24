# A parsed expert system is kept as an RDS file in RESY's user cache directory,
# so that later loads of the same file restore the object instead of parsing
# the text again. An entry belongs to one file in one state (path, size and
# modification time), to the scheme and version it was loaded as, and to the
# installed build of RESY that parsed it; when any of these changes the entry
# is not used, and writing the new entry removes the older ones of that file.
# Without an installed build (a development load) nothing is cached.
# `options(RESY.cache = FALSE)` turns the cache off; `options(RESY.cache_dir =)`
# moves it.

.resy_cache_state <- new.env(parent = emptyenv())

# Directory of the cache, or NULL when caching is off.
.resy_cache_dir <- function() {
  if (isFALSE(getOption("RESY.cache", TRUE))) return(NULL)
  getOption("RESY.cache_dir", tools::R_user_dir("RESY", "cache"))
}

# The installed build of RESY, or NA for a development load.
.resy_build_stamp <- function() {
  if (is.null(.resy_cache_state$build)) {
    built <- suppressWarnings(utils::packageDescription("RESY", fields = "Built"))
    .resy_cache_state$build <- if (is.character(built)) built else NA_character_
  }
  .resy_cache_state$build
}

.resy_text_md5 <- function(x) {
  tmp <- tempfile()
  on.exit(unlink(tmp))
  writeLines(x, tmp, useBytes = TRUE)
  unname(tools::md5sum(tmp))
}

# Cache file of `path` loaded as `scheme`/`version`, or NULL when caching is off.
# The name starts with a hash of the path alone, which groups the entries of
# one file so that outdated ones can be found and removed.
.resy_cache_file <- function(path, scheme = NULL, version = NULL) {
  dir <- .resy_cache_dir()
  build <- .resy_build_stamp()
  if (is.null(dir) || is.na(build)) return(NULL)
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  info <- file.info(path)
  key <- c(path, info$size, format(info$mtime, "%Y-%m-%d %H:%M:%OS6"),
           scheme %||% "", version %||% "", build)
  file.path(dir, paste0(substr(.resy_text_md5(path), 1L, 16L), "_",
                        .resy_text_md5(key), ".rds"))
}

# The cached object, or NULL when there is none or it cannot be read.
.resy_cache_read <- function(file) {
  if (is.null(file) || !file.exists(file)) return(NULL)
  tryCatch(readRDS(file), error = function(e) NULL)
}

# Store `parsed`, the system read from `path`, replacing the older entries of
# the same file and the entries of files that no longer exist. Each file's
# entries share a `<path hash>.path` record holding the file's path. A failure
# to write leaves the cache as it was and the load unaffected.
.resy_cache_write <- function(file, parsed, path) {
  if (is.null(file)) return(invisible(FALSE))
  dir <- dirname(file)
  group <- substr(basename(file), 1L, 16L)
  ok <- tryCatch({
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    .resy_cache_prune(dir)
    old <- list.files(dir, pattern = paste0("^", group, "_"), full.names = TRUE)
    unlink(setdiff(old, file))
    writeLines(enc2utf8(normalizePath(path, winslash = "/")),
               file.path(dir, paste0(group, ".path")), useBytes = TRUE)
    tmp <- tempfile(tmpdir = dir, fileext = ".tmp")
    # Fastest gzip level: reading is as quick as with xz, writing 30 times quicker.
    con <- gzfile(tmp, "wb", compression = 1L)
    saveRDS(parsed, con)
    close(con)
    file.rename(tmp, file)
  }, error = function(e) FALSE, warning = function(w) FALSE)
  invisible(isTRUE(ok))
}

# Remove the entries of files that no longer exist, with their path records,
# and entries without a record.
.resy_cache_prune <- function(dir) {
  records <- list.files(dir, pattern = "\\.path$", full.names = TRUE)
  source <- vapply(records, function(f)
    c(readLines(f, n = 1L, warn = FALSE, encoding = "UTF-8"), "")[1L], character(1))
  unlink(records[!file.exists(source)])
  live <- sub("\\.path$", "", basename(records[file.exists(source)]))
  entries <- list.files(dir, pattern = "\\.rds$", full.names = TRUE)
  unlink(entries[!substr(basename(entries), 1L, 16L) %in% live])
}
