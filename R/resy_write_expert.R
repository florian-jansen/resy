# Serializer for the expert-system `.txt` format. Emits the lines retained by
# resy_read_expert() in source order, joined with the original line terminator,
# so a tree read and written unchanged round-trips byte-identically. This is the
# inverse of resy_read_expert(): the reader keeps every byte of the source, the
# writer re-emits it. Deriving the output from edited structured `entries`
# (rather than the retained lines) is a separate, independently tested path that
# ships with the expert-editing API.

#' Write an expert-system file
#'
#' @description
#' Serialises a \code{resy_expert} tree (as returned by
#' \code{\link{resy_read_expert}}) back to a \code{.txt} file. The round-trip is
#' byte-identical: for any file \code{f},
#' \code{resy_write_expert(resy_read_expert(f), out)} reproduces \code{f}
#' exactly, including line endings and trailing newline.
#'
#' The output reproduces the source the tree was read from. This is the inverse
#' of \code{\link{resy_read_expert}} and keeps the \code{.txt} format the
#' canonical, editable representation an expert system can be shared in.
#'
#' @param x An object of class \code{resy_expert}.
#' @param file Path to write to.
#'
#' @return Invisibly returns \code{file}.
#' @seealso \code{\link{resy_read_expert}} for the inverse operation.
#' @export
#' @examples
#' \dontrun{
#' f <- "/path/to/EUNIS-ESy-2025-10-03.txt"
#' x <- resy_read_expert(f)
#' out <- tempfile(fileext = ".txt")
#' resy_write_expert(x, out)
#' identical(readBin(f, "raw", file.info(f)$size),
#'           readBin(out, "raw", file.info(out)$size))
#' }
resy_write_expert <- function(x, file) {
  if (!inherits(x, "resy_expert")) {
    stop(sprintf(
      "`x` must be a 'resy_expert' object (from resy_read_expert()), got %s.",
      class(x)[1]
    ), call. = FALSE)
  }
  if (!is.character(file) || length(file) != 1L || is.na(file)) {
    stop(sprintf(
      "`file` must be a single file path, got %s of length %d.",
      class(file)[1], length(file)
    ), call. = FALSE)
  }

  line_term <- x$meta$line_terminator %||% "\r\n"
  trailing_newline <- isTRUE(x$meta$trailing_newline)

  out <- x$preamble
  for (sec in x$sections) {
    out <- c(out, sec$header_line, sec$body_lines)
    if (!is.na(sec$end_line)) out <- c(out, sec$end_line)
    out <- c(out, sec$trailing)
  }

  text <- paste(out, collapse = line_term)
  if (trailing_newline) text <- paste0(text, line_term)

  # writeBin on raw UTF-8 bytes preserves the file exactly; writeLines would
  # append a platform-native terminator and re-encode.
  con <- file(file, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(text), con)

  invisible(file)
}
