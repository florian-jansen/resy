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
#' `<root>/<scheme>/<version>/`, where the roots are searched in the order
#' given by `location`: classifications stored with [resy_add_classification()]
#' (`"user"`) and the classifications shipped with the package (`"package"`).
#'
#' @param expertfile Optional path to a `.json` or `.txt` file.
#' @param scheme Classification scheme name (default `"EUNIS"`).
#' @param version Version identifier. If `NULL`, the newest available version
#'   is used.
#' @param location Where to look for `scheme`/`version`, in search order. One
#'   or both of `"user"` and `"package"`; the default searches both, user
#'   first, so a user-stored classification takes precedence over a shipped
#'   one with the same scheme and version.
#' @return A list of class `resy_parsed_expert`.
#' @seealso [resy_available_classifications()], [resy_add_classification()]
#' @export
resy_load_expert <- function(expertfile = NULL,
                             scheme     = "EUNIS",
                             version    = NULL,
                             location   = c("user", "package")) {
  # --- Direct file path
  if (!is.null(expertfile)) {
    return(.resy_parse_by_ext(expertfile))
  }

  location <- match.arg(location, several.ok = TRUE)
  avail <- do.call(rbind, lapply(location, function(loc)
    .resy_scan_classifications(.resy_classifications_root(loc))))
  avail <- avail[avail$scheme == scheme, , drop = FALSE]
  if (nrow(avail) == 0L)
    stop("No classifications found for scheme: '", scheme, "'.")

  # --- Resolve version
  if (is.null(version))
    version <- sort(avail$version, decreasing = TRUE)[1L]
  hit <- avail[avail$version == version, , drop = FALSE]
  if (nrow(hit) == 0L)
    stop(
      "Classification not found for scheme='",
      scheme, "', version='", version, "'."
      )

  # --- First root in search order; json preferred over txt within a root
  paths <- c(rbind(hit$expert_json, hit$expert_txt))
  paths <- paths[!is.na(paths)]
  if (!length(paths))
    stop(
      "No expert file (json/txt) found for scheme='",
      scheme, "', version='", version, "'."
      )
  .resy_parse_by_ext(paths[1L])
}

# Dispatch to the correct parser based on file extension.
.resy_parse_by_ext <- function(path) {
  if (grepl("\\.json$", path, ignore.case = TRUE))
    return(.resy_parse_json(path))
  # Treat anything else as a .txt expert file
  .resy_build_parsed(.resy_parse_expert_file(path))
}
