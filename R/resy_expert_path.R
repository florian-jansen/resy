#' Get the path to a bundled classification file
#'
#' @description
#' Returns the full path to an expert-system file bundled with the package.
#'
#' @param scheme Classification scheme, e.g. `"EUNIS"`.
#' @param version Version identifier, e.g. `"2025-10-03"`.
#' @param format One of `"json"` (default) or `"txt"`.
#' @param mustWork Logical; if `TRUE` (default) an error is thrown when the
#'   file does not exist.
#' @return A file path string, or `NA` (invisibly) when `mustWork = FALSE` and
#'   the file is absent.
#' @examples
#' # Path to the bundled EUNIS expert system (JSON by default).
#' resy_expert_path("EUNIS", "2025-10-03")
#'
#' # Probe without erroring when a scheme/version is not installed.
#' resy_expert_path("EUNIS", "1900-01-01", mustWork = FALSE)
#' @export
resy_expert_path <- function(scheme,
                             version,
                             format   = c("json", "txt"),
                             mustWork = TRUE) {
  format <- match.arg(format)
  fname  <- switch(format, json = "expert.json", txt = "expert.txt")

  base <- system.file("extdata", "classifications", scheme, version, package = "RESY")
  p    <- if (nzchar(base)) file.path(base, fname) else NA_character_

  if (mustWork && (is.na(p) || !file.exists(p)))
    stop(sprintf(
      "Expert file not found: scheme='%s', version='%s', format='%s'.",
      scheme, version, format
    ), call. = FALSE)

  p
}
