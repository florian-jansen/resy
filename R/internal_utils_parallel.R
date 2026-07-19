#' @keywords internal
.resy_mclapply <- function(X, FUN, ..., mc = 1L, mc.cores = NULL) {
  
  if (!is.null(mc.cores)) mc <- mc.cores
  
  mc <- as.integer(mc %||% 1L)
  if (mc <= 1L) return(lapply(X, FUN, ...))
  # parallel::mclapply is not available on Windows
  if (.Platform$OS.type == "windows") return(lapply(X, FUN, ...))
  parallel::mclapply(X, FUN, ..., mc.cores = mc)
  
}

#' @keywords internal
.resy_mcmapply <- function(
    FUN, ..., mc = 1L, mc.cores = NULL, SIMPLIFY = TRUE, USE.NAMES = TRUE
) {
  
  if (!is.null(mc.cores)) mc <- mc.cores
  mc <- as.integer(mc %||% 1L)
  if (mc <= 1L || .Platform$OS.type == "windows") {
    return(mapply(FUN, ..., SIMPLIFY = SIMPLIFY, USE.NAMES = USE.NAMES))
    
  }
  
  parallel::mcmapply(
    FUN, ..., mc.cores = mc, SIMPLIFY = SIMPLIFY, USE.NAMES = USE.NAMES
  )
  
}

`%||%` <- function(a, b) if (!is.null(a)) a else b
