#' List possible assignments per plot
#'
#' @description
#' The result object returned by [resy_classify()] contains a long table of all
#' vegetation types that were evaluated as possible for each plot (i.e. the
#' corresponding vegtype formula evaluated to `TRUE`).
#'
#' This helper lets you access, sort, and filter those candidates.
#'
#' @param res A `resy_result` returned by [resy_classify()].
#' @param plot_id Optional plot id (character or numeric). If `NULL`, returns
#'   candidates for all plots.
#' @param priority Optional priority *rank* (integer). If provided, 
#' only candidates with `priority_rank == priority` are returned.
#' @param min_priority Optional minimum priority *rank* (integer). Higher means
#'   higher priority. If provided, only candidates with `priority_rank >= min_priority`
#'   are returned.
#' @param top_n Optional maximum number of candidates to return per plot.
#' @return A `data.table` with columns `plot_id`, `type`, `priority`, `priority_rank`.
#' @export
resy_candidates <- function(res, plot_id = NULL, priority = NULL, min_priority = NULL, top_n = NULL) {
  stopifnot(inherits(res, "resy_result"))
  
  cand <- res$candidates
  if (is.null(cand)) {
    stop("No candidate table found in result. Re-run resy_classify() with a recent package version.")
  }
  if (!inherits(cand, "data.table")) cand <- data.table::as.data.table(cand)

  # Ensure required columns exist even when no types matched
  for (col in c("plot_id", "type", "priority", "priority_rank")) {
    if (!col %in% names(cand))
      cand[[col]] <- if (col == "priority_rank") integer() else character()
  }

  if (nrow(cand) == 0L)
    return(cand[, c("plot_id", "type", "priority", "priority_rank"), with = FALSE])

  all_plots <- names(res$result)
  if (is.null(all_plots) || !length(all_plots)) {
    all_plots <- unique(as.character(cand$plot_id))
  } else {
    all_plots <- unique(as.character(all_plots))
  }
  
  if (!is.null(plot_id)) {
    all_plots <- intersect(all_plots, as.character(plot_id))
  }
  
  if (!is.null(priority) && !is.null(min_priority)) {
    stop("Use only one of 'priority' or 'min_priority'.")
  }
  
  if (!is.null(priority)) {
    pr <- as.integer(priority)
    
    base <- data.table::data.table(plot_id = all_plots)
    cand_sub <- cand[priority_rank == pr]
    
    # keep only requested priority and at most one row per plot
    cand_sub <- cand_sub[order(plot_id)]
    cand_sub <- cand_sub[, .SD[1], by = plot_id]
    
    out <- cand_sub[base, on = "plot_id"]
    return(out[])
  }
  
  if (!is.null(min_priority)) {
    cand <- cand[priority_rank >= as.integer(min_priority)]
  }
  
  if (!is.null(plot_id)) {
    cand <- cand[plot_id %in% all_plots]
  }
  
  if (!is.null(top_n)) {
    top_n <- as.integer(top_n)
    cand <- cand[order(plot_id, priority_rank)][, head(.SD, top_n), by = plot_id]
  }
  
  cand[]
}