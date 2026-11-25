# File names an expert system may be stored under
#'
#' Per format, the file names looked for in a version directory, in order of
#' preference. Expert files of either format may be xz-compressed;
#' `jsonlite::read_json()`, `readLines()` and `.resy_read_raw()` read them
#' directly.
#'
#' @keywords internal
#' @noRd
.resy_expert_files <- list(
  json = c("expert.json", "expert.json.xz"),
  txt  = c("expert.txt", "expert.txt.xz")
)

#' First existing expert file of a format in a version directory
#'
#' @param dir Version directory, e.g. `<root>/EUNIS/2025-10-03`.
#' @param format `"json"`, `"txt"`, or `NULL` for either, JSON first (the
#'   order in which [resy_load_expert()] reads them).
#' @return The file path, or `NA_character_` when none exists.
#' @keywords internal
#' @noRd
.resy_find_expert_file <- function(dir, format = NULL) {
  names <- if (is.null(format)) unlist(.resy_expert_files, use.names = FALSE)
           else .resy_expert_files[[match.arg(format, names(.resy_expert_files))]]
  p <- file.path(dir, names)
  p <- p[file.exists(p)]
  if (length(p)) p[1L] else NA_character_
}

#' Whether a path is a JSON expert file, plain or xz-compressed
#'
#' @param path Character vector of file paths.
#' @return Logical vector.
#' @keywords internal
#' @noRd
.resy_is_json <- function(path) grepl("\\.json(\\.xz)?$", path, ignore.case = TRUE)

#' Whether a path is a text expert file, plain or xz-compressed
#'
#' @param path Character vector of file paths.
#' @return Logical vector.
#' @keywords internal
#' @noRd
.resy_is_txt <- function(path) grepl("\\.txt(\\.xz)?$", path, ignore.case = TRUE)

#' Whether a path is xz-compressed, judged by its extension
#'
#' @param path Character vector of file paths.
#' @return Logical vector.
#' @keywords internal
#' @noRd
.resy_is_xz <- function(path) grepl("\\.xz$", path, ignore.case = TRUE)

#' The bytes of a file, decompressed when it is xz-compressed
#'
#' @param path A file path.
#' @return A raw vector.
#' @keywords internal
#' @noRd
.resy_read_raw <- function(path) {
  if (!.resy_is_xz(path))
    return(readBin(path, what = "raw", n = file.info(path)$size))
  con <- xzfile(path, open = "rb")
  on.exit(close(con))
  chunks <- list()
  repeat {
    b <- readBin(con, what = "raw", n = 4194304L)
    if (!length(b)) break
    chunks[[length(chunks) + 1L]] <- b
  }
  unlist(chunks, use.names = FALSE) %||% raw()
}

#' MD5 checksum of the (decompressed) content of a file
#'
#' @param path A file path.
#' @return A 32-character lowercase hex string.
#' @keywords internal
#' @noRd
.resy_content_md5 <- function(path) {
  if (!.resy_is_xz(path)) return(unname(tools::md5sum(path)))
  .resy_raw_md5(.resy_read_raw(path))
}

#' MD5 checksum of bytes already read
#'
#' @param bytes A raw vector.
#' @return A 32-character lowercase hex string.
#' @keywords internal
#' @noRd
.resy_raw_md5 <- function(bytes) {
  tmp <- tempfile()
  on.exit(unlink(tmp))
  writeBin(bytes, tmp)
  unname(tools::md5sum(tmp))
}

#' The lines of a text file held as bytes, read as `readLines()` reads a file
#'
#' @param bytes A raw vector.
#' @return A character vector marked UTF-8.
#' @keywords internal
#' @noRd
.resy_raw_lines <- function(bytes) {
  con <- rawConnection(bytes)
  on.exit(close(con))
  readLines(con, warn = FALSE, encoding = "UTF-8")
}
