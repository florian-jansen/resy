#' File names an expert system may be stored under
#'
#' Per format, the file names looked for in a version directory, in order of
#' preference. JSON expert files may be xz-compressed; `jsonlite::read_json()`
#' and `file()` read them directly.
#'
#' @keywords internal
#' @noRd
.resy_expert_files <- list(
  json = c("expert.json", "expert.json.xz"),
  txt  = "expert.txt"
)

#' First existing expert file of a format in a version directory
#'
#' @param dir Version directory, e.g. `<root>/EUNIS/2025-10-03`.
#' @param format `"json"` or `"txt"`.
#' @return The file path, or `NA_character_` when none exists.
#' @keywords internal
#' @noRd
.resy_find_expert_file <- function(dir, format = c("json", "txt")) {
  format <- match.arg(format)
  p <- file.path(dir, .resy_expert_files[[format]])
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
