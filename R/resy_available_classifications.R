#' List available classifications
#'
#' @description
#' Lists the classification schemes and versions bundled with the package
#' (under `inst/extdata/classifications/`).
#'
#' @return A data frame with columns `scheme`, `version`, `expert_json`,
#'   `expert_txt`. The `expert_*` columns contain the full file path when the
#'   file exists, otherwise `NA`.
#'   
#' @details
#' The function scans the package's classification store directory structure:
#' \itemize{
#'   \item Top-level directories represent classification schemes (e.g., "EUNIS").
#'   \item Second-level directories represent versions within each scheme.
#'   \item Within each version directory, the function looks for `expert.json`
#'     and `expert.txt` files.
#' }
#' 
#' @examples
#' # List all available classifications and their paths
#' resy_available_classifications()
#'
#' @seealso
#' [resy_load_expert()], [resy_add_classification()], [resy_classify()]
#'
#' @export
resy_available_classifications <- function() {
  
  root <- system.file("extdata", "classifications", package = "RESY")
  if (!nzchar(root) || !dir.exists(root))
    return(.resy_empty_classifications_df())

  schemes <- list.dirs(root, full.names = FALSE, recursive = FALSE)
  if (!length(schemes))
    return(.resy_empty_classifications_df())

  rows <- lapply(schemes, function(sc) {
    
    vers_root <- file.path(root, sc)
    versions  <- list.dirs(vers_root, full.names = FALSE, recursive = FALSE)
    
    lapply(versions, function(v) {
      
      base <- file.path(root, sc, v)
      
      .resy_file_or_na <- function(f) {
        
        p <- file.path(base, f)
        if (file.exists(p)) p else NA_character_
        
      }
      
      data.frame(
        scheme      = sc,
        version     = v,
        expert_json = .resy_file_or_na("expert.json"),
        expert_txt  = .resy_file_or_na("expert.txt"),
        stringsAsFactors = FALSE
      )
      
    })
    
  })

  out <- do.call(rbind, unlist(rows, recursive = FALSE))
  rownames(out) <- NULL
  out
  
}

.resy_empty_classifications_df <- function() {
  
  data.frame(
    scheme = character(), version = character(),
    expert_json = character(), expert_txt = character(),
    stringsAsFactors = FALSE
  )
  
}
