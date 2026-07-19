#' Internal Parallel Computing Utilities
#'
#' @description
#' Provides cross-platform wrappers around base R's parallel computing functions.
#' These utilities enable conditional parallelization that gracefully falls back
#' to sequential computation on Windows (where `parallel::mclapply()` and
#' `parallel::mcmapply()` are unavailable) or when a single core is requested.
#'
#' @details
#' The `RESY` package uses these wrapper functions to allow parallelization of
#' computationally intensive operations across different operating systems and
#' user configurations without requiring additional dependencies.
#'
#' ## Functions
#'
#' - `.resy_mclapply()`: Wraps `parallel::mclapply()` with Windows compatibility
#'   and fallback to `base::lapply()` when parallelization is not applicable.
#'
#' - `.resy_mcmapply()`: Wraps `parallel::mcmapply()` with Windows compatibility
#'   and fallback to `base::mapply()` when parallelization is not applicable.
#'
#' - `%||%`: Null-coalescing operator that returns its left operand if not NULL,
#'   otherwise returns the right operand. Used for parameter defaulting.
#'
#' ## Parallelization Rules
#'
#' Parallel computation is applied only when:
#' - Multiple cores are requested (`mc > 1` or `mc.cores > 1`), AND
#' - The operating system supports fork-based parallelization (not Windows)
#'
#' Otherwise, computations fall back to sequential operations.
#'
#' @keywords internal
#'
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
