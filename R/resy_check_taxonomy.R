#' Check species names against an expert system's species list
#'
#' @description
#' Validates taxon names in a plot observation table against the canonical
#' names and synonyms declared in Section 1 of the loaded expert system.
#' Returns a per-taxon summary of matches and canonical name mappings.
#'
#' This is a purely offline check; no external name-resolution service is
#' called.
#'
#' @param obs A data frame or `data.table` with a column holding taxon names.
#' @param parsed A `resy_parsed_expert` object from [resy_load_expert()].
#' @param col Name of the column in `obs` that holds taxon names
#'   (default `"TaxonName"`).
#' @return A data frame with one row per unique taxon name in `obs`:
#'   \describe{
#'     \item{`TaxonName`}{The name as it appears in `obs`.}
#'     \item{`matched`}{`TRUE` if the name was found as a canonical name or
#'       synonym in Section 1 of the expert system.}
#'     \item{`canonical`}{The canonical name, or `NA` when unmatched.}
#'   }
#' @seealso [resy_load_expert()], [resy_harmonize_eunis()]
#' @export
resy_check_taxonomy <- function(obs, parsed, col = "TaxonName") {
  if (!inherits(parsed, "resy_parsed_expert"))
    stop("`parsed` must be a resy_parsed_expert object (from resy_load_expert()).")
  if (!col %in% names(obs))
    stop("Column '", col, "' not found in `obs`.")

  aggs        <- parsed$aggs
  canon_names <- names(aggs)

  # Build lookup: synonym → canonical, canonical → itself
  synonyms <- unlist(aggs, use.names = FALSE)
  sources  <- rep(canon_names, lengths(aggs))
  lookup   <- c(
    stats::setNames(sources,     synonyms),
    stats::setNames(canon_names, canon_names)
  )
  lookup <- lookup[!duplicated(names(lookup))]

  taxa      <- unique(as.character(obs[[col]]))
  taxa      <- taxa[!is.na(taxa)]
  matched   <- taxa %in% names(lookup)
  canonical <- lookup[taxa]
  canonical[!matched] <- NA_character_

  data.frame(
    TaxonName = taxa,
    matched   = matched,
    canonical = unname(canonical),
    stringsAsFactors = FALSE
  )
}
