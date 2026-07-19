#' Calculate Total Cover from Individual Cover Values
#'
#' @description
#' Computes the total coverage from a vector of individual cover percentages,
#' accounting for overlapping coverage between species or layers. Uses the
#' complement method: total cover = 1 - (product of complements).
#'
#' @details
#' This function is designed for use with vegetation plot data where multiple
#' species or layers can overlap. Instead of simple addition, which would
#' overestimate total cover, this function uses the mathematical complement
#' formula:
#'
#' Total Cover = (1 - ∏(1 - cover_i/100)) × 100
#'
#' This approach is standard in vegetation science for combining cover values
#' from different species or strata where overlapping coverage exists.
#'
#' The result is rounded to 10 decimal places to minimize floating-point
#' arithmetic artifacts.
#'
#' @param x numeric vector of cover values (0-100), typically representing
#'   individual species or layer coverage percentages in a vegetation plot.
#'
#' @return numeric scalar representing the total cover percentage (0-100),
#'   rounded to 10 decimal places.
#'
#' @keywords internal
#'
#' @examples
#' # Single species
#' .total_cover(50)
#'
#' # Two species with overlapping coverage
#' .total_cover(c(50, 30))
#'
#' # Multiple species with various coverages
#' .total_cover(c(60, 40, 20))
#'
.total_cover <- function(x) round((1 - prod(1 - x/100)) * 100, 10)