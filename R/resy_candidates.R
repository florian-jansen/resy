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
#' @param top_n Optional maximum number of candidates to return per plot, the
#'   highest priorities first.
#' @param wide Logical. If `TRUE`, returns one row per plot with its
#'   classification and its candidate types side by side, highest priority
#'   first.
#' @return A `tibble` with columns `plot_id`, `type`, `priority`, `priority_rank`.
#'   With `wide = TRUE`, a `data.table` with one row per plot and columns
#'   `plot_id`, `classification`, then `type_1`, `priority_1`, `type_2`,
#'   `priority_2`, ...; a plot with fewer candidates has `NA` in the remaining
#'   columns.
#' @export
resy_candidates <- function(
    res, plot_id = NULL, priority = NULL, min_priority = NULL, top_n = NULL,
    wide = FALSE
    ) {
  
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

  if (nrow(cand) == 0L && !isTRUE(wide)) {
    
    return(
      tibble::as_tibble(
        cand[, c("plot_id", "type", "priority", "priority_rank"), with = FALSE]
        )
      )
    
  }

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
    
    if (isTRUE(wide)) return(.resy_candidates_wide(cand_sub, all_plots, res))
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
    cand <- cand[order(plot_id, -priority_rank, type)][, head(.SD, top_n), by = plot_id]
    
  }
  
  if (isTRUE(wide)) return(.resy_candidates_wide(cand, all_plots, res))
  cand[]
  
}

.resy_candidates_wide <- function(cand, plots, res) {
  cls <- res$result.classification
  out <- data.table::data.table(
    plot_id = plots,
    classification = if (is.null(cls)) NA_character_ else unname(as.character(cls[plots]))
  )
  cand <- cand[!is.na(type)][order(plot_id, -priority_rank, type)]
  if (!nrow(cand)) return(out[])

  cand[, rank := seq_len(.N), by = plot_id]
  w <- data.table::dcast(cand, plot_id ~ rank, value.var = c("type", "priority"))
  n <- seq_len(max(cand$rank))
  cols <- as.vector(rbind(paste0("type_", n), paste0("priority_", n)))
  out <- merge(out, w[, c("plot_id", cols), with = FALSE], by = "plot_id",
               all.x = TRUE, sort = FALSE)
  out[match(plots, out$plot_id)]
}
