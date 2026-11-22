# Lookup from every name an expert system knows to the aggregate it belongs to:
# each member of an aggregation maps to the aggregate, and each aggregate to
# itself. Empty and missing names are dropped; a name listed under several
# aggregates keeps the first.
.resy_agg_lookup <- function(aggs) {
  canon <- names(aggs)
  lookup <- c(
    stats::setNames(rep(canon, lengths(aggs)), as.character(unlist(aggs, use.names = FALSE))),
    stats::setNames(canon, canon)
  )
  keep <- !is.na(names(lookup)) & nzchar(names(lookup)) & !is.na(lookup) & nzchar(lookup)
  lookup <- lookup[keep]
  lookup[!duplicated(names(lookup))]
}

#' Aggregate taxa to expert-system aggregation level
#'
#' @description
#' Replaces `obs$TaxonName` by aggregated names if they occur in the aggregation
#' mapping of the expert system. If you use GermanSl or EuroSL, use `taxval` instead.
#'
#' @param obs A `data.table` with column `TaxonName`.
#' @param aggs Named list of aggregations, the `aggs` element of
#'   [resy_load_expert()].
#' @return Modified `obs` as `data.table`.
#' @noRd
.resy_aggregate_taxa <- function(obs, aggs) {
  if (!inherits(obs, "data.table")) obs <- data.table::as.data.table(obs)
  if (!length(aggs)) return(obs)

  lookup <- .resy_agg_lookup(aggs)
  index1 <- fastmatch::fmatch(obs$TaxonName, names(lookup))
  hit <- !is.na(index1)
  if (any(hit)) obs$TaxonName[hit] <- unname(lookup[index1[hit]])
  obs
}
