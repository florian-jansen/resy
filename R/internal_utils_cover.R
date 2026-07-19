#' @keywords internal
.total_cover <- function(x) round((1 - prod(1 - x/100)) * 100, 10)