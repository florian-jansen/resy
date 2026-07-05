#' Classification storage roots
#'
#' @description
#' Returns the root directory where classifications are stored.
#' Built-in classifications ship inside the package (read-only after install).
#' User-added classifications are stored in a user-writable data directory.
#'
#' @param location One of `"user"` or `"package"`.
#' @param create Logical; if `TRUE` and `location = "user"`, create the
#'   directory if it does not yet exist. Ignored for `"package"`.
#' @return A path string.
#' @keywords internal
resy_classifications_root <- function(location = c("user", "package"),
                                      create = FALSE) {
  location <- match.arg(location)
  if (location == "package") {
    return(system.file("extdata", "classifications", package = "RESY"))
  }
  # user location: writable per-user data directory
  root <- tools::R_user_dir("RESY", which = "data")
  root <- file.path(root, "classifications")
  if (isTRUE(create) && !dir.exists(root)) {
    dir.create(root, recursive = TRUE, showWarnings = FALSE)
  }
  root
}
