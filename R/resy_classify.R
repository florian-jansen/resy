
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
#' Loads an expert system (by file or by scheme/version), aggregates taxa,
#' evaluates the membership conditions, and returns plot classifications.
#'
#' The classifier is taxonomy-agnostic: it classifies the species names in `obs`
#' as they are given. Names should already match the expert system's vocabulary.
#' If your plot data uses names from a general backbone (GBIF, WFO, POWO,
#' Euro+Med, a national checklist), harmonise them first as an explicit step with
#' [resy_resolve_taxa] and inspect the result with [resy_summarize_taxa] before
#' classifying, so the taxonomic choices stay visible (see the taxonomy
#' vignette). Setting `resolve_taxa = TRUE` runs that resolution inside
#' `resy_classify()` as a convenience: names the expert already knows pass through
#' untouched, unknown names are looked up in the synonym table, and names that
#' resolve to nothing keep their original value (never a best guess). What was
#' resolved is then reported in the result's `taxon_resolution`.
#'
#' @param obs Observations as `data.table` with at least columns describing plot id,
#'   the species name (see `species_col`), and `Cover_Perc`.
#' @param header Plot header data.frame; required for evaluating $$C/$$N.
#' @param expertfile Optional path to expert-system file (.json/.txt). If set, takes precedence.
#' @param scheme Scheme name (default: "EUNIS").
#' @param version Version identifier. If NULL, uses latest available version for the scheme.
#' @param location Where to look for scheme/version "user" or "package".
#' @param id_col Optional name of the plot id column. If NULL, tries PlotObservationID, then PlotID.
#' @param species_col Name of the column in `obs` holding the species name
#'   (default `"TaxonName"`). Resolved names are written back to `TaxonName`.
#' @param resolve_taxa Logical; if `FALSE` (default) the classifier is
#'   taxonomy-agnostic and uses the names in `obs` as given. If `TRUE`, species
#'   names are resolved to the expert's vocabulary via [resy_resolve_taxa] before
#'   classification (see Description).
#' @param synonyms Synonym-table override passed to [resy_resolve_taxa] when
#'   `resolve_taxa = TRUE`; `NULL` uses the shipped table.
#' @param mc Number of CPU cores to use.
#' @return An object of class `resy_result`. When `resolve_taxa = TRUE` it also
#'   carries a `taxon_resolution` summary from [resy_summarize_taxa]; otherwise
#'   `taxon_resolution` is `NULL`.
#' @seealso [resy_resolve_taxa], [resy_summarize_taxa]
#' @examples
#' \donttest{
#' # Classify the bundled example plots with the minimal Apennine-test scheme.
#' species <- utils::read.csv(
#'   system.file("extdata", "data_example_species.csv", package = "RESY")
#' )
#' names(species)[names(species) == "species"] <- "TaxonName"
#' names(species)[names(species) == "cover"]   <- "Cover_Perc"
#'
#' # A one-row-per-plot header is required even without geographic conditions.
#' header <- as.data.frame(unique(species["PlotObservationID"]))
#'
#' res <- resy_classify(species, header, scheme = "Apennine-test")
#' head(res$result.classification)
#' }
#' @export
resy_classify <- function(obs,
                          header,
                          expertfile = NULL,
                          scheme = "EUNIS",
                          version = NULL,
                          location = c("user", "package"),
                          id_col = NULL,
                          species_col = "TaxonName",
                          resolve_taxa = FALSE,
                          synonyms = NULL,
                          mc = max(1L, floor(parallel::detectCores() * 0.75))) {
  if (!inherits(obs, "data.table")) obs <- data.table::as.data.table(obs)

  parsed <- resy_load_expert(expertfile = expertfile, scheme = scheme, version = version)

  # Optional convenience: resolve species names to the expert's vocabulary. The
  # expert system carries its own synonymy (aggregation targets + members), so a
  # name it already knows passes through untouched; only names it lacks are looked
  # up in the synonym table. Unresolved taxa keep their original value (no row
  # dropped, so obs stays aligned with header) and classify as an unknown species.
  # Off by default: the classifier is taxonomy-agnostic and resolution is an
  # explicit user step (see resy_resolve_taxa and the taxonomy vignette).
  taxon_resolution <- NULL
  if (isTRUE(resolve_taxa) && species_col %in% names(obs)) {
    expert_vocab <- unique(c(names(parsed$aggs),
                             unlist(parsed$aggs, use.names = FALSE)))
    resolved <- resy_resolve_taxa(obs, species_col = species_col,
                                  synonyms = synonyms, canonical = expert_vocab)
    taxon_resolution <- resy_summarize_taxa(resolved, species_col = species_col)
    obs <- data.table::as.data.table(resolved)
    unresolved <- is.na(obs$canonical)
    obs$TaxonName <- ifelse(unresolved, as.character(obs[[species_col]]),
                            obs$canonical)
  } else if (!"TaxonName" %in% names(obs) && species_col %in% names(obs)) {
    # Agnostic path: the solver keys on TaxonName; mirror a custom species column
    # into it so a user need not rename their column by hand.
    obs$TaxonName <- as.character(obs[[species_col]])
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
