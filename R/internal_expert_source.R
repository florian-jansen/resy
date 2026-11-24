#' Published expert-system releases known to RESY
#'
#' Reads `inst/extdata/classifications/releases.csv`: one row per published
#' release, with the Zenodo DOI, download URL, size, MD5 and SHA-256 of the
#' released `.txt` file. The same table builds the getaca registry
#' (`data-raw/build_registry.R`).
#'
#' @return A data frame.
#' @keywords internal
#' @noRd
.resy_releases <- function() {
  f <- system.file("extdata", "classifications", "releases.csv", package = "RESY")
  if (!nzchar(f))
    return(data.frame(scheme = character(), version = character(),
                      doi = character(), file = character(), url = character(),
                      size = numeric(), md5 = character(), sha256 = character(),
                      licence = character(), stringsAsFactors = FALSE))
  utils::read.csv(f, colClasses = "character", stringsAsFactors = FALSE)
}

#' Where a parsed expert system came from
#'
#' Scheme and version come from the caller when it resolved the file from a
#' classification store; otherwise from the store layout
#' `<root>/<scheme>/<version>/expert.*` when the path has that shape; otherwise
#' from a published release whose `.txt` has the same MD5 as the file's
#' content.
#'
#' @param path Path of the expert file that was parsed.
#' @param scheme,version Scheme and version, when known to the caller.
#' @return A list with `scheme`, `version`, `file`, `md5`, `doi` and
#'   `identical_to_release` (`TRUE` when the file's content is byte-identical
#'   to the published `.txt`, `FALSE` when it differs, `NA` when no release of
#'   that scheme and version is known).
#' @keywords internal
#' @noRd
.resy_expert_source <- function(path, scheme = NULL, version = NULL,
                                md5 = .resy_content_md5(path)) {
  rel <- .resy_releases()

  if (is.null(scheme) || is.null(version)) {
    roots <- vapply(c("user", "package"), .resy_classifications_root, character(1))
    roots <- normalizePath(roots[nzchar(roots) & dir.exists(roots)],
                           winslash = "/", mustWork = FALSE)
    store <- normalizePath(dirname(dirname(dirname(path))), winslash = "/",
                           mustWork = FALSE)
    is_store_file <- basename(path) %in% unlist(.resy_expert_files) &&
      store %in% roots
    if (is_store_file) {
      version <- basename(dirname(path))
      scheme  <- basename(dirname(dirname(path)))
    } else if (any(hit <- rel$md5 == md5)) {
      scheme  <- rel$scheme[hit][1L]
      version <- rel$version[hit][1L]
    }
  }

  row <- rel[rel$scheme %in% scheme & rel$version %in% version, , drop = FALSE]
  list(
    scheme  = scheme %||% NA_character_,
    version = version %||% NA_character_,
    file    = basename(path),
    md5     = md5,
    doi     = if (nrow(row)) row$doi[1L] else NA_character_,
    identical_to_release = if (nrow(row)) identical(row$md5[1L], md5) else NA
  )
}
