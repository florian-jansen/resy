#' Which expert system and taxonomic backbone produced a result
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' Reports the expert-system release a parsed expert system or a
#' classification result rests on, so it can be stored next to the result or
#' cited: the scheme and version, the file that was read, the MD5 checksum of
#' its content, the DOI of the published release, and whether the file is
#' byte-identical to the published `.txt`. For an expert system with a
#' taxonomic backbone, the backbone it declares (name, URL, version) is added,
#' and for a classification result also the version of the backbone that was
#' actually used. For a result of [resy_classify()] with the deprecated
#' `resolve_taxa = TRUE` and the bundled synonym layer, the build date of that
#' layer and the [taxify](https://github.com/gcol33/taxify) version it was built
#' with are added.
#'
#' @param x A `resy_parsed_expert` from [resy_load_expert()] or a
#'   `resy_result` from [resy_classify()].
#' @return A one-row data frame with columns `scheme`, `version`,
#'   `expert_file`, `expert_md5`, `release_doi`, `identical_to_release`,
#'   `backbone`, `backbone_url`, `backbone_version`, `backbone_version_used`,
#'   `synonym_layer_built`, `synonym_layer_taxify` and `resy_version`.
#'   `identical_to_release` is `NA` when no published release of that scheme
#'   and version is known (for example a user's own system); the
#'   `backbone*` columns are `NA` for an expert system without a backbone
#'   (`backbone_version_used` also for a parsed expert system), and the
#'   `synonym_layer_*` columns are `NA` when no synonym layer was used.
#' @seealso [resy_load_expert()], [resy_classify()]
#' @examples
#' resy_provenance(resy_load_expert(scheme = "EUNIS", version = "2021-06-01"))
#' @export
resy_provenance <- function(x) {
  if (inherits(x, "resy_result")) {
    src   <- x$parsed$source
    layer <- x$synonym_layer
    bb    <- x$parsed$backbone
    used  <- x$backbone_version
  } else if (inherits(x, "resy_parsed_expert")) {
    src   <- x$source
    layer <- NULL
    bb    <- x$backbone
    used  <- NULL
  } else {
    stop("`x` must be a resy_parsed_expert or a resy_result.", call. = FALSE)
  }
  src <- src %||% list()
  na  <- NA_character_
  data.frame(
    scheme               = src$scheme %||% na,
    version              = src$version %||% na,
    expert_file          = src$file %||% na,
    expert_md5           = src$md5 %||% na,
    release_doi          = src$doi %||% na,
    identical_to_release = src$identical_to_release %||% NA,
    backbone             = bb$name %||% na,
    backbone_url         = bb$url %||% na,
    backbone_version     = bb$version %||% na,
    backbone_version_used = used %||% na,
    synonym_layer_built  = layer$built %||% na,
    synonym_layer_taxify = layer$taxify_version %||% na,
    resy_version         = as.character(utils::packageVersion("RESY")),
    stringsAsFactors = FALSE
  )
}

#' Build record of the bundled synonym layer
#'
#' @return A list with the fields of `inst/extdata/esy_synonym_layer_build.csv`
#'   (`built`, `taxify_version`, `n_pairs`, ...), or `NULL` when the file is
#'   absent.
#' @keywords internal
#' @noRd
.resy_synonym_layer_build <- function() {
  f <- system.file("extdata", "esy_synonym_layer_build.csv", package = "RESY")
  if (!nzchar(f)) return(NULL)
  as.list(utils::read.csv(f, colClasses = "character", stringsAsFactors = FALSE)[1L, ])
}
