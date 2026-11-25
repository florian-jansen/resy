
#' @noRd
.resy_init_plot_conditions <- function(obs, membership.expressions) {
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
#' `r lifecycle::badge("experimental")`
#' Loads an expert system (by file or by scheme/version), matches the species
#' of the plots to it, evaluates the membership conditions, and returns plot
#' classifications.
#'
#' How species names are matched depends on Section 1 of the expert system:
#' * An expert system with a taxonomic backbone (the bundled defaults, e.g.
#'   EUNIS `2025-10-03-EuroSL` with EuroSL) resolves the plot names to taxon
#'   concepts of the backbone (see [resy_backbone()]). A plot taxon counts for
#'   an expert taxon if the backbone places it at or below that taxon. Names
#'   that cannot be used are reported in the result's `taxon_resolution`,
#'   split into potentially important and probably unimportant ones (see the
#'   taxonomy vignette).
#' * An expert system with species aggregations in Section 1 (the published
#'   EUNIS-ESy releases) classifies the names as they are given, after merging
#'   the names each aggregation lists.
#'
#' @param obs Observations as a data frame or `data.table` with at least columns
#'   describing plot id, the species name (see `species_col`), and the cover
#'   `Cover_Perc`. Darwin Core names are accepted: `eventID` for the plot id,
#'   `scientificName` for the species, and `organismQuantity` for the cover when
#'   `organismQuantityType` is a percent cover such as `"\% cover"`.
#' @param header Plot header data frame with one row per plot; required for
#'   evaluating $$C/$$N. Darwin Core `country` is accepted for `Country`, and
#'   `Altitude` or Darwin Core
#'   `minimumElevationInMeters`/`maximumElevationInMeters` for `Altitude (m)`.
#' @param expertfile Optional path to expert-system file (.json/.txt). If set, takes precedence.
#' @param scheme Scheme name (default: "EUNIS").
#' @param version Version identifier. If NULL, uses latest available version for the scheme.
#' @param location Where to look for `scheme`/`version`, in search order; see
#'   [resy_load_expert()]. Defaults to both `"user"` and `"package"`.
#' @param id_col Optional name of the plot id column. If NULL, tries
#'   PlotObservationID, then PlotID, then Darwin Core eventID.
#' @param species_col Name of the column in `obs` holding the species name. If
#'   `NULL` (default), uses `TaxonName`, then Darwin Core `scientificName`.
#'   Resolved names are written back to `TaxonName`.
#' @param resolve_taxa,synonyms `r lifecycle::badge("deprecated")` Resolution
#'   of names through the synonym layer ([resy_resolve_taxa()]) for expert
#'   systems with Section 1 aggregations. Expert systems with a taxonomic
#'   backbone always match names along the backbone.
#' @param mc Number of CPU cores to use.
#' @param expert An expert system already read with [resy_load_expert()]. When
#'   given, `expertfile`, `scheme`, `version` and `location` are not used, so
#'   data classified in several parts reads the expert system only once.
#' @return An object of class `resy_result`. For an expert system with a
#'   taxonomic backbone, `taxon_resolution` is the table of plot taxon names
#'   matched against the backbone (as from [resy_check_taxonomy()]); its
#'   `summary()` lists the names not matched, split into potentially important
#'   and probably unimportant ones, and `backbone_version` is the version of the
#'   backbone used. With the deprecated `resolve_taxa = TRUE`,
#'   `taxon_resolution` is the `summary()` of the [resy_resolve_taxa()] result;
#'   otherwise it is `NULL`. The
#'   expert-system release and, when the bundled synonym layer was used, its
#'   build are reported by [resy_provenance()].
#' @seealso [resy_check_taxonomy()], [resy_backbone()], [resy_provenance()]
#' @examples
#' \donttest{
#' # Classify the bundled example plots with the minimal Apennine-test scheme.
#' species <- utils::read.csv(
#'   system.file("extdata", "data_example_species.csv", package = "RESY")
#' )
#'
#' # A one-row-per-plot header is required even without geographic conditions.
#' header <- as.data.frame(unique(species["PlotObservationID"]))
#'
#' res <- resy_classify(species, header, scheme = "Apennine-test", version = "2026-06-27",
#'                      species_col = "scientificName")
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
                          species_col = NULL,
                          resolve_taxa = lifecycle::deprecated(),
                          synonyms = lifecycle::deprecated(),
                          mc = max(1L, floor(parallel::detectCores() * 0.75)),
                          expert = NULL) {
  if (!inherits(obs, "data.table")) obs <- data.table::as.data.table(obs)
  species_col <- .resy_species_col(obs, species_col)
  obs <- .resy_adopt_columns(obs, "Cover_Perc")
  header <- .resy_adopt_columns(header, c("Country", "Altitude (m)"))

  parsed <- expert %||% resy_load_expert(expertfile = expertfile, scheme = scheme,
                                         version = version, location = location)

  # Deprecated: resolution through the synonym layer, for expert systems with
  # Section 1 aggregations. Unresolved taxa keep their original value.
  if (lifecycle::is_present(synonyms)) {
    lifecycle::deprecate_warn("0.3.0", "resy_classify(synonyms)",
                              details = .resy_backbone_hint)
  } else {
    synonyms <- NULL
  }
  if (lifecycle::is_present(resolve_taxa)) {
    lifecycle::deprecate_warn("0.3.0", "resy_classify(resolve_taxa)",
                              details = .resy_backbone_hint)
    resolve_taxa <- isTRUE(resolve_taxa) && is.null(parsed$backbone)
  } else {
    resolve_taxa <- FALSE
  }
  taxon_resolution <- NULL
  if (resolve_taxa) {
    resolved <- resy_resolve_taxa(obs, species_col = species_col,
                                  synonyms = synonyms, expert = parsed)
    taxon_resolution <- summary(resolved)
    obs <- data.table::as.data.table(resolved)
    unresolved <- is.na(obs$canonical)
    obs$TaxonName <- ifelse(unresolved, as.character(obs[[species_col]]),
                            obs$canonical)
  } else if (species_col != "TaxonName") {
    # Agnostic path: the solver keys on TaxonName; mirror a custom species column
    # into it so a user need not rename their column by hand.
    obs$TaxonName <- as.character(obs[[species_col]])
  }

  tmp <- .resy_standardize_plot_id(obs, header, id_col = id_col)
  obs <- tmp$obs
  header <- tmp$header

  # Header conditions ($$C, $$N) on a column the header lacks, and numeric
  # conditions ($$N) on a missing value, are evaluated as 0 by the solver, so
  # say which columns and how many plots this affects.
  header_conds <- parsed$conditions[startsWith(parsed$conditions, "$$C") |
                                      startsWith(parsed$conditions, "$$N")]
  header_cols <- trimws(substring(header_conds, 4L))
  missing_cols <- setdiff(unique(header_cols), names(header))
  if (length(missing_cols)) {
    warning("`header` is missing columns used by the expert system: ",
            paste(missing_cols, collapse = ", "),
            ". Rules using these columns are evaluated with a value of 0.",
            call. = FALSE)
  }
  num_cols <- intersect(unique(header_cols[startsWith(header_conds, "$$N")]),
                        names(header))
  in_obs <- header$PlotObservationID %in% obs$PlotObservationID
  n_na <- vapply(num_cols, function(col) sum(is.na(header[[col]][in_obs])),
                 integer(1))
  n_na <- n_na[n_na > 0]
  if (length(n_na)) {
    warning("Header columns used by the expert system have missing values: ",
            paste0(names(n_na), " (", n_na, ifelse(n_na == 1, " plot)", " plots)"),
                   collapse = ", "),
            ". Conditions on them are evaluated as if the value were 0.",
            call. = FALSE)
  }

  # Expert systems with a taxonomic backbone: plot taxa count for an expert
  # taxon if the backbone places them at or below it. Otherwise Section 1
  # aggregates the plot taxa.
  if (!is.null(parsed$backbone)) {
    bb <- .resy_backbone_apply(obs, parsed)
    obs2 <- bb$obs
    parsed <- bb$parsed
    taxon_resolution <- .resy_backbone_taxa_table(bb$taxa, species_col, parsed$backbone)
    backbone_version <- bb$version
    .resy_backbone_message(bb$taxa)
  } else {
    obs2 <- .resy_aggregate_taxa(obs, parsed$aggs)
    backbone_version <- NULL
  }
  plot.cond <- .resy_init_plot_conditions(obs2, parsed$conditions)
  
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
  n_types <- lengths(res$types)
  if (sum(n_types) > 0) {
    ty <- as.character(unlist(res$types, use.names = FALSE))
    pr <- parsed$vegtype.priority[unlist(res$type_rules, use.names = FALSE)]
    cand <- data.table::data.table(
      plot_id       = rep(as.character(names(res$types)), n_types),
      type          = ty,
      priority      = pr,
      priority_rank = as.integer(pr)
    )
    data.table::setorder(cand, plot_id, -priority_rank, type)
  }
  
  src <- parsed$source
  structure(
    c(list(obs = obs2, header = header, expertfile = expertfile,
           scheme = src$scheme %||% scheme, version = src$version %||% version,
           prefer = location, candidates = cand, taxon_resolution = taxon_resolution,
           backbone_version = backbone_version,
           synonym_layer = if (resolve_taxa && is.null(synonyms))
             .resy_synonym_layer_build() else NULL),
      res,
      list(parsed = parsed)),
    class = "resy_result"
  )
}
