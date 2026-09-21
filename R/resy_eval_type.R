
#' Evaluate and print details for a vegetation type
#'
#' @description
#' Prints the definition of one vegetation type of the expert system used in
#' a classification: its full name, its membership formula as written in the
#' expert file, the compiled formula over membership-condition columns, and a
#' table of the membership conditions it refers to.
#'
#' @param res A `resy_result` returned by [resy_classify()].
#' @param t Vegetation-type short code (e.g. "R55") or numeric index.
#' @return `NULL`, invisibly. Called for the printed output; prints
#'   "Type not defined." when `t` is not a type code of the expert system.
#' @seealso [resy_eval_plot()], [resy_classify()]
#' @examples
#' \donttest{
#' species <- utils::read.csv(
#'   system.file("extdata", "data_example_species.csv", package = "RESY")
#' )
#' names(species)[names(species) == "species"] <- "TaxonName"
#' names(species)[names(species) == "cover"]   <- "Cover_Perc"
#' header <- as.data.frame(unique(species["PlotObservationID"]))
#'
#' res <- resy_classify(species, header, scheme = "Apennine-test", mc = 1L)
#'
#' # By short code or by position in the expert system
#' resy_eval_type(res, "FB")
#' resy_eval_type(res, 1)
#' }
#' @export
resy_eval_type <- function(res, t) {
  stopifnot(inherits(res, "resy_result"))
  vegtype.formula.names <- res$parsed$vegtype.formula.names
  vegtype.formula.names.short <- res$parsed$vegtype.formula.names.short
  vegtype.formulas <- res$parsed$vegtype.formulas
  vegtype.formulas.p <- res$parsed$vegtype.formulas.p
  membership.expressions <- res$parsed$membership.expressions
  groups <- res$parsed$groups
  
  if (is.character(t)) t <- fastmatch::fmatch(t, vegtype.formula.names.short)
  if (is.na(t)) {
    cat('Type not defined.\n')
    return(invisible(NULL))
  }
  
  cat(vegtype.formula.names[t], '\n\n', vegtype.formulas[t], '\n\n', vegtype.formulas.p[t], '\n\n', sep='')
  col <- unique(as.numeric(stringr::str_extract_all(vegtype.formulas.p[t], "(?<=col\\s{0,1})[-0-9.]+")[[1]]))
  print(data.frame(row.names = col, expressions = membership.expressions[col], check.names = FALSE), right = FALSE)
  
  # If there is a species group with same (normalized) name, print it.
  norm <- function(x) gsub('-| ', '', x)
  target <- norm(vegtype.formula.names[t])
  group_keys <- norm(substring(names(groups), 9))
  if (target %in% group_keys) {
    print(groups[[fastmatch::fmatch(target, group_keys)]])
  }
  
  invisible(NULL)
}
