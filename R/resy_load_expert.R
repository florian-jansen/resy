#' Load a classification
#'
#' @description
#' Loads a parsed expert-system object ready for use with [resy_classify()].
#'
#' If `expertfile` is given it takes precedence over `scheme`/`version`. The
#' file format is detected from the extension:
#' \describe{
#'   \item{`.json`}{Parsed directly via the internal JSON parser (preferred).}
#'   \item{`.txt`}{Parsed via the legacy text parser.}
#' }
#'
#' When no `expertfile` is supplied, the function looks for
#' `expert.json`, then `expert.txt` (in that order) under
#' `inst/extdata/classifications/<scheme>/<version>/` in the installed package.
#'
#' @param expertfile Optional path to a `.json` or `.txt` file.
#' @param scheme Classification scheme name (default `"EUNIS"`).
#' @param version Version identifier. If `NULL`, the newest available version
#'   is used.
#' @return A list of class `resy_parsed_expert`.
#' @seealso [resy_available_classifications()]
#' @export
resy_load_expert <- function(expertfile = NULL,
                             scheme     = "EUNIS",
                             version    = NULL) {
  # --- Direct file path
  if (!is.null(expertfile)) {
    return(.resy_parse_by_ext(expertfile))
  }

  # --- Resolve version
  if (is.null(version)) {
    avail   <- resy_available_classifications()
    avail   <- avail[avail$scheme == scheme, , drop = FALSE]
    if (nrow(avail) == 0L)
      stop("No classifications found for scheme: '", scheme, "'.")
    version <- sort(avail$version, decreasing = TRUE)[1L]
  }

  # --- Find file in package (json preferred over txt)
  base <- system.file("extdata", "classifications", scheme, version, package = "RESY")
  if (!nzchar(base))
    stop("Classification not found for scheme='", scheme, "', version='", version, "'.")

  for (fname in c("expert.json", "expert.txt")) {
    p <- file.path(base, fname)
    if (file.exists(p)) return(.resy_parse_by_ext(p))
  }

  stop("No expert file (json/txt) found for scheme='", scheme, "', version='", version, "'.")
}

# Dispatch to the correct parser based on file extension.
.resy_parse_by_ext <- function(path) {
  if (grepl("\\.json$", path, ignore.case = TRUE))
    return(resy_parse_json(path))
  # Treat anything else as a .txt expert file
  .resy_build_parsed(parse.classification.expert.file(path))
}
