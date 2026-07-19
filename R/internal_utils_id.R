.resy_guess_id_col <- function(obs, header) {
  
  candidates <- c("PlotObservationID", "PlotID")
  for (nm in candidates) {
    if (nm %in% names(obs) && nm %in% names(header)) return(nm)
    
  }
  
  return(NULL)
  
}

# Standardize plot id to PlotObservationID internally.
# Returns list(obs=..., header=..., id_col_used=...)
.resy_standardize_plot_id <- function(obs, header, id_col = NULL) {
  
  if (!is.null(id_col)) {
    
    if (!(id_col %in% names(obs)))
      stop("id_col '", id_col, "' not found in obs.")
    if (!(id_col %in% names(header)))
      stop("id_col '", id_col, "' not found in header.")
    id_used <- id_col
    
  } else {
    
    id_used <- .resy_guess_id_col(obs, header)
    if (is.null(id_used)) {
      stop(
        "No plot id column found in both obs and header. ",
        "Please provide id_col, or include one of: PlotObservationID, PlotID."
      )
      
    }
  }
  # Create/overwrite PlotObservationID used by internal logic
  obs[, PlotObservationID := as.character(get(id_used))]
  header$PlotObservationID <- as.character(header[[id_used]])
  list(obs = obs, header = header, id_col_used = id_used)
}

.resy_get_id_col <- function(obs, header, id_col = NULL) {
  
  candidates <- c("PlotObservationID", "PlotID")
  if (!is.null(id_col)) candidates <- c(id_col, candidates)
  
  for (cand in unique(candidates)) {
    if (cand %in% names(obs) && cand %in% names(header)) return(cand)
    
  }
  
  stop("No suitable plot id column found in both obs and header. Tried: ",
       paste(unique(candidates), collapse = ", "))
  
}

.resy_normalize_ids_obs <- function(obs, id_col) {
  
  obs$PlotObservationID <- as.character(obs[[id_col]])
  obs
  
}

.resy_normalize_ids_header <- function(header, id_col) {
  
  header$PlotObservationID <- as.character(header[[id_col]])
  header
  
}
