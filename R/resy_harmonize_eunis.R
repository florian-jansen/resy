#' Harmonize plot data for EUNIS classification
#'
#' @description
#' Prepares vegetation plot header data for EUNIS habitat classification.
#' Converts coordinates to EPSG:25832 (ETRS89 / UTM zone 32N), assigns WWF
#' ecoregions and country identifiers, optionally computes coast/dune flags,
#' and optionally checks and harmonizes species taxonomy.
#'
#' Use [resy_check_eunis()] first to verify that the input data meets all
#' requirements before running this function.
#'
#' @param data A data frame or `sf` object containing plot data. If not an
#'   `sf` object, columns `Longitude` and `Latitude` must be present.
#' @param source_crs Integer EPSG code of the coordinates in a plain data
#'   frame, in any coordinate reference system; they are converted as needed.
#'   When `NULL` (default), coordinates that are all valid longitudes and
#'   latitudes are read as degrees (EPSG:4326); other coordinates need the code.
#'   Ignored when `data` is an `sf` object, which carries its own CRS.
#' @param run_taxonomy Logical; if `TRUE`, runs [resy_check_taxonomy()] on
#'   `species_data`.
#' @param species_data A data frame with a column `species`. Required when
#'   `run_taxonomy = TRUE`.
#' @param parsed A `resy_parsed_expert` object from [resy_load_expert()].
#'   Required when `run_taxonomy = TRUE`.
#' @param run_coast_dunes Logical; if `TRUE`, assigns `Coast_EEA` and
#'   `Dunes_Bohn` flags via spatial intersection.
#' @param coast_buffer Numeric buffer in metres for coastline proximity
#'   (default 5000).
#' @return A named list:
#'   \describe{
#'     \item{`sites`}{Data frame of harmonised plot data, geometry dropped,
#'       WGS84 `Longitude` and `Latitude` added, and the same values as
#'       `DEG_LON` and `DEG_LAT`, the header fields EUNIS-ESy reads.}
#'     \item{`species_checked`}{Output from [resy_check_taxonomy()] when
#'       `run_taxonomy = TRUE`, otherwise `NULL`.}
#'   }
#' @seealso [resy_check_eunis()], [resy_check_taxonomy()], [resy_classify()]
#' @export
resy_harmonize_eunis <- function(
    data,
    source_crs      = NULL,
    run_taxonomy    = FALSE,
    species_data    = NULL,
    parsed          = NULL,
    run_coast_dunes = FALSE,
    coast_buffer    = 5000
    ) {

  # ---- 1. Sites as sf in the CRS of the base maps ----

  data_sf <- .resy_check_coordinates(data, source_crs = source_crs)

  if (anyNA(data_sf$geometry))
    warning("Some sites have missing coordinates.")

  # ---- 2. PlotObservationID ----

  if (!rlang::has_name(data_sf, "PlotObservationID"))
    stop('Column "PlotObservationID" is missing.')

  # ---- 3. Ecoregions and countries, and what is missing ----

  sites <- .resy_assign_sites(data_sf)
  data_sf <- sites$data
  for (msg in .resy_site_warnings(data_sf, sites$assigned, coast_dunes = FALSE))
    warning(msg, call. = FALSE)

  # ---- 4. Coast and dunes ----
  
  if (run_coast_dunes) {
    
    flags <- .resy_assign_coast_dunes(data_sf, buffer_dist = coast_buffer)
    data_sf$Coast_EEA  <- flags$Coast_EEA
    data_sf$Dunes_Bohn <- flags$Dunes_Bohn
    
  }

  # ---- 5. Taxonomy ----
  
  taxonomy_checked <- NULL
  if (run_taxonomy) {
    
    if (is.null(species_data)) stop("species_data must be provided when run_taxonomy = TRUE.")
    if (is.null(parsed))       stop("parsed must be provided when run_taxonomy = TRUE.")
    taxonomy_checked <- resy_check_taxonomy(species_data, parsed, col = "species")
    
  }

  # ---- 6. Column order ----
  
  data_sf <- .resy_order_eunis_cols(data_sf)

  # ---- 7. Re-export WGS84 coordinates, drop geometry ----
  
  coords_wgs84       <- sf::st_transform(data_sf, 4326)
  coords_mat         <- sf::st_coordinates(coords_wgs84)
  data_sf$Longitude  <- coords_mat[, 1]
  data_sf$Latitude   <- coords_mat[, 2]
  # EUNIS-ESy reads the plot position from the header fields DEG_LON and DEG_LAT.
  data_sf$DEG_LON    <- coords_mat[, 1]
  data_sf$DEG_LAT    <- coords_mat[, 2]

  sites_output <- as.data.frame(sf::st_drop_geometry(data_sf)) |>
    dplyr::select(-dplyr::any_of("...1"))

  list(sites = sites_output, species_checked = taxonomy_checked)
  
}
