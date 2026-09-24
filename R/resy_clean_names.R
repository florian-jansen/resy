#' Remove taxonomic authorities from scientific names
#'
#' Strips author citations from scientific plant names while keeping the
#' taxonomic structure that expert-system names depend on, so that names from
#' different taxonomic backbones resolve against the canonical names and
#' synonyms of an expert system. The genus and species epithet are always kept.
#' Infraspecific rank markers (\code{subsp.}, \code{var.}, \code{f.}, ...) are
#' kept together with their epithet, and the \code{ssp.} abbreviation is
#' normalised to \code{subsp.}. Aggregate and collective markers
#' (\code{agg.}, \code{aggr.}, \code{coll.}, \code{s.l.}, \code{s.str.},
#' \code{s.lat.}) stand alone and are kept in place, including when they trail a
#' name with no following epithet (\code{"Taraxacum officinale agg."}) or follow
#' an infraspecific epithet (\code{"Aconitum napellus subsp. firmum s.l."}).
#' The \code{sensu lato} and \code{sensu stricto} qualifiers (in any of the
#' forms \code{s.l.}, \code{s. l.}, \code{sens. lat.}, \code{sensu lato}, the
#' \code{stricto} equivalents, and the compact \code{s.s.}) are normalised to
#' \code{s.l.} / \code{s.str.} and
#' kept; a \code{sensu <author>} concept attribution (for example
#' \code{"aggr. sensu Buser"}) is dropped, to match the bare form the expert
#' system uses as its canonical name. The hybrid sign (ASCII \code{x} or the
#' multiplication sign) is kept: for a nothospecies (\code{"Salix x rubens"}), a
#' leading nothogenus (\code{"x Ammocalamagrostis baltica"}), and a hybrid
#' formula joining two taxa (\code{"Betula pendula x pubescens"},
#' \code{"Elytrigia repens x Leymus arenarius"}), so a hybrid is never collapsed
#' onto one of its parents. Names with fewer than two words are returned
#' unchanged.
#'
#' @param x A character vector of scientific names, optionally carrying author
#'   citations (for example \code{"Fagus sylvatica L."}).
#' @return A character vector the same length as \code{x} with author citations
#'   removed and taxonomic structure preserved. \code{NA} values are preserved.
#' @examples
#' resy_clean_names(c(
#'   "Fagus sylvatica L.",
#'   "Epipactis helleborine (L.) Crantz subsp. helleborine",
#'   "Senecio ovatus (G.Gaertn., B.Mey. & Scherb.) Willd.",
#'   "Taraxacum officinale agg.",
#'   "Festuca ovina s. l.",
#'   "Alchemilla vulgaris aggr. sensu Buser",
#'   "Mentha x verticillata aggr."
#' ))
#' @export
resy_clean_names <- function(x) {
  # Infraspecific rank markers are followed by an epithet and kept with it.
  infra_ranks <- c("subsp.", "nothosubsp.", "nssp.", "var.", "f.", "cv.")
  # Aggregate and collective markers stand alone, denote a broader taxon
  # concept, and are kept as-is (usually terminal, sometimes after an epithet).
  agg_markers <- c("agg.", "aggr.", "coll.", "s.l.", "s.str.", "s.lat.")
  # Botanical hybrid sign: ASCII "x" or the multiplication sign (built with
  # intToUtf8 to keep this source file ASCII-only).
  hybrid_marks <- c("x", intToUtf8(215L))

  vapply(x, function(nm) {
    if (is.na(nm)) return(NA_character_)
    nm <- trimws(nm)
    # Normalise sensu-lato / sensu-stricto qualifiers to the compact marker so
    # they are kept, not dropped as a sensu-concept ("sens. lat." -> "s.l.",
    # "sensu stricto" -> "s.str.").
    nm <- gsub(
      "\\bsens(?:u|\\.)?\\s+lat(?:o|\\.)",    "s.l.",   nm,
      perl = TRUE, ignore.case = TRUE
      )
    nm <- gsub(
      "\\bsens(?:u|\\.)?\\s+str(?:icto|\\.)", "s.str.", nm,
      perl = TRUE, ignore.case = TRUE
      )
    # Collapse spaced sensu-lato abbreviations so they survive tokenisation as
    # a single marker ("s. l." -> "s.l.").
    nm <- gsub("\\bs\\.\\s+l\\.",   "s.l.",   nm, perl = TRUE)
    nm <- gsub("\\bs\\.\\s+lat\\.", "s.lat.", nm, perl = TRUE)
    nm <- gsub("\\bs\\.\\s+str\\.", "s.str.", nm, perl = TRUE)
    # Sensu stricto in the compact "s.s." / "s. s." form -> canonical "s.str.".
    nm <- gsub("\\bs\\.\\s*s\\.", "s.str.", nm, perl = TRUE)
    # The "ssp." abbreviation is the subspecies rank marker; normalise to the
    # canonical "subsp." so its epithet is kept by the infraspecific rule below.
    nm <- gsub("\\bssp\\.", "subsp.", nm, perl = TRUE)
    w <- strsplit(nm, "\\s+")[[1]]
    if (length(w) < 2L) return(nm)

    n <- length(w)
    # Establish the core genus + epithet, keeping the hybrid sign whether it is
    # a leading nothogenus sign ("x Ammocalamagrostis baltica") or sits between
    # genus and epithet in a nothospecies ("Salix x rubens").
    if (n >= 3L && (w[1L] %in% hybrid_marks || w[2L] %in% hybrid_marks)) {
      out <- w[1:3]
      i <- 4L
    } else {
      out <- w[1:2]
      i <- 3L
    }
    while (i <= n) {
      if (w[i] %in% infra_ranks && i < n) {
        out <- c(out, w[i], w[i + 1L])
        i <- i + 2L
      } else if (w[i] %in% agg_markers) {
        out <- c(out, w[i])
        i <- i + 1L
      } else if (w[i] %in% hybrid_marks && i < n) {
        # Hybrid formula connector joining a second taxon
        # ("Betula pendula x pubescens", "Elytrigia repens x Leymus arenarius").
        # An upper-case token after the sign is a second genus (keep it plus its
        # epithet); a lower-case token is a partner epithet of the same genus.
        if (grepl("^[A-Z]", w[i + 1L]) && i + 1L < n) {
          out <- c(out, w[i], w[i + 1L], w[i + 2L])
          i <- i + 3L
        } else {
          out <- c(out, w[i], w[i + 1L])
          i <- i + 2L
        }
      } else {
        # Author citation or sensu-concept token: drop it.
        i <- i + 1L
      }
    }
    paste(out, collapse = " ")
  }, character(1), USE.NAMES = FALSE)
}
