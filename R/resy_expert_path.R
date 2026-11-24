#' Get the path to a bundled classification file
#'
#' @description
#' Returns the full path to an expert-system file bundled with the package.
#'
#' @param scheme Classification scheme, e.g. `"EUNIS"`.
#' @param version Version identifier, e.g. `"2025-10-03"`.
#' @param format `NULL` (default) for the file the classification is stored
#'   in, the one [resy_load_expert()] reads (JSON when both exist); `"json"` or
#'   `"txt"` for that format only.
#' @param mustWork Logical; if `TRUE` (default) an error is thrown when the
#'   file does not exist.
#' @return A file path string, or `NA` (invisibly) when `mustWork = FALSE` and
#'   the file is absent.
#' @examples
#' # Path to the bundled EUNIS expert system (the published .txt, compressed).
#' resy_expert_path("EUNIS", "2025-10-03")
#'
#' # Probe without erroring when a scheme/version is not installed.
#' resy_expert_path("EUNIS", "1900-01-01", mustWork = FALSE)
#' @export
resy_expert_path <- function(scheme,
                             version,
                             format   = NULL,
                             mustWork = TRUE) {
  if (!is.null(format)) format <- match.arg(format, c("json", "txt"))

  base <- system.file("extdata", "classifications", scheme, version, package = "RESY")
  p    <- if (nzchar(base)) .resy_find_expert_file(base, format) else NA_character_

  if (mustWork && (is.na(p) || !file.exists(p)))
    stop(sprintf(
      "Expert file not found: scheme='%s', version='%s', format='%s'.",
      scheme, version, format %||% "json/txt"
    ), call. = FALSE)

  p
}
