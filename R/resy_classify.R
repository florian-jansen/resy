
#' @keywords internal
resy_init_plot_conditions <- function(obs, membership.expressions) {
  if (!inherits(obs, "data.table")) obs <- data.table::as.data.table(obs)
  if (!"PlotObservationID" %in% names(obs)) stop("obs must contain PlotObservationID")
  plots <- as.character(unique(obs$PlotObservationID))
  
  k <- length(membership.expressions %||% character(0))
  cn <- paste0("col", seq_len(k))
  
  array(0, c(length(plots), k),
        dimnames = list(plots, cn))
}



#' Classify vegetation plots with the expert system
#'
#' @description
#' Convenience wrapper that loads an expert system (by file or by scheme/version),
#' aggregates taxa, evaluates membership conditions/expressions, and returns plot
#' classifications.
#'
#' @param obs Observations as `data.table` with at least columns describing plot id,
#'   `TaxonName`, and `Cover_Perc`.
#' @param header Plot header data.frame; required for evaluating $$C/$$N.
#' @param expertfile Optional path to expert-system file (.json/.txt). If set, takes precedence.
#' @param scheme Scheme name (default: "EUNIS").
#' @param version Version identifier. If NULL, uses latest available version for the scheme.
#' @param location Where to look for scheme/version "user" or"package".
#' @param id_col Optional name of the plot id column. If NULL, tries PlotObservationID, then PlotID.
#' @param mc Number of CPU cores to use.
#' @return An object of class `resy_result`.
#' @export
resy_classify <- function(obs,
                          header,
                          expertfile = NULL,
                          scheme = "EUNIS",
                          version = NULL,
                          location = c("user", "package"),
                          id_col = NULL,
                          mc = max(1L, floor(parallel::detectCores() * 0.75))) {
  if (!inherits(obs, "data.table")) obs <- data.table::as.data.table(obs)
  
  tmp <- .resy_standardize_plot_id(obs, header, id_col = id_col)
  obs <- tmp$obs
  header <- tmp$header
  
  parsed <- resy_load_expert(expertfile = expertfile, scheme = scheme, version = version)
  
  obs2 <- resy_aggregate_taxa(obs, parsed$aggs)
  plot.cond <- resy_init_plot_conditions(obs2, parsed$conditions)
  
  res <- .resy_solve_membership(
    obs = obs2,
    header = header,
    parsed = parsed,
    plot.cond = plot.cond,
    mc = mc
  )
  
  # Build a long table of all possible assignments (types) per plot with priorities.
  empty_cand <- data.table::data.table(
    plot_id       = character(),
    type          = character(),
    priority      = character(),
    priority_rank = integer()
  )
  cand <- empty_cand
  if (!is.null(res$types) && length(res$types) > 0) {
    vt_names <- parsed$vegtype.formula.names.short
    vt_prio  <- parsed$vegtype.priority
    rows <- lapply(names(res$types), function(pid) {
      ty <- res$types[[pid]]
      if (!length(ty)) return(NULL)
      pr <- vt_prio[fastmatch::fmatch(ty, vt_names)]
      data.table::data.table(
        plot_id       = as.character(pid),
        type          = as.character(ty),
        priority      = pr,
        priority_rank = as.integer(pr)
      )
    })
    rows <- Filter(Negate(is.null), rows)
    if (length(rows)) {
      cand <- data.table::rbindlist(rows, use.names = TRUE, fill = TRUE)
      data.table::setorder(cand, plot_id, -priority_rank, type)
    }
  }
  
  structure(
    c(list(obs = obs2, header = header, expertfile = expertfile, scheme = scheme, version = version, prefer = location, candidates = cand),
      res,
      list(parsed = parsed)),
    class = "resy_result"
  )
}
