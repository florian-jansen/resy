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

  aggs        <- parsed$aggs
  canon_names <- names(aggs)

  # Build lookup: synonym -> canonical, canonical -> itself
  synonyms <- unlist(aggs, use.names = FALSE)
  sources  <- rep(canon_names, lengths(aggs))
  lookup   <- c(
    stats::setNames(sources,     synonyms),
    stats::setNames(canon_names, canon_names)
  )
  lookup <- lookup[!duplicated(names(lookup))]

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
  cat(sprintf("%d name(s): %d matched (%s), %d unmatched (%s)\n",
              x$n, x$matched, .resy_pct(x$matched, x$n),
              x$unmatched, .resy_pct(x$unmatched, x$n)))
  if (x$unmatched > 0L) {
    cat("Unmatched names:\n")
    cat(paste0("  ", x$unmatched_names), sep = "\n")
  }
  invisible(x)
}

.resy_pct <- function(k, n) {
  if (n == 0L) "0%" else sprintf("%.1f%%", 100 * k / n)
}
