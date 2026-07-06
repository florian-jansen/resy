
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
#' @param species_col Name of the column in `obs` holding the species name
#'   (default `"TaxonName"`). Only consulted when `by != "canonical"`.
#' @param by How `species_col` is keyed. `"canonical"` (default) takes the species
#'   column as already-canonical ESy names and does no translation. `"name"` first
#'   resolves the column to canonical names via the taxonomy synonym table (see
#'   [resy_resolve_taxa]), accepting names from any major backbone. A name the
#'   expert system already knows passes through untouched; only names it lacks are
#'   resolved (to an expert canonical), and an unresolved taxon keeps its original
#'   value and is classified as an unknown species (never a best guess). What
#'   resolved is reported in the result's `taxon_resolution`.
#' @param synonyms Synonym-table override passed to [resy_resolve_taxa] when
#'   `by = "name"`; `NULL` uses the shipped table.
#' @param mc Number of CPU cores to use.
#' @return An object of class `resy_result`. When `by != "canonical"` it also
#'   carries a `taxon_resolution` summary from [resy_summarize_taxa].
#' @seealso [resy_resolve_taxa], [resy_summarize_taxa]
#' @export
resy_classify <- function(obs,
                          header,
                          expertfile = NULL,
                          scheme = "EUNIS",
                          version = NULL,
                          location = c("user", "package"),
                          id_col = NULL,
                          species_col = "TaxonName",
                          by = c("canonical", "name"),
                          synonyms = NULL,
                          mc = max(1L, floor(parallel::detectCores() * 0.75))) {
  if (!inherits(obs, "data.table")) obs <- data.table::as.data.table(obs)
  by <- match.arg(by)

  parsed <- resy_load_expert(expertfile = expertfile, scheme = scheme, version = version)

  taxon_resolution <- NULL
  if (by != "canonical") {
    # The expert system carries its own synonymy (aggregation targets + members);
    # a name it already knows passes through untouched, and only names it lacks are
    # looked up in the synonym table -- so the exact-match set is the expert's own
    # vocabulary. Unresolved taxa keep their original value (no row dropped, so obs
    # stays aligned with header) and classify as an unknown species.
    expert_vocab <- unique(c(names(parsed$aggs),
                             unlist(parsed$aggs, use.names = FALSE)))
    resolved <- resy_resolve_taxa(obs, species_col = species_col,
                                  synonyms = synonyms, canonical = expert_vocab)
    taxon_resolution <- resy_summarize_taxa(resolved, species_col = species_col)
    obs <- data.table::as.data.table(resolved)
    unresolved <- is.na(obs$canonical)
    obs$TaxonName <- ifelse(unresolved, as.character(obs[[species_col]]),
                            obs$canonical)
  }

  tmp <- .resy_standardize_plot_id(obs, header, id_col = id_col)
  obs <- tmp$obs
  header <- tmp$header

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
    c(list(obs = obs2, header = header, expertfile = expertfile, scheme = scheme, version = version, prefer = location, candidates = cand, taxon_resolution = taxon_resolution),
      res,
      list(parsed = parsed)),
    class = "resy_result"
  )
}
