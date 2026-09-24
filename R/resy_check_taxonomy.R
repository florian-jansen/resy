#' Check species names against an expert system's species list
#'
#' @description
#' Validates taxon names in a plot observation table against the canonical
#' names and synonyms declared in Section 1 of the loaded expert system.
#' Returns a per-taxon table of matches and canonical name mappings.
#'
#' This is a purely offline check; no external name-resolution service is
#' called.
#'
#' The result is a `resy_taxa` data frame. Printing it shows what each column
#' holds and how many names matched; [summary()] returns the match counts and
#' the unmatched names.
#'
#' @param obs A data frame or `data.table` with a column holding taxon names.
#' @param parsed A `resy_parsed_expert` object from [resy_load_expert()].
#' @param col Name of the column in `obs` that holds taxon names
#'   (default `"TaxonName"`).
#' @return A `resy_taxa` data frame with one row per unique taxon name in `obs`:
#'   \describe{
#'     \item{`scientificName`}{The name as submitted in `obs`.}
#'     \item{`TaxonName`}{The canonical name used by [resy_classify()], or `NA`
#'       when unmatched.}
#'     \item{`matched`}{`TRUE` if the name was found as a canonical name or
#'       synonym in Section 1 of the expert system.}
#'   }
#' @seealso [resy_load_expert()], [resy_harmonize_eunis()]
#' @examples
#' parsed <- resy_load_expert(scheme = "Apennine-test")
#'
#' obs <- data.frame(
#'   PlotObservationID = c("p1", "p1", "p2"),
#'   TaxonName = c("Fagus sylvatica",     # canonical name
#'                 "Abies alba Mill.",    # listed synonym of "Abies alba"
#'                 "Planta inventa")      # unknown to the expert system
#' )
#' checked <- resy_check_taxonomy(obs, parsed)
#' checked
#' summary(checked)
#'
#' # Names held in a differently named column
#' names(obs)[2] <- "species"
#' resy_check_taxonomy(obs, parsed, col = "species")
#' @export
resy_check_taxonomy <- function(obs, parsed, col = "TaxonName") {
  if (!inherits(parsed, "resy_parsed_expert"))
    stop("`parsed` must be a resy_parsed_expert object (from resy_load_expert()).")
  if (!col %in% names(obs))
    stop("Column '", col, "' not found in `obs`.")

  canon_names <- names(parsed$aggs)
  lookup      <- .resy_agg_lookup(parsed$aggs)

  taxa      <- unique(as.character(obs[[col]]))
  taxa      <- taxa[!is.na(taxa)]
  matched   <- taxa %in% names(lookup)
  canonical <- lookup[taxa]
  canonical[!matched] <- NA_character_

  out <- data.frame(
    scientificName = taxa,
    TaxonName      = unname(canonical),
    matched        = matched,
    stringsAsFactors = FALSE
  )
  .resy_taxa(
    out, input_col = col, name_col = "scientificName",
    columns = c(
      scientificName = "name as submitted",
      TaxonName      = "canonical name used by resy_classify(); NA when unmatched",
      matched        = "TRUE if found as a canonical name or Section 1 synonym"
    ),
    reference = sprintf("checked against %d Section 1 species", length(canon_names))
  )
}
