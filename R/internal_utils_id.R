#' Internal Plot Identification Utilities
#'
#' @description
#' Provides utilities for detecting, standardizing, and normalizing plot
#' identification columns across observation and header data frames. These
#' functions ensure consistent use of plot IDs throughout the resy classification
#' workflow.
#'
#' @details
#' The resy package supports flexible plot ID column naming conventions but
#' internally standardizes all plot IDs to the `PlotObservationID` column for
#' consistency. These utilities handle the following tasks:
#'
#' - **Detection**: Automatically identify ID columns by looking for standard
#'   names (`PlotObservationID`, `PlotID`) across both observation and header
#'   data frames.
#'
#' - **Standardization**: Convert user-specified or auto-detected ID columns
#'   to the internal `PlotObservationID` standard while preserving the original
#'   column reference.
#'
#' - **Normalization**: Ensure plot IDs are stored as character strings and are
#'   present in both observation and header data frames.
#'
#' ## Functions
#'
#' - `.resy_guess_id_col()`: Automatically detects a common ID column name
#'   present in both observation and header data frames.
#'
#' - `.resy_standardize_plot_id()`: Converts plot IDs to the internal
#'   `PlotObservationID` standard and validates presence in both data frames.
#'
#' - `.resy_get_id_col()`: Retrieves an ID column name with explicit priority
#'   ordering, including user-specified columns.
#'
#' - `.resy_normalize_ids_obs()`: Normalizes plot IDs in observation data to
#'   character `PlotObservationID`.
#'
#' - `.resy_normalize_ids_header()`: Normalizes plot IDs in header data to
#'   character `PlotObservationID`.
#'
#' @keywords internal
#'

#' @keywords internal
.resy_guess_id_col <- function(obs, header) {
  
  candidates <- c("PlotObservationID", "PlotID")
  for (nm in candidates) {
    if (nm %in% names(obs) && nm %in% names(header)) return(nm)
    
  }
  
  return(NULL)
  
}

#' Standardize Plot Identification Column to Internal Standard
#'
#' @description
#' Converts plot ID columns to the internal `PlotObservationID` standard,
#' validating that the ID column exists in both observation and header data
#' frames.
#'
#' @param obs data frame or data.table of species observations with a plot ID
#'   column.
#'
#' @param header data frame with plot-level metadata including a plot ID column.
#'
#' @param id_col character scalar specifying the name of the plot ID column to
#'   use. If `NULL` (default), the function automatically detects a standard
#'   column name.
#'
#' @return list with elements:
#'   - `obs`: observation data with `PlotObservationID` added/overwritten
#'   - `header`: header data with `PlotObservationID` added/overwritten
#'   - `id_col_used`: character scalar indicating which original column was used
#'
#' @keywords internal
#'
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

#' Retrieve Plot Identification Column with Priority Ordering
#'
#' @description
#' Retrieves a plot ID column name from both observation and header data frames,
#' using explicit priority ordering including user-specified columns.
#'
#' @param obs data frame or data.table of species observations.
#'
#' @param header data frame with plot-level metadata.
#'
#' @param id_col character scalar specifying a preferred plot ID column name.
#'   If provided, this column is checked first before falling back to standard
#'   names.
#'
#' @return character scalar naming the detected plot ID column.
#'
#' @keywords internal
#'
.resy_get_id_col <- function(obs, header, id_col = NULL) {
  
  candidates <- c("PlotObservationID", "PlotID")
  if (!is.null(id_col)) candidates <- c(id_col, candidates)
  
  for (cand in unique(candidates)) {
    if (cand %in% names(obs) && cand %in% names(header)) return(cand)
    
  }
  
  stop("No suitable plot id column found in both obs and header. Tried: ",
       paste(unique(candidates), collapse = ", "))
  
}

#' Normalize Plot IDs in Observation Data to Character PlotObservationID
#'
#' @description
#' Standardizes plot IDs in observation data to character format under the
#' `PlotObservationID` column.
#'
#' @param obs data frame or data.table of species observations.
#'
#' @param id_col character scalar naming the source plot ID column.
#'
#' @return data frame or data.table with `PlotObservationID` column added
#'   as character representation of the source ID column.
#'
#' @keywords internal
#'
.resy_normalize_ids_obs <- function(obs, id_col) {
  
  obs$PlotObservationID <- as.character(obs[[id_col]])
  obs
  
}

#' Normalize Plot IDs in Header Data to Character PlotObservationID
#'
#' @description
#' Standardizes plot IDs in header data to character format under the
#' `PlotObservationID` column.
#'
#' @param header data frame with plot-level metadata.
#'
#' @param id_col character scalar naming the source plot ID column.
#'
#' @return data frame with `PlotObservationID` column added as character
#'   representation of the source ID column.
#'
#' @keywords internal
#'
.resy_normalize_ids_header <- function(header, id_col) {
  
  header$PlotObservationID <- as.character(header[[id_col]])
  header
  
}
