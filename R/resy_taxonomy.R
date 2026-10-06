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
#' Loads the shipped table of alternate species names mapped to their canonical
#' ESy name. Each synonym is an alternate string a plot dataset might carry, keyed
#' to the canonical ESy species it resolves to; \code{source} records the taxonomic
#' backbone(s) that support the pairing (\code{;}-separated when more than one).
#' The shipped table also has an \code{accepted_in} column: the backbones that list
#' the synonym as an accepted name under the same author as the synonym rows
#' supporting the pair. A backbone appears in both \code{source} and
#' \code{accepted_in} when it holds an accepted row and a synonym row for the
#' name. The column is empty when no backbone accepts the name. The shipped
#' synonyms are binomials (genus and species epithet); infraspecific
#' names, hybrid formulas, and bare genera are not in it. Its build date and the
#' version of each backbone are recorded in
#' \code{inst/extdata/esy_synonyms_build.csv} and
#' \code{inst/extdata/esy_synonyms_backbones.csv}.
#' Pass \code{path = NULL} for the shipped table, a file path for a user CSV, or a
#' data frame to validate one already in memory.
#'
#' @param path \code{NULL} (default) loads the shipped
#'   \code{inst/extdata/esy_synonyms.csv.xz}. A character path loads a user CSV
#'   (optionally \code{.gz}/\code{.xz}) with the same schema. A data frame is
#'   validated and returned unchanged.
#' @return A data frame with columns \code{synonym}, \code{esy_canonical}, and
#'   \code{source}, and \code{accepted_in} when the table has it.
#' @seealso \code{\link{resy_resolve_taxa}}, \code{\link{resy_canonical_species}}
#' @export
resy_read_synonyms <- function(path = NULL) {
  if (is.data.frame(path)) return(.resy_validate_synonyms(path))
  if (is.null(path)) {
    sys_path <- system.file("extdata", "esy_synonyms.csv.xz", package = "RESY")
    if (!nzchar(sys_path)) {
      stop("resy_read_synonyms: shipped synonym table not found at ",
           "inst/extdata/esy_synonyms.csv.xz. Pass a file path or a data frame.",
           call. = FALSE)
    }
    path <- sys_path
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

#' Export the canonical ESy species list
#'
#' Returns the canonical ESy species names -- the set the expert system aggregates
#' over, and the target column a user builds a translation table against. Also the
#' authority used by \code{\link{resy_resolve_taxa}} for the exact-match step.
#'
#' @param path \code{NULL} (default) loads the shipped
#'   \code{inst/extdata/esy_canonical.csv.xz}. A character path or data frame
#'   (with an \code{esy_canonical} column) reads the canonical names from an
#'   override instead.
#' @return A sorted character vector of unique canonical ESy species names.
#' @seealso \code{\link{resy_read_synonyms}}, \code{\link{resy_resolve_taxa}}
#' @export
resy_canonical_species <- function(path = NULL) {
  if (is.data.frame(path)) {
    if (!"esy_canonical" %in% names(path)) {
      stop("resy_canonical_species: data frame needs an `esy_canonical` column.",
           call. = FALSE)
    }
    return(sort(unique(.resy_normalize_name(as.character(path$esy_canonical)))))
  }
  if (is.null(path)) {
    path <- system.file("extdata", "esy_canonical.csv.xz", package = "RESY")
    if (!nzchar(path)) {
      stop("resy_canonical_species: shipped canonical list not found at ",
           "inst/extdata/esy_canonical.csv.xz.", call. = FALSE)
    }
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
#' @param species_col Name of the column in \code{obs} holding the species name
#'   (default \code{"TaxonName"}).
#' @param synonyms \code{NULL} (default) uses the shipped synonym table; pass a
#'   path or data frame to override it.
#' @param canonical \code{NULL} (default) uses the shipped canonical list for the
#'   exact-match step; pass a path, a data frame, or a character vector of names
#'   to override it (\code{\link{resy_classify}} passes the expert system's own
#'   vocabulary here, so any name the expert already knows is left untouched).
#' @return A \code{resy_taxa} data frame: \code{obs} with three appended columns,
#'   \code{canonical} (the resolved ESy name, \code{NA} when unresolved),
#'   \code{taxon_confidence} (\code{"exact"}, \code{"synonym"},
#'   \code{"cleaned_exact"}, \code{"cleaned_synonym"}, or \code{"unresolved"}),
#'   and \code{matched} (\code{TRUE} unless unresolved).
#' @seealso \code{\link{resy_read_synonyms}}, \code{\link{resy_check_taxonomy}},
#'   \code{\link{resy_classify}}
#' @export
resy_resolve_taxa <- function(obs, species_col = "TaxonName",
                              synonyms = NULL, canonical = NULL) {
  if (!is.data.frame(obs)) {
    stop("resy_resolve_taxa: `obs` must be a data frame.", call. = FALSE)
  }
  if (!is.character(species_col) || length(species_col) != 1L ||
      !species_col %in% names(obs)) {
    stop("resy_resolve_taxa: column `", species_col, "` not found in `obs`.",
         call. = FALSE)
  }
  # A character vector of length > 1 is taken as the canonical names directly;
  # NULL / a single path / a data frame are read via resy_canonical_species().
  canon <- if (is.character(canonical) && length(canonical) > 1L) {
    .resy_normalize_name(canonical)
  } else {
    resy_canonical_species(canonical)
  }
  lookup <- .resy_synonym_lookup(resy_read_synonyms(synonyms))

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
