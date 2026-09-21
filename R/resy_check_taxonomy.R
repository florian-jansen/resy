#' Check species names against an expert system's species list
#'
#' @description
#' Validates taxon names in a plot observation table against the canonical
#' names and synonyms declared in Section 1 of the loaded expert system.
#' Returns a per-taxon table of matches and canonical name mappings.
#'
#' This is a purely offline check; no external name-resolution service is
#' called.
#'
#' The result is a `resy_taxa` data frame. Printing it shows what each column
#' holds and how many names matched; [summary()] returns the match counts and
#' the unmatched names.
#'
#' @param obs A data frame or `data.table` with a column holding taxon names.
#' @param parsed A `resy_parsed_expert` object from [resy_load_expert()].
#' @param col Name of the column in `obs` that holds taxon names
#'   (default `"TaxonName"`).
#' @return A `resy_taxa` data frame with one row per unique taxon name in `obs`:
#'   \describe{
#'     \item{`scientificName`}{The name as submitted in `obs`.}
#'     \item{`TaxonName`}{The canonical name used by [resy_classify()], or `NA`
#'       when unmatched.}
#'     \item{`matched`}{`TRUE` if the name was found as a canonical name or
#'       synonym in Section 1 of the expert system.}
#'   }
#' @seealso [resy_load_expert()], [resy_harmonize_eunis()]
#' @examples
#' parsed <- resy_load_expert(scheme = "Apennine-test")
#'
#' obs <- data.frame(
#'   PlotObservationID = c("p1", "p1", "p2"),
#'   TaxonName = c("Fagus sylvatica",     # canonical name
#'                 "Abies alba Mill.",    # listed synonym of "Abies alba"
#'                 "Planta inventa")      # unknown to the expert system
#' )
#' checked <- resy_check_taxonomy(obs, parsed)
#' checked
#' summary(checked)
#'
#' # Names held in a differently named column
#' names(obs)[2] <- "species"
#' resy_check_taxonomy(obs, parsed, col = "species")
#' @export
resy_check_taxonomy <- function(obs, parsed, col = "TaxonName") {
  if (!inherits(parsed, "resy_parsed_expert"))
    stop("`parsed` must be a resy_parsed_expert object (from resy_load_expert()).")
  if (!col %in% names(obs))
    stop("Column '", col, "' not found in `obs`.")

  canon_names <- names(parsed$aggs)
  lookup      <- .resy_agg_lookup(parsed$aggs)

  taxa      <- unique(as.character(obs[[col]]))
  taxa      <- taxa[!is.na(taxa)]
  matched   <- taxa %in% names(lookup)
  canonical <- lookup[taxa]
  canonical[!matched] <- NA_character_

  out <- data.frame(
    scientificName = taxa,
    TaxonName      = unname(canonical),
    matched        = matched,
    stringsAsFactors = FALSE
  )
  .resy_taxa(out, input_col = col, n_expert = length(canon_names))
}

# Column descriptions of a resy_taxa table, shown in the print header.
.resy_taxa_columns <- c(
  scientificName = "name as submitted",
  TaxonName      = "canonical name used by resy_classify(); NA when unmatched",
  matched        = "TRUE if found as a canonical name or Section 1 synonym"
)

.resy_taxa <- function(df, input_col, n_expert) {
  attr(df, "input_col") <- input_col
  attr(df, "n_expert")  <- n_expert
  class(df) <- c("resy_taxa", "data.frame")
  df
}

#' @export
print.resy_taxa <- function(x, n = 10L, ...) {
  s <- summary(x)
  cat(sprintf(
    "<resy_taxa> %d name(s) from column `%s` checked against %d Section 1 species\n",
    s$n, attr(x, "input_col"), attr(x, "n_expert")))
  cols <- intersect(names(.resy_taxa_columns), names(x))
  w <- max(nchar(cols))
  cat(sprintf("  %-*s  %s\n", w, cols, .resy_taxa_columns[cols]), sep = "")
  cat(sprintf("%d matched (%s), %d unmatched",
              s$matched, .resy_pct(s$matched, s$n), s$unmatched))
  cat(if (s$unmatched > 0L) "; summary() lists them\n\n" else "\n\n")
  shown <- as.data.frame(unclass(x)[cols], stringsAsFactors = FALSE)
  print(utils::head(shown, n), ...)
  if (nrow(shown) > n) cat(sprintf("# ... %d more row(s)\n", nrow(shown) - n))
  invisible(x)
}

#' @export
summary.resy_taxa <- function(object, ...) {
  m <- as.logical(object$matched)
  n <- length(m)
  structure(
    list(
      n         = n,
      matched   = sum(m),
      unmatched = n - sum(m),
      unmatched_names = sort(as.character(object$scientificName[!m]))
    ),
    class = "summary.resy_taxa"
  )
}

#' @export
print.summary.resy_taxa <- function(x, ...) {
  cat(sprintf("%d names checked: %d matched (%s), %d not matched (%s).\n",
              x$n, x$matched, .resy_pct(x$matched, x$n),
              x$unmatched, .resy_pct(x$unmatched, x$n)))
  if (x$unmatched > 0L) {
    cat("\nNot matched:\n")
    kinds <- .resy_name_kind(x$unmatched_names)
    labels <- c(genus = "genus only", infraspecific = "below species level",
                species = "species")
    for (k in names(labels)) {
      nm <- x$unmatched_names[kinds == k]
      if (!length(nm)) next
      if (k == "genus") nm <- sub("\\s+spp?\\.?$", "", nm)
      cat(.resy_pack_names(sprintf("  %s (%d): ", labels[[k]], length(nm)), nm,
                           width = getOption("width"), exdent = 4L), sep = "\n")
    }
  }
  invisible(x)
}

# Lines of comma-separated names after `lead`, filled up to `width` characters
# without breaking a name across lines; continuation lines are indented by
# `exdent` spaces.
.resy_pack_names <- function(lead, names, width, exdent) {
  lines <- character()
  current <- lead
  fresh <- TRUE
  for (i in seq_along(names)) {
    item <- if (i < length(names)) paste0(names[i], ",") else names[i]
    candidate <- if (fresh) paste0(current, item) else paste(current, item)
    if (!fresh && nchar(candidate) > width) {
      lines <- c(lines, current)
      current <- paste0(strrep(" ", exdent), item)
    } else {
      current <- candidate
    }
    fresh <- FALSE
  }
  c(lines, current)
}

# What a taxon name names: a genus only ("Carex sp.", "Carex"), a taxon below
# species level ("Festuca rubra subsp. commutata", "... var. ..."), or a species.
.resy_name_kind <- function(names) {
  words <- lengths(strsplit(trimws(names), "\\s+"))
  genus <- words == 1L | grepl("\\s+spp?\\.?$", names)
  infra <- grepl("\\s(subsp|ssp|var|subvar|f|nothosubsp)\\.\\s", names)
  ifelse(genus, "genus", ifelse(infra, "infraspecific", "species"))
}

.resy_pct <- function(k, n) {
  if (n == 0L) "0%" else sprintf("%.1f%%", 100 * k / n)
}
