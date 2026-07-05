#' Aggregate taxa to expert-system aggregation level
#'
#' @description
#' Replaces `obs$TaxonName` by aggregated names if they occur in the aggregation
#' mapping of the expert system. If you use GermanSl or EuroSL, use `taxval` instead.
#'
#' @param obs A `data.table` with column `TaxonName`.
#' @param aggs Named list of aggregations as returned by [resy_parse_expert()].
#' @return Modified `obs` as `data.table`.
resy_aggregate_taxa <- function(obs, aggs) {
  if (!inherits(obs, "data.table")) obs <- data.table::as.data.table(obs)
  
  agg_stack <- data.table::as.data.table(stack(aggs))
  agg_stack[, ind := as.character(ind)]
  agg_id <- data.table::data.table(values = names(aggs), ind = names(aggs))
  AGG <- data.table::rbindlist(list(agg_stack, agg_id), use.names = TRUE, fill = TRUE)
  AGG <- AGG[values != "" & !is.na(values)]
  AGG <- AGG[ind != "" & !is.na(ind)]
  AGG <- unique(AGG, by = c("values", "ind"))
  
  index1 <- fastmatch::fmatch(obs$TaxonName, AGG$values)
  if (any(!is.na(index1))) {
    obs$TaxonName[!is.na(index1)] <- AGG$ind[index1[!is.na(index1)]]
  }
  obs
}

