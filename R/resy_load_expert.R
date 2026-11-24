#' Load a classification
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' Loads a parsed expert-system object ready for use with [resy_classify()].
#'
#' If `expertfile` is given it takes precedence over `scheme`/`version`. The
#' file format is detected from the extension:
#' \describe{
#'   \item{`.json`, `.json.xz`}{Parsed directly via the internal JSON parser
#'     (preferred); `.json.xz` is xz-compressed JSON.}
#'   \item{`.txt`}{Parsed via the legacy text parser.}
#' }
#'
#' When no `expertfile` is supplied, the function looks for
#' `expert.json` (or `expert.json.xz`), then `expert.txt` (or `expert.txt.xz`), in that order, under
#' `<root>/<scheme>/<version>/`, where the roots are searched in the order
#' given by `location`: classifications stored with [resy_add_classification()]
#' (`"user"`) and the classifications shipped with the package (`"package"`).
#'
#' A loaded system is kept in RESY's cache directory
#' (`tools::R_user_dir("RESY", "cache")`), so that loading the same file again
#' restores it instead of parsing it. The cached copy is used only while the
#' file keeps its size and modification time and the same installed version of
#' RESY loads it; storing a new copy removes the older ones of that file. Set
#' `options(RESY.cache = FALSE)` to parse every time, or
#' `options(RESY.cache_dir = <path>)` to keep the cache elsewhere.
#'
#' @param expertfile Optional path to a `.json` or `.txt` file.
#' @param scheme Classification scheme name (default `"EUNIS"`).
#' @param version Version identifier. If `NULL`, the newest available version
#'   is used.
#' @param location Where to look for `scheme`/`version`, in search order. One
#'   or both of `"user"` and `"package"`; the default searches both, user
#'   first, so a user-stored classification takes precedence over a shipped
#'   one with the same scheme and version.
#' @return A list of class `resy_parsed_expert`. Its scheme, version and file,
#'   and whether the file is byte-identical to the published release, are
#'   reported by [resy_provenance()].
#' @seealso [resy_available_classifications()], [resy_add_classification()],
#'   [resy_provenance()]
#' @examples
#' expert <- resy_load_expert(scheme = "Apennine-test")
#' expert$vegtype.formula.names
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
    stop("Classification not found for scheme='", scheme, "', version='", version, "'.")

  # --- First root in search order; json preferred over txt within a root
  paths <- c(rbind(hit$expert_json, hit$expert_txt))
  paths <- paths[!is.na(paths)]
  if (!length(paths))
    stop("No expert file (json/txt) found for scheme='", scheme, "', version='", version, "'.")
  .resy_parse_by_ext(paths[1L], scheme = scheme, version = version)
}

# Dispatch to the correct parser based on file extension, and record where the
# parsed system came from (see .resy_expert_source()). The file is read once;
# the parser and the checksum share its bytes. A system loaded before comes
# from the cache (see .resy_cache_file()).
.resy_parse_by_ext <- function(path, scheme = NULL, version = NULL) {
  if (!file.exists(path))
    stop("File not found: ", path)
  cache <- .resy_cache_file(path, scheme = scheme, version = version)
  parsed <- .resy_cache_read(cache)
  if (inherits(parsed, "resy_parsed_expert")) return(parsed)
  bytes <- .resy_read_raw(path)
  parsed <- if (.resy_is_json(path)) .resy_parsed_from_json(.resy_raw_json(bytes)) else
    .resy_build_parsed(.resy_parse_expert_lines(.resy_raw_lines(bytes)))
  parsed$source <- .resy_expert_source(path, scheme = scheme, version = version,
                                       md5 = .resy_raw_md5(bytes))
  .resy_cache_write(cache, parsed, path)
  parsed
}
