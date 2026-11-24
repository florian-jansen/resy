# Taxonomy name resolution: map plot species names -- as they arrive from any
# major backbone (GBIF, WFO, POWO, Euro+Med, ITIS, NCBI, national checklists) --
# to the canonical ESy species names the expert system aggregates over. A name is
# matched as given (exact, then synonym table); names still unmatched are matched
# again with author citations removed by resy_clean_names(). Input that matches
# nothing stays NA and is flagged; it is never replaced with a best guess.

# Required schema for the synonym table.
.RESY_SYNONYM_COLUMNS <- c("synonym", "esy_canonical", "source")

# Optional column, carried when present (the shipped table has it).
.RESY_SYNONYM_OPTIONAL <- "accepted_in"

# Whitespace-normalise a taxon name for matching (trim + collapse runs). No case
# folding: ESy names are properly cased and folding risks false merges.
.resy_normalize_name <- function(x) gsub("\\s+", " ", trimws(x))

#' Read the taxonomy synonym table
#'
#' Returns the table of alternate species names mapped to the species names of an
#' expert system. Each row is a synonym pair: an alternate string a plot dataset
#' might carry, keyed to the name of the expert system it resolves to;
#' \code{source} records the taxonomic backbone(s) that support the synonym pair
#' (\code{;}-separated when more than one).
#'
#' RESY ships one synonym layer for all expert systems and all their releases:
#' the synonym pairs of six taxonomic backbones (Euro+Med, WFO, GBIF, COL, ITIS,
#' NCBI). With \code{path = NULL}, the layer is anchored on the expert system
#' given in \code{expert}, so each release gets a table that fits its own species
#' names:
#' \itemize{
#'   \item A pair is kept when its target is a name the expert system evaluates:
#'     an aggregate name of Section 1, or a species that a species group or a
#'     membership condition names and that no aggregate absorbs.
#'   \item A synonym with more than one such target is resolved by Euro+Med, the
#'     taxonomy of the EUNIS expert system. Its single answer is kept; otherwise
#'     the synonym is dropped.
#'   \item A name the expert system already uses is never remapped.
#'   \item A synonym that Euro+Med accepts as a species is kept only when it is
#'     the same Euro+Med concept as its target (an orthographic or gender
#'     variant).
#' }
#' The anchored table is kept for the rest of the session.
#'
#' The table also has an \code{accepted_in} column: the backbones that list the
#' synonym as an accepted name under the same author as the synonym rows
#' supporting the synonym pair. A backbone appears in both \code{source} and
#' \code{accepted_in} when it holds an accepted row and a synonym row for the
#' name. The column is empty when no backbone accepts the name. The synonyms are
#' binomials (genus and species epithet); infraspecific names, hybrid formulas,
#' and bare genera are not in it. The build date of the layer and the version of
#' each backbone are recorded in \code{inst/extdata/esy_synonym_layer_build.csv} and
#' \code{inst/extdata/esy_synonym_layer_backbones.csv}.
#'
#' @param path \code{NULL} (default) anchors the shipped synonym layer on
#'   \code{expert}. A character path loads a user CSV (optionally
#'   \code{.gz}/\code{.xz}) with the same schema. A data frame is validated and
#'   returned unchanged.
#' @param expert An expert system read with \code{\link{resy_load_expert}}, used
#'   when \code{path = NULL}. \code{NULL} (default) uses the newest EUNIS release,
#'   the expert system \code{resy_load_expert()} reads by default.
#' @return A data frame with columns \code{synonym}, \code{esy_canonical}, and
#'   \code{source}, and \code{accepted_in} when the table has it.
#' @seealso \code{\link{resy_resolve_taxa}}, \code{\link{resy_canonical_species}}
#' @examples
#' synonyms <- resy_read_synonyms()
#' head(synonyms)
#' @export
resy_read_synonyms <- function(path = NULL, expert = NULL) {
  if (is.data.frame(path)) return(.resy_validate_synonyms(path))
  if (is.null(path)) {
    return(.resy_expert_synonyms(expert %||% resy_load_expert()))
  }
  if (!is.character(path) || length(path) != 1L) {
    stop("resy_read_synonyms: `path` must be NULL, a single character path, ",
         "or a data frame.", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("resy_read_synonyms: file not found: ", path, call. = FALSE)
  }
  df <- utils::read.csv(path, stringsAsFactors = FALSE,
                        na.strings = c("", "NA"), encoding = "UTF-8")
  .resy_validate_synonyms(df)
}

.resy_validate_synonyms <- function(df) {
  if (!is.data.frame(df)) {
    stop("synonym table must be a data frame.", call. = FALSE)
  }
  missing <- setdiff(.RESY_SYNONYM_COLUMNS, names(df))
  if (length(missing) > 0L) {
    stop("synonym table: missing required column(s): ",
         paste(missing, collapse = ", "), ".", call. = FALSE)
  }
  keep <- c(.RESY_SYNONYM_COLUMNS, intersect(.RESY_SYNONYM_OPTIONAL, names(df)))
  for (col in keep) df[[col]] <- as.character(df[[col]])
  df[, keep, drop = FALSE]
}

# Species named in groups and membership conditions.
# Values of header groups ($$C, $$N) are not species names.
.resy_expert_used <- function(parsed) {
  norm <- .resy_normalize_name
  is_header <- startsWith(names(parsed$groups), "$$")
  header_values <- norm(unlist(parsed$groups[is_header], use.names = FALSE))
  group_members <- norm(unlist(parsed$groups[!is_header], use.names = FALSE))

  cond <- trimws(parsed$conditions)
  cond <- trimws(sub("^NON ", "", cond))
  cond <- cond[!startsWith(cond, "$")]
  sides <- trimws(unlist(strsplit(cond, "EXCEPT", fixed = TRUE), use.names = FALSE))
  tok <- norm(.resy_membership_parts(sides[nzchar(sides)]))
  tok <- tok[!startsWith(tok, "#") & !startsWith(tok, "$") &
               is.na(match(tok, parsed$groups.names))]

  used <- setdiff(unique(c(group_members, tok)), header_values)
  used[!is.na(used) & nzchar(used)]
}

# Species names an expert system uses. `vocab` holds every name it knows: the
# aggregate names of Section 1 with their members, the members of the species
# groups of Section 2, and the species named directly in membership conditions.
# `targets` holds the names the classifier evaluates as themselves: the
# aggregate names, and the group or condition names that no aggregate absorbs.
.resy_expert_names <- function(parsed, mapping = TRUE) {
  agg_names <- .resy_normalize_name(names(parsed$aggs))
  agg_members <- .resy_normalize_name(unlist(parsed$aggs, use.names = FALSE))
  used <- .resy_expert_used(parsed)
  targets <- unique(c(agg_names, setdiff(used, agg_members)))
  if (!mapping) return(list(targets = targets))
  vocab <- unique(c(agg_names, agg_members, used))

  # The name each vocabulary name is evaluated as: a target as itself, an
  # aggregate member as its aggregate. A member of several aggregates keeps its
  # own name.
  agg_of <- rep(agg_names, lengths(parsed$aggs))
  first <- !duplicated(paste(agg_members, agg_of, sep = "\r"))
  in_several <- unique(agg_members[first][duplicated(agg_members[first])])
  evaluated_as <- vocab
  is_member <- !vocab %in% targets & vocab %in% agg_members & !vocab %in% in_several
  evaluated_as[is_member] <- agg_of[match(vocab[is_member], agg_members)]
  names(evaluated_as) <- vocab
  list(targets = targets, vocab = vocab, evaluated_as = evaluated_as)
}

# The synonym layer: synonym pairs harvested from the taxonomic backbones,
# independent of any expert system. Read once per session.
.resy_synonym_cache <- new.env(parent = emptyenv())

.resy_synonym_layer <- function() {
  if (is.null(.resy_synonym_cache$layer)) {
    path <- system.file("extdata", "esy_synonym_layer.csv.xz", package = "RESY")
    if (!nzchar(path)) {
      stop("shipped synonym layer not found at ",
           "inst/extdata/esy_synonym_layer.csv.xz.", call. = FALSE)
    }
    layer <- utils::read.csv(path, stringsAsFactors = FALSE,
                             na.strings = c("", "NA"), encoding = "UTF-8")
    layer$sc_drop <- as.logical(layer$sc_drop)
    .resy_synonym_cache$layer <- layer
  }
  .resy_synonym_cache$layer
}

# Anchor the synonym layer on the names of one expert system (`nm`, from
# .resy_expert_names()). A synonym is ambiguous when its targets among the
# names the expert system knows are evaluated as more than one name; Euro+Med,
# the authority the EUNIS expert system follows, resolves it when its own
# targets are evaluated as a single name, otherwise the synonym is dropped. Kept
# are pairs whose target is a name the classifier evaluates. A synonym the
# expert system knows is never remapped, and a synonym that Euro+Med accepts as
# a species of a different concept than the target (`sc_drop`) is dropped.
.resy_anchor_synonyms <- function(layer, nm) {
  p <- layer[!is.na(fastmatch::fmatch(layer$target, nm$vocab)), , drop = FALSE]
  s <- p$synonym
  ev <- unname(nm$evaluated_as[p$target])
  # Synonyms whose rows `sel` are evaluated as more than one name.
  several <- function(sel) {
    ss <- s[sel]
    ss <- ss[!duplicated(paste(ss, ev[sel], sep = "\r"))]
    unique(ss[duplicated(ss)])
  }
  ambiguous <- s %in% several(rep(TRUE, length(s)))
  em <- ambiguous & grepl("euromed", p$source, fixed = TRUE)
  em_single <- setdiff(s[em], several(em))
  keep <- (!ambiguous | (em & s %in% em_single)) &
    !is.na(fastmatch::fmatch(p$target, nm$targets)) &
    is.na(fastmatch::fmatch(s, nm$vocab)) & !p$sc_drop
  p <- p[keep, , drop = FALSE]
  out <- data.frame(synonym = p$synonym, esy_canonical = p$target,
                    source = p$source, accepted_in = p$accepted_in,
                    stringsAsFactors = FALSE)
  out <- out[order(out$esy_canonical, out$synonym, method = "radix"), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# The synonym table of one expert system, anchored once per session and expert.
.resy_expert_synonyms <- function(parsed) {
  key <- rlang::hash(parsed[c("aggs", "groups", "groups.names", "conditions")])
  hit <- .resy_synonym_cache$anchored[[key]]
  if (!is.null(hit)) return(hit)
  out <- .resy_anchor_synonyms(.resy_synonym_layer(), .resy_expert_names(parsed))
  .resy_synonym_cache$anchored[[key]] <- out
  out
}

# Build a normalised synonym -> canonical lookup. Ambiguous synonyms (one string
# mapping to more than one canonical name) are dropped so they never resolve
# silently; the shipped table is already free of these, this guards user tables.
.resy_synonym_lookup <- function(syn) {
  key <- .resy_normalize_name(syn$synonym)
  canon <- .resy_normalize_name(syn$esy_canonical)
  ok <- !is.na(key) & nzchar(key) & !is.na(canon) & nzchar(canon)
  key <- key[ok]; canon <- canon[ok]
  ambiguous <- key %in% key[duplicated(key) & !duplicated(data.frame(key, canon))]
  keep <- !ambiguous & !duplicated(key)
  data.frame(key = key[keep], canonical = canon[keep], stringsAsFactors = FALSE)
}

# Match normalised names against the canonical vocabulary (exact) and the synonym
# lookup. Returns the canonical name (NA when unmatched) and the confidence label
# per element.
.resy_match_taxa <- function(probe, canon, lookup) {
  resolved <- rep(NA_character_, length(probe))
  conf <- rep("unresolved", length(probe))

  is_exact <- probe %in% canon
  resolved[is_exact] <- probe[is_exact]
  conf[is_exact] <- "exact"

  miss <- !is_exact
  hit <- lookup$canonical[match(probe[miss], lookup$key)]
  resolved[miss] <- hit
  conf[miss][!is.na(hit)] <- "synonym"

  list(canonical = resolved, confidence = conf)
}

#' Export the canonical species names of an expert system
#'
#' Returns the canonical species names of an expert system: the names its
#' classifier evaluates, which is the target column a user builds a translation
#' table against. These are the aggregate names of Section 1, and the species
#' that a species group or a membership condition names and that no aggregate
#' absorbs.
#'
#' @param path \code{NULL} (default) takes the canonical names from
#'   \code{expert}. A character path or data frame (with an \code{esy_canonical}
#'   column) reads the canonical names from an override instead.
#' @param expert An expert system read with \code{\link{resy_load_expert}}, used
#'   when \code{path = NULL}. \code{NULL} (default) uses the newest EUNIS release.
#' @return A sorted character vector of unique canonical species names.
#' @seealso \code{\link{resy_read_synonyms}}, \code{\link{resy_resolve_taxa}}
#' @examples
#' canonical <- resy_canonical_species()
#' head(canonical)
#' @export
resy_canonical_species <- function(path = NULL, expert = NULL) {
  if (is.data.frame(path)) {
    if (!"esy_canonical" %in% names(path)) {
      stop("resy_canonical_species: data frame needs an `esy_canonical` column.",
           call. = FALSE)
    }
    return(sort(unique(.resy_normalize_name(as.character(path$esy_canonical)))))
  }
  if (is.null(path)) {
    return(sort(.resy_expert_names(expert %||% resy_load_expert())$targets))
  }
  if (!is.character(path) || length(path) != 1L || !file.exists(path)) {
    stop("resy_canonical_species: `path` must be NULL, an existing file, ",
         "or a data frame.", call. = FALSE)
  }
  df <- utils::read.csv(path, stringsAsFactors = FALSE,
                        na.strings = c("", "NA"), encoding = "UTF-8")
  if (!"esy_canonical" %in% names(df)) {
    stop("resy_canonical_species: file needs an `esy_canonical` column.",
         call. = FALSE)
  }
  sort(unique(.resy_normalize_name(as.character(df$esy_canonical))))
}

#' Resolve plot species names to canonical ESy names
#'
#' Maps a column of plot species names to the canonical ESy names used by the
#' expert system, so the result can be classified with \code{\link{resy_classify}}
#' without hand-harmonising names. A name already equal to a canonical ESy name
#' resolves to itself (\code{"exact"}); otherwise it is looked up in the synonym
#' table (\code{"synonym"}). A name that matches neither as given is tried again
#' with its author citation removed by \code{\link{resy_clean_names}}
#' (\code{"cleaned_exact"}, \code{"cleaned_synonym"}); the cleaned form is used
#' only for matching, so a name is never altered when it already matches. A name
#' that still matches nothing is left \code{NA} and flagged \code{"unresolved"};
#' it is never replaced with a best guess.
#'
#' The synonym table pools synonymy from six backbones (Euro+Med, WFO, GBIF, COL,
#' ITIS, NCBI), so plot data named under any of them resolves without the caller
#' needing to say which backbone the names came from.
#'
#' The result is a \code{resy_taxa} data frame, the same class
#' \code{\link{resy_check_taxonomy}} returns. Printing it shows what each column
#' holds and how many distinct names resolved; \code{summary()} returns the
#' counts per name and per record, the records by match type, and the names that
#' stayed unresolved.
#'
#' @param obs A data frame (or \code{data.table}) of plot observations.
#' @param species_col Name of the column in \code{obs} holding the species name.
#'   If \code{NULL} (default), uses \code{TaxonName}, then Darwin Core
#'   \code{scientificName}.
#' @param synonyms \code{NULL} (default) uses the shipped synonym layer anchored
#'   on \code{expert} (see \code{\link{resy_read_synonyms}}); pass a path or data
#'   frame to override it.
#' @param canonical \code{NULL} (default) uses every species name in
#'   \code{expert} for the exact-match step, so a name the expert system already uses is
#'   left untouched; pass a path, a data frame, or a character vector of names to
#'   override it.
#' @param expert An expert system read with \code{\link{resy_load_expert}}, whose
#'   species names the plot names are resolved to. \code{NULL} (default) uses the
#'   newest EUNIS release. Not read when both \code{synonyms} and
#'   \code{canonical} are given.
#' @return A \code{resy_taxa} data frame: \code{obs} with three appended columns,
#'   \code{canonical} (the resolved ESy name, \code{NA} when unresolved),
#'   \code{taxon_confidence} (\code{"exact"}, \code{"synonym"},
#'   \code{"cleaned_exact"}, \code{"cleaned_synonym"}, or \code{"unresolved"}),
#'   and \code{matched} (\code{TRUE} unless unresolved).
#' @seealso \code{\link{resy_read_synonyms}}, \code{\link{resy_check_taxonomy}},
#'   \code{\link{resy_classify}}
#' @examples
#' obs <- data.frame(
#'   PlotObservationID = c("p1", "p2"),
#'   TaxonName = c("Quercus robur", "Poa annua")
#' )
#'
#' resolved <- resy_resolve_taxa(obs, species_col = "TaxonName")
#' resolved[, c("PlotObservationID", "TaxonName", "canonical", "taxon_confidence", "matched")]
#' @export
resy_resolve_taxa <- function(
    obs, species_col = NULL, synonyms = NULL, canonical = NULL, expert = NULL
    ) {

  if (!is.data.frame(obs)) {
    stop("resy_resolve_taxa: `obs` must be a data frame.", call. = FALSE)

  }

  if (!is.null(species_col) &&
      (!is.character(species_col) || length(species_col) != 1L)) {
    stop("resy_resolve_taxa: `species_col` must be a single column name.",
         call. = FALSE)
  }
  species_col <- .resy_species_col(obs, species_col)
  
  if (is.null(expert) && (is.null(synonyms) || is.null(canonical))) {
    expert <- resy_load_expert()
  }
  # A character vector of length > 1 is taken as the canonical names directly;
  # a single path or a data frame is read via resy_canonical_species().
  canon <- if (is.null(canonical)) {
    .resy_expert_names(expert)$vocab
  } else if (is.character(canonical) && length(canonical) > 1L) {
    .resy_normalize_name(canonical)
  } else {
    resy_canonical_species(canonical)
  }
  lookup <- .resy_synonym_lookup(resy_read_synonyms(synonyms, expert = expert))

  raw <- as.character(obs[[species_col]])
  probe <- .resy_normalize_name(raw)

  m <- .resy_match_taxa(probe, canon, lookup)
  resolved <- m$canonical
  conf <- m$confidence
  is_exact <- conf == "exact"
  resolved[is_exact] <- raw[is_exact]   # keep the original string for passthrough

  # Names still unmatched are matched once more with author citations removed.
  # Only the unique unmatched strings are cleaned, and only for matching: a name
  # that already matched is never altered.
  todo <- which(conf == "unresolved" & !is.na(probe))
  if (length(todo) > 0L) {
    uniq <- unique(probe[todo])
    cleaned <- resy_clean_names(uniq)
    changed <- cleaned != uniq
    m2 <- .resy_match_taxa(cleaned[changed], canon, lookup)
    pos <- match(probe[todo], uniq[changed])
    hit2 <- m2$canonical[pos]
    sel <- !is.na(hit2)
    resolved[todo[sel]] <- hit2[sel]
    conf[todo[sel]] <- paste0("cleaned_", m2$confidence[pos][sel])
  }

  out <- as.data.frame(obs, stringsAsFactors = FALSE)
  out$canonical <- resolved
  out$taxon_confidence <- conf
  out$matched <- conf != "unresolved"
  columns <- c("name as submitted",
               "resolved canonical name; NA when unresolved",
               "exact, synonym, cleaned_exact, cleaned_synonym or unresolved",
               "TRUE if the name resolved")
  names(columns) <- c(species_col, "canonical", "taxon_confidence", "matched")
  .resy_taxa(out, input_col = species_col, name_col = species_col,
             columns = columns,
             reference = sprintf("resolved against %d reference names",
                                 length(canon)))
}
