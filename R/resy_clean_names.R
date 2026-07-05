#' Remove taxonomic authorities from scientific names
#'
#' Strips author citations from scientific plant names while keeping
#' infraspecific ranks (\code{subsp.}, \code{var.}, \code{f.}, ...), so that
#' names from different taxonomic backbones resolve against the canonical names
#' and synonyms of an expert system. The genus and species epithet are always
#' kept; when an infraspecific rank marker is present, the marker and its
#' epithet are kept too. Names with fewer than two words are returned unchanged.
#'
#' @param x A character vector of scientific names, optionally carrying author
#'   citations (for example \code{"Fagus sylvatica L."}).
#' @return A character vector the same length as \code{x} with author citations
#'   removed. \code{NA} values are preserved.
#' @examples
#' resy_clean_names(c(
#'   "Fagus sylvatica L.",
#'   "Epipactis helleborine (L.) Crantz subsp. helleborine",
#'   "Senecio ovatus (G.Gaertn., B.Mey. & Scherb.) Willd."
#' ))
#' @export
resy_clean_names <- function(x) {
  ranks <- c("subsp.", "nothosubsp.", "nssp.", "var.", "f.", "cv.", "agg.")
  vapply(x, function(nm) {
    if (is.na(nm)) return(NA_character_)
    w <- strsplit(trimws(nm), "\\s+")[[1]]
    if (length(w) < 2L) return(nm)
    out <- w[1:2]
    ri <- which(w %in% ranks)
    if (length(ri) && ri[1] < length(w)) out <- c(out, w[ri[1]], w[ri[1] + 1L])
    paste(out, collapse = " ")
  }, character(1), USE.NAMES = FALSE)
}
