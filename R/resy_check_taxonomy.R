#' Check species names against an expert system's species list
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' Validates taxon names in a plot observation table against the species names
#' of the loaded expert system: the aggregates of Section 1 with the names they
#' include, and the species that a species group or a membership condition
#' names. Returns a per-taxon table of matches and canonical name mappings.
#'
#' This is a purely offline check; no external name-resolution service is
#' called.
#'
#' The result is a `resy_taxa` data frame. Printing it shows what each column
#' holds and how many names matched; [base::summary()] returns the match counts and
#' the unmatched names.
#'
#' @param obs A data frame or `data.table` with a column holding taxon names.
#' @param parsed A `resy_parsed_expert` object from [resy_load_expert()].
#' @param col Name of the column in `obs` that holds taxon names. If `NULL`
#'   (default), uses `TaxonName`, then Darwin Core `scientificName`.
#' @return A `resy_taxa` data frame with one row per unique taxon name in `obs`:
#'   \describe{
#'     \item{`scientificName`}{The name as submitted in `obs`.}
#'     \item{`TaxonName`}{The canonical name used by [resy_classify()], or `NA`
#'       when unmatched.}
#'     \item{`matched`}{`TRUE` if the name was found among the species names
#'       of the expert system.}
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
resy_check_taxonomy <- function(obs, parsed, col = NULL) {

  if (!inherits(parsed, "resy_parsed_expert"))
    stop("`parsed` must be a resy_parsed_expert object (from resy_load_expert()).")
  col <- .resy_species_col(obs, col, arg = "col")

  # Section 1 maps aggregate names and their members to the aggregate; a
  # species that only a species group or a membership condition names is
  # evaluated as itself.
  targets <- .resy_expert_names(parsed, mapping = FALSE)$targets
  lookup  <- c(.resy_agg_lookup(parsed$aggs), stats::setNames(targets, targets))
  lookup  <- lookup[!duplicated(names(lookup))]

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
      scientificName = "Name as submitted",
      TaxonName      = "Canonical name used by resy_classify(); NA when unmatched",
      matched        = "TRUE if found among the species names of the expert system"
    ),
    reference = sprintf("checked against %d species names of the expert system",
                        length(targets))
  )
  
}
