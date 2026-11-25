# Taxonomic backbone of an expert system.
#
# An expert system whose Section 1 names a taxonomic backbone (instead of
# listing species aggregations) is evaluated along the backbone's taxon tree: a
# plot taxon counts for an expert taxon if the backbone places it at or below
# that taxon. Names are resolved with vegdata, using only matching steps that
# keep the taxon concept.

.resy_backbone_cache <- new.env(parent = emptyenv())

# Pointer from the deprecated synonym-layer functions to the backbone.
.resy_backbone_hint <- paste(
  "Expert systems with a taxonomic backbone (the bundled default versions)",
  "match species names along the backbone; check names with resy_check_taxonomy().")

# Matching steps of vegdata::taxname.match() that keep the taxon concept. Left
# out: "simplify" (drops s. str., s. l. and rank markers), "infraspecific" and
# "genus" (widen a name). The "aggregate" step maps agg./s. l. to the aggregate;
# its fallback "aggregate as species" is rejected. Misapplied names ("auct.")
# are never matched by vegdata.
.resy_backbone_steps <- c("exact", "aggregate", "fuzzy", "accepted genus")

# Determination qualifiers: what such a record represents is unknown, so it is
# never matched.
.resy_uncertain_re <- "(^|\\s)(cf\\.?|aff\\.|\\?)(\\s|$)"
# Names whose extent differs from the plain species.
.resy_broad_re <- "\\s(aggr?\\.|s\\. ?l\\.|sensu lato|coll\\.|\\(group\\))(\\s|$)"
.resy_strict_re <- "\\s(s\\. ?str\\.|sensu stricto)(\\s|$)"
# Ranks (vegdata codes) a broad name may resolve to.
.resy_broad_ranks <- c("AGG", "AG2", "AG3", "GRP", "SER", "SEC", "SGE")
# Ranks from the genus upwards: records at these ranks are too coarse to count
# for any species.
.resy_coarse_ranks <- c("GAT", "TRI", "SFA", "FAM", "ORD", "ORA", "KLA", "UKL",
                        "CL6", "ABT", "UAB", "ROOT")

# Backbone declaration of a Section 1 body: the first line with text holds the
# backbone name, its URL and optionally a version ("EuroSL
# https://eurosl.infinitenature.org 2026-11-24"). NULL when the body is not a
# backbone declaration.
.resy_parse_backbone <- function(lines) {
  x <- trimws(lines[grepl("[^ \t\r\n]", lines)])
  if (!length(x)) return(NULL)
  tok <- strsplit(x[1L], "\\s+")[[1L]]
  if (length(tok) < 2L || !grepl("^https?://", tok[2L])) return(NULL)
  list(name = tok[1L], url = tok[2L],
       version = if (length(tok) >= 3L) tok[3L] else NA_character_)
}

# The Section 1 body declaring `backbone`.
.resy_backbone_line <- function(backbone) {
  trimws(paste(backbone$name, backbone$url,
               if (!is.na(backbone$version %||% NA)) backbone$version else ""))
}

#' Load the taxonomic backbone of an expert system
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' Reads the taxonomic reference list that an expert system declares in
#' Section 1 (for EUNIS: EuroSL), through the vegdata package.
#'
#' Where the list comes from, in order:
#' 1. `source`, if given: a path to an SQLite file holding the list in a table
#'    named after the backbone, a (compressed) CSV file, or a data frame with
#'    the list;
#' 2. the option `resy.backbone` (same forms), e.g.
#'    `options(resy.backbone = "~/EuroSL.sqlite")`;
#' 3. the reference list of that name installed for vegdata
#'    (see `vegdata::taxref_download_eurosl()`).
#'
#' The list is read once per session; a list read from a file is also kept in
#' RESY's cache directory (see [resy_load_expert()]) for later sessions.
#'
#' @param expert A `resy_parsed_expert` (from [resy_load_expert()]) declaring
#'   a backbone, or the backbone name (e.g. `"EuroSL"`).
#' @param source Optional path to an SQLite or CSV file, or a data frame; see
#'   above.
#' @return A `data.table` with one row per name of the reference list, in the
#'   standardised vegdata form (columns `TaxonUsageID`, `TaxonName`,
#'   `TaxonConceptID`, `SYNONYM`, `taxonRank`, `parentTaxonConceptID`, ...).
#' @seealso [resy_check_taxonomy()], [resy_classify()]
#' @export
resy_backbone <- function(expert, source = getOption("resy.backbone")) {
  name <- if (inherits(expert, "resy_parsed_expert")) expert$backbone$name else expert
  if (is.null(name) || !nzchar(name))
    stop("The expert system declares no taxonomic backbone.", call. = FALSE)
  .resy_backbone_get(name, source)$list
}

# The backbone `name` with its lookups, cached per session: `list` (the
# reference list), `concept_of` (usage -> accepted concept), `parent`,
# `name_of` and `rank_of` (by accepted concept).
.resy_backbone_get <- function(name, source = getOption("resy.backbone")) {
  # A backbone prepared with .resy_backbone_build() and saved as RDS
  if (is.character(source) && grepl("\\.rds$", source, ignore.case = TRUE)) {
    key <- paste(name, normalizePath(source, mustWork = FALSE))
    if (is.null(.resy_backbone_cache[[key]])) {
      if (!file.exists(source)) stop("Backbone file not found: ", source, call. = FALSE)
      bb <- readRDS(source)
      bb$memo <- new.env(parent = emptyenv())
      # lookups prepared with the file (.resy_backbone_prepare())
      bb$memo$keys <- bb$keys
      bb$memo$expert <- bb$expert
      bb$keys <- bb$expert <- NULL
      .resy_backbone_cache[[key]] <- bb
    }
    return(.resy_backbone_cache[[key]])
  }
  if (!requireNamespace("vegdata", quietly = TRUE))
    stop("Expert systems with a taxonomic backbone need the vegdata package, ",
         "or a prepared backbone (options(resy.backbone = <.rds file>)).", call. = FALSE)
  # Without a source, vegdata reads the reference list installed for it; its
  # file only identifies the list for the cache.
  path <- source
  if (is.null(source)) {
    path <- tryCatch(vegdata::db_path(tolower(name)), error = function(e) NULL)
  }
  key <- if (is.data.frame(source)) rlang::hash(source) else
    paste(name, normalizePath(path %||% "", mustWork = FALSE))
  if (!is.null(.resy_backbone_cache[[key]])) return(.resy_backbone_cache[[key]])

  # A backbone read from a file is kept in RESY's cache directory, so that later
  # sessions skip reading and standardising the list.
  file <- if (is.character(path) && file.exists(path))
    .resy_cache_file(path, scheme = "backbone", version = name)
  bb <- .resy_cache_read(file)
  if (is.null(bb)) {
    bb <- .resy_backbone_build(name, .resy_backbone_read(name, source))
    .resy_cache_write(file, bb, path)
  }
  bb$memo <- new.env(parent = emptyenv())
  .resy_backbone_cache[[key]] <- bb
  bb
}

# The reference list `name` from `source`: a data frame, an SQLite file with a
# table `name`, or a (compressed) CSV file; without a source, the name for
# vegdata to look up.
.resy_backbone_read <- function(name, source) {
  if (is.null(source) || is.data.frame(source)) return(source %||% name)
  if (!file.exists(source)) stop("Backbone file not found: ", source, call. = FALSE)
  if (grepl("\\.csv(\\.(gz|xz|bz2))?$", source, ignore.case = TRUE)) {
    return(utils::read.csv(source, colClasses = "character", na.strings = "",
                           encoding = "UTF-8"))
  }
  if (!requireNamespace("RSQLite", quietly = TRUE))
    stop("Reading a backbone from SQLite needs the RSQLite package.", call. = FALSE)
  con <- DBI::dbConnect(RSQLite::SQLite(), source)
  on.exit(DBI::dbDisconnect(con))
  DBI::dbReadTable(con, name)
}

# The standardised reference list with the lookups RESY uses: `list`,
# `concept_of` (usage -> accepted concept), `parent`, `name_of`, `rank_of` (by
# accepted concept) and `version`.
.resy_backbone_build <- function(name, refl) {
  sp <- suppressMessages(vegdata::tax("all", refl = refl))
  if (is.null(sp))
    stop("Backbone '", name, "' is not available. Install it for vegdata ",
         "(e.g. vegdata::taxref_download_eurosl()) or set ",
         "options(resy.backbone = <path to the SQLite file>).", call. = FALSE)
  sp <- data.table::as.data.table(sp)
  edit <- if ("EditStatus" %in% names(sp)) sp$EditStatus else character()
  version <- utils::head(sub("^version ", "", edit[grepl("^version ", edit)]), 1L)
  .resy_backbone_from(sp, if (length(version)) version else NA_character_)
}

# The lookups of a standardised reference list `sp`. Only the columns RESY
# reads are kept.
.resy_backbone_from <- function(sp, version) {
  sp <- sp[, c("TaxonUsageID", "TaxonName", "TaxonConceptID", "SYNONYM", "taxonRank",
               "parentTaxonConceptID"), with = FALSE]
  # vegdata takes the list as it is only when it is marked as standardised
  data.table::setattr(sp, "standardised", TRUE)
  acc <- sp[!sp$SYNONYM %in% TRUE]
  list(
    list       = sp,
    concept_of = stats::setNames(sp$TaxonConceptID, sp$TaxonUsageID),
    parent     = stats::setNames(acc$parentTaxonConceptID, acc$TaxonConceptID),
    name_of    = stats::setNames(acc$TaxonName, acc$TaxonConceptID),
    rank_of    = stats::setNames(acc$taxonRank, acc$TaxonConceptID),
    version    = version
  )
}

# Resolve `names` to backbone concepts, keeping the concept: one row per
# distinct name with the matched usage, its accepted concept (`concept`, NA
# when not matched), the accepted name, the match type and the reason a name is
# not matched (`issue`: "uncertain_determination", "level_unclear",
# "misapplied_name", "not_found"). Each name is matched once per backbone and
# session; classifying data in parts reuses the matches.
.resy_backbone_match <- function(names, bb) {
  u <- unique(as.character(names[!is.na(names) & nzchar(trimws(names))]))
  memo <- bb$memo %||% new.env(parent = emptyenv())
  done <- memo$match
  new <- if (is.null(done)) u else u[is.na(fastmatch::fmatch(u, done$name))]
  if (length(new)) {
    m <- if (.resy_backbone_vegdata()) .resy_match_vegdata(new, bb) else .resy_match_light(new, bb)
    concept <- unname(bb$concept_of[m$usage])
    rank <- unname(bb$rank_of[concept])
    issue <- data.table::fcase(
      grepl(.resy_uncertain_re, m$name, ignore.case = TRUE), "uncertain_determination",
      m$match %in% "misapplied name", "misapplied_name",
      m$match %in% "aggregate as species", "level_unclear",
      !is.na(concept) & grepl(.resy_broad_re, m$name) & !rank %in% .resy_broad_ranks,
      "level_unclear",
      grepl(.resy_strict_re, m$name), "level_unclear",
      is.na(concept), "not_found",
      default = NA_character_)
    concept[!is.na(issue)] <- NA_character_
    done <- data.table::rbindlist(list(done, data.table::data.table(
      name = m$name, usage = m$usage, concept = concept,
      accepted = unname(bb$name_of[concept]), match = m$match, issue = issue)))
    memo$match <- done
  }
  done[fastmatch::fmatch(u, done$name)]
}

# Whether names are matched with vegdata: when it is installed, unless
# options(resy.backbone_match = "light") asks for RESY's own matching.
.resy_backbone_vegdata <- function() {
  !identical(getOption("resy.backbone_match"), "light") &&
    requireNamespace("vegdata", quietly = TRUE)
}

# Matching with vegdata::taxname.match(): columns name, usage, match.
.resy_match_vegdata <- function(names, bb) {
  m <- data.table::as.data.table(suppressMessages(suppressWarnings(
    vegdata::taxname.match(names, refl = bb$list, steps = .resy_backbone_steps,
                           check.file = NULL))))
  m <- unique(m, by = "Name")
  m <- m[fastmatch::fmatch(names, m$Name)]
  data.table::data.table(name = names, usage = m$TaxonUsageID, match = m$match)
}

# RESY's own matching, without vegdata: a name as written, without its author
# citation, or a genus written as "X sp."; an aggregate (agg., aggr., s. l.,
# coll.) only as an aggregate of the backbone ("aggregate as species" when the
# backbone has the species only); misapplied names (auct.) never. There is no
# correction of spelling. Columns name, usage, match.
.resy_match_light <- function(names, bb) {
  keys <- .resy_backbone_keys(bb)
  look <- function(x) unname(keys[x])
  k <- .resy_name_key(names)
  usage <- look(k)
  plain <- .resy_name_key(.resy_strip_authors(k))
  open <- is.na(usage)
  usage[open] <- look(plain[open])
  broad <- grepl(.resy_broad_re, plain)
  base <- trimws(sub(paste0(.resy_broad_re, ".*$"), "", plain))
  open <- is.na(usage) & broad
  usage[open] <- look(paste(base[open], "agg."))
  as_species <- is.na(usage) & broad & !is.na(look(base))
  auct <- grepl(" auct\\.?( |$)", names)
  usage[auct | usage %in% "ambiguous"] <- NA_character_
  data.table::data.table(
    name = names, usage = usage,
    match = data.table::fcase(auct, "misapplied name", !is.na(usage) & broad, "aggregate",
                              !is.na(usage), "exact", as_species, "aggregate as species",
                              default = "none"))
}

# Lookup key of a name: single spaces, hybrids as "x ", "aggr." as "agg.",
# "ssp." as "subsp.", and "X sp." as the genus X.
.resy_name_key <- function(x) {
  x <- gsub("\u00d7\\s*", "x ", x)
  x <- gsub("\\s+", " ", trimws(x))
  x <- gsub(" aggr\\.?( |$)", " agg.\\1", x)
  x <- gsub(" ssp\\.", " subsp.", x)
  x <- sub(" (sp|spec|spp|species)\\.?$", "", x)
  trimws(x)
}

# A name without its author citation: the genus, then the lower-case words
# (epithets, rank markers, agg., s. l.) apart from the particles of authors.
.resy_strip_authors <- function(x) {
  particles <- c("ex", "et", "in", "de", "du", "van", "von", "der", "den", "la", "le", "&")
  # nomenclatural remarks: ", nom. illeg.", "nom. inval.", ...
  x <- sub(",? nom\\. .*$", "", x)
  vapply(strsplit(x, " ", fixed = TRUE), function(tok) {
    if (length(tok) < 2L) return(paste(tok, collapse = " "))
    rest <- tok[-1L]
    keep <- (grepl("^[a-z\u00e0-\u00ff-]", rest) & !rest %in% particles &
      !grepl("^d'", rest)) | rest == "(group)"
    paste(c(tok[1L], rest[keep]), collapse = " ")
  }, character(1))
}

# Lookup keys of the backbone's names (misapplied names left out): the usage
# a key stands for, or "ambiguous" when it names several concepts.
.resy_backbone_keys <- function(bb) {
  memo <- bb$memo %||% new.env(parent = emptyenv())
  if (!is.null(memo$keys)) return(memo$keys)
  sp <- bb$list
  ok <- !grepl(" auct\\.?( |$)", sp$TaxonName)
  key <- .resy_name_key(sp$TaxonName[ok])
  usage <- sp$TaxonUsageID[ok]
  concept <- sp$TaxonConceptID[ok]
  # accepted names first, so a key keeps the usage of its accepted name
  o <- order(sp$SYNONYM[ok] %in% TRUE)
  key <- key[o]; usage <- usage[o]; concept <- concept[o]
  n_concepts <- tapply(concept, key, function(x) length(unique(x)))
  first <- !duplicated(key)
  keys <- stats::setNames(usage[first], key[first])
  keys[names(n_concepts)[n_concepts > 1L]] <- "ambiguous"
  memo$keys <- keys
  keys
}

# The backbone restricted to `concepts`, everything the backbone places below
# them and their ancestors, each with all its names. Plot taxa outside the
# restriction are not matched. Used for the expert systems of the RESY App.
.resy_backbone_subset <- function(bb, concepts) {
  concepts <- unique(concepts[!is.na(concepts)])
  kids <- split(names(bb$parent), unname(bb$parent))
  keep <- concepts
  frontier <- concepts
  while (length(frontier)) {
    frontier <- setdiff(unlist(kids[frontier], use.names = FALSE), keep)
    keep <- c(keep, frontier)
  }
  keep <- union(keep, .resy_backbone_ancestors(concepts, bb$parent)$ancestor)
  out <- .resy_backbone_from(bb$list[bb$list$TaxonConceptID %in% keep], bb$version)
  out$subset <- TRUE
  out
}

# A backbone ready to be saved as RDS for sessions without vegdata (the RESY
# App): with `experts` (parsed expert systems), restricted to the taxa they
# name (see .resy_backbone_subset()), and with the lookup keys of the light
# matching and the resolved names of the expert systems computed beforehand.
.resy_backbone_prepare <- function(bb, experts = list()) {
  if (length(experts)) {
    concepts <- unlist(lapply(experts, function(p)
      .resy_backbone_match(.resy_expert_used(p), bb)$concept))
    bb <- .resy_backbone_subset(bb, concepts)
  }
  bb$memo <- new.env(parent = emptyenv())
  old <- options(resy.backbone_match = "light")
  on.exit(options(old))
  bb$keys <- .resy_backbone_keys(bb)
  for (p in experts) .resy_backbone_expert(p, bb)
  bb$expert <- bb$memo$expert
  bb$memo <- NULL
  bb
}

# Ancestors of each concept in `concepts`, the concept itself included at
# depth 0: a table with columns `concept`, `ancestor` and `depth`.
.resy_backbone_ancestors <- function(concepts, parent) {
  concepts <- unique(concepts[!is.na(concepts)])
  out <- list()
  cur <- concepts
  depth <- 0L
  while (length(cur) && any(!is.na(cur)) && depth < 100L) {
    keep <- !is.na(cur)
    out[[length(out) + 1L]] <- data.table::data.table(
      concept = concepts[keep], ancestor = cur[keep], depth = depth)
    concepts <- concepts[keep]
    cur <- unname(parent[cur[keep]])
    depth <- depth + 1L
  }
  if (!length(out))
    return(data.table::data.table(concept = character(), ancestor = character(),
                                  depth = integer()))
  data.table::rbindlist(out)
}

# Species an expert system names, resolved against its backbone: for each name
# the concept and the expert names below it in the backbone tree (`sets`), and
# the expert name a plot taxon at or below each referenced concept counts as.
.resy_backbone_expert <- function(parsed, bb) {
  ref <- .resy_expert_used(parsed)
  # resolved once per backbone and set of names, so that data classified in
  # parts resolves the expert system once
  memo <- bb$memo %||% new.env(parent = emptyenv())
  key <- rlang::hash(ref)
  if (!is.null(memo$expert[[key]])) return(memo$expert[[key]])
  out <- .resy_backbone_expert_resolve(ref, bb)
  if (is.null(memo$expert)) memo$expert <- list()
  memo$expert[[key]] <- out
  out
}

.resy_backbone_expert_resolve <- function(ref, bb) {
  m <- .resy_backbone_match(ref, bb)
  rc <- m$concept[match(ref, m$name)]
  # one expert name stands for each concept; further names of the same concept
  # are evaluated as that one
  rep_of <- tapply(ref[!is.na(rc)], rc[!is.na(rc)], `[`, 1L)
  anc <- .resy_backbone_ancestors(rc, bb$parent)
  anc <- anc[anc$ancestor %in% names(rep_of)]
  below <- split(unname(rep_of[anc$concept]), anc$ancestor)
  sets <- lapply(seq_along(ref), function(i)
    unique(c(ref[i], if (!is.na(rc[i])) below[[rc[i]]])))
  names(sets) <- ref
  list(names = ref, match = m, concept = rc, rep_of = rep_of, sets = sets)
}

# Plot taxon names against the backbone and the expert taxa: one row per
# distinct name with the expert name it counts as (`TaxonName`, NA when it
# counts for none) and, for names that do not count, how important that may be.
.resy_backbone_plot_taxa <- function(taxa, ex, bb) {
  taxa <- unique(as.character(taxa[!is.na(taxa)]))
  m <- .resy_backbone_match(taxa, bb)
  m <- m[match(taxa, m$name)]
  m$name <- taxa
  anc <- .resy_backbone_ancestors(m$concept, bb$parent)
  hit <- anc[anc$ancestor %in% names(ex$rep_of)]
  data.table::setorderv(hit, c("concept", "depth"))
  hit <- hit[!duplicated(hit$concept)]
  counts_as <- unname(ex$rep_of[hit$ancestor[match(m$concept, hit$concept)]])
  # a name the expert system uses literally, but the backbone lacks
  literal <- is.na(counts_as) & taxa %in% ex$names
  counts_as[literal] <- taxa[literal]

  # resolved taxa above an expert taxon (e.g. "Festuca ovina agg." for an
  # expert "Festuca ovina")
  ref_anc <- .resy_backbone_ancestors(ex$concept, bb$parent)
  above <- ref_anc[ref_anc$depth > 0L]
  above_of <- tapply(unname(ex$rep_of[above$concept]), above$ancestor,
                     function(x) paste(utils::head(unique(x), 3L), collapse = ", "))
  is_above <- is.na(counts_as) & !is.na(m$concept) & m$concept %in% names(above_of)
  coarse <- unname(bb$rank_of[m$concept]) %in% .resy_coarse_ranks

  # expert names without a backbone concept, by genus and epithet: plot taxa of
  # the same species cannot count for them
  stem <- function(x) sub("^(\\S+ \\S+).*$", "\\1", x)
  unresolved <- ex$names[is.na(ex$concept)]
  unresolved_of <- tapply(unresolved, stem(unresolved), paste, collapse = ", ")
  same_stem <- unname(unresolved_of[stem(taxa)])
  same_stem[is.na(same_stem)] <- unname(unresolved_of[stem(m$accepted[is.na(same_stem)])])

  ref_genera <- unique(sub(" .*", "", ex$names))
  # In a backbone restricted to the taxa of the expert system (the RESY App), a
  # name that is not found is outside those taxa; only one of the same genus
  # and epithet as an expert taxon may be a variant of it.
  if (isTRUE(bb$subset)) {
    near <- tapply(ex$names, stem(ex$names), paste, collapse = ", ")
    outside <- !is.na(m$issue) & m$issue == "not_found" & is.na(near[stem(taxa)])
    m$issue[outside] <- "outside_expert_taxa"
  }
  genus <- sub(" .*", "", sub("^(cf\\.?|aff\\.)\\s+", "", taxa, ignore.case = TRUE))
  relevant_genus <- genus %in% ref_genera

  status <- data.table::fcase(
    !is.na(counts_as), "matched",
    !is.na(m$issue), m$issue,
    is_above & !coarse, "broader_than_expert_taxon",
    is_above, "coarse_rank",
    !is.na(same_stem), "expert_taxon_not_in_backbone",
    default = "not_used")
  importance <- data.table::fcase(
    status %in% c("matched", "not_used"), NA_character_,
    status == "uncertain_determination", "unimportant",
    status == "broader_than_expert_taxon", "important",
    status == "expert_taxon_not_in_backbone", "important",
    status == "coarse_rank", "unimportant",
    status == "outside_expert_taxa", "unimportant",
    relevant_genus, "important",
    default = "unimportant")
  reason <- data.table::fcase(
    status == "uncertain_determination", "cf./aff./? record: ignored",
    status == "broader_than_expert_taxon",
    paste0("broader than expert taxon ", above_of[m$concept], ": not counted"),
    status == "coarse_rank", "genus or higher rank: not counted",
    status == "outside_expert_taxa", "not among the taxa of the expert system",
    status == "expert_taxon_not_in_backbone",
    paste0("expert taxon ", same_stem, " has no backbone concept: not counted"),
    status == "level_unclear", "extent (s. l./agg./s. str.) not determinable in the backbone",
    status == "misapplied_name", "misapplied name (auct.): no concept",
    status == "not_found" & relevant_genus, "not in the backbone; genus used by the expert system",
    status == "not_found", "not in the backbone; genus not used by the expert system",
    default = NA_character_)
  data.frame(
    scientificName = taxa,
    TaxonName      = counts_as,
    matched        = status %in% c("matched", "not_used"),
    backbone_name  = m$accepted,
    match          = m$match,
    status         = status,
    importance     = importance,
    reason         = reason,
    stringsAsFactors = FALSE
  )
}

# Classification input for an expert system with a backbone: plot taxa renamed
# to the expert taxon they count as, and the expert system with each species
# group and species condition widened to the expert taxa below it in the
# backbone tree. Returns `obs`, `parsed` and the plot taxon table (`taxa`).
.resy_backbone_apply <- function(obs, parsed, source = getOption("resy.backbone")) {
  bb <- .resy_backbone_get(parsed$backbone$name, source)
  ex <- .resy_backbone_expert(parsed, bb)
  taxa <- .resy_backbone_plot_taxa(obs$TaxonName, ex, bb)
  i <- fastmatch::fmatch(obs$TaxonName, taxa$scientificName)
  hit <- !is.na(i) & !is.na(taxa$TaxonName[i])
  obs$TaxonName[hit] <- taxa$TaxonName[i[hit]]

  is_header <- startsWith(names(parsed$groups), "$$")
  parsed$groups[!is_header] <- lapply(parsed$groups[!is_header], function(g)
    unique(c(g, unlist(ex$sets[intersect(trimws(g), names(ex$sets))], use.names = FALSE))))
  parsed$species_sets <- ex$sets
  list(obs = obs, parsed = parsed, taxa = taxa, version = bb$version)
}

# The plot taxon table as a resy_taxa object.
.resy_backbone_taxa_table <- function(taxa, input_col, backbone) {
  .resy_taxa(
    taxa, input_col = input_col, name_col = "scientificName",
    columns = c(
      scientificName = "Name as submitted",
      TaxonName      = "Expert taxon it counts as; NA if none",
      matched        = "FALSE if the name could not be matched in a usable way",
      status         = "matched, not_used (not in the expert system) or why not matched",
      importance     = "For names not matched: potentially important or probably unimportant"
    ),
    reference = sprintf("matched against the taxonomic backbone %s%s", backbone$name,
                        if (!is.na(backbone$version %||% NA)) paste0(" ", backbone$version) else "")
  )
}

# One-line account of the plot taxa that do not count for any expert taxon.
.resy_backbone_message <- function(taxa) {
  imp <- taxa$importance
  n_imp <- sum(imp %in% "important")
  n_un <- sum(imp %in% "unimportant")
  if (!n_imp && !n_un) return(invisible())
  message(sprintf(paste0(
    "%d plot taxon name(s) not matched to the backbone in a way the expert ",
    "system can use: %d potentially important, %d probably unimportant. ",
    "See `taxon_resolution` of the result or resy_check_taxonomy()."), n_imp + n_un, n_imp, n_un))
}
