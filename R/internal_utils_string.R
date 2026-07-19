#' @keywords internal
trim.trailing <- function(x) sub("\\s+$|\\s+\\d$|\\s+\\-\\s+\\d$", "", x)

#' @keywords internal
trim.leading <- function(x)  sub("^\\s+", "", x)

#' @keywords internal
trim <- function(x) gsub("^\\s+|\\s+$", "", x)