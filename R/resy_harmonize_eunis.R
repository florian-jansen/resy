#' Harmonize plot data for EUNIS classification
#'
#' @description
#' Prepares vegetation plot header data for EUNIS habitat classification.
#' Converts coordinates to EPSG:25832, assigns WWF ecoregions and country
#' identifiers, optionally computes coast/dune flags, and optionally checks
#' and harmonizes species taxonomy.
#'
#' Use [resy_check_eunis()] first to verify that the input data meets all
#' requirements before running this function.
#'
#' @param data A data frame or `sf` object containing plot data. If not an
#'   `sf` object, columns `Longitude` and `Latitude` must be present.
#' @param source_crs Integer EPSG code of the input CRS. Required when `data`
#'   is a plain data frame; ignored when `data` is already an `sf` object.
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
#'       WGS84 `Longitude` and `Latitude` added.}
#'     \item{`species_checked`}{Output from [resy_check_taxonomy()] when
#'       `run_taxonomy = TRUE`, otherwise `NULL`.}
#'   }
#' @seealso [resy_check_eunis()], [resy_check_taxonomy()], [resy_classify()]
#' @export
resy_harmonize_eunis <- function(data,
                                 source_crs      = NULL,
                                 run_taxonomy    = FALSE,
                                 species_data    = NULL,
                                 parsed          = NULL,
                                 run_coast_dunes = FALSE,
                                 coast_buffer    = 5000) {

  # ---- 1. Ensure sf + CRS ----
  if (!inherits(data, "sf")) {
    if (!all(c("Longitude", "Latitude") %in% names(data)))
      stop('Data frame must contain columns "Longitude" and "Latitude".')
    if (is.null(source_crs))
      stop("source_crs must be provided for plain data frames.")
    data_sf <- sf::st_as_sf(data, coords = c("Longitude", "Latitude"), crs = source_crs)
  } else {
    data_sf <- data
  }
  data_sf <- sf::st_transform(data_sf, 25832)

  if (anyNA(data_sf$geometry)) warning("Some sites have missing coordinates.")

  # ---- 2. PlotObservationID ----
  if (!rlang::has_name(data_sf, "PlotObservationID"))
    stop('Column "PlotObservationID" is missing.')

  # ---- 3. Altitude ----
  if (rlang::has_name(data_sf, "Altitude (m)")) {
    if (anyNA(data_sf$`Altitude (m)`)) warning('NA values in "Altitude (m)".')
  } else {
    warning('"Altitude (m)" is missing. See mapsforeurope.org for a raster source.')
  }

  # ---- 4. Ecoregions ----
  if (!rlang::has_name(data_sf, "Ecoreg")) {
    data_sf <- .resy_assign_ecoregions(data_sf)
    if (anyNA(data_sf$Ecoreg))
      warning('NA values in "Ecoreg": some sites are outside the ecoregion base map.')
  } else if (anyNA(data_sf$Ecoreg)) {
    warning('NA values in "Ecoreg" from provided data.')
  }

  # ---- 5. Country ----
  if (!rlang::has_name(data_sf, "Country")) {
    data_sf <- .resy_assign_country(data_sf)
    if (anyNA(data_sf$Country))
      warning('NA values in "Country": some sites are outside the country base map.')
  } else if (anyNA(data_sf$Country)) {
    warning('NA values in "Country" from provided data.')
  }

  # ---- 6. Coast and dunes ----
  if (run_coast_dunes) {
    flags <- .resy_assign_coast_dunes(data_sf, buffer_dist = coast_buffer)
    data_sf$Coast_EEA  <- flags$Coast_EEA
    data_sf$Dunes_Bohn <- flags$Dunes_Bohn
  }

  # ---- 7. Taxonomy ----
  taxonomy_checked <- NULL
  if (run_taxonomy) {
    if (is.null(species_data)) stop("species_data must be provided when run_taxonomy = TRUE.")
    if (is.null(parsed))       stop("parsed must be provided when run_taxonomy = TRUE.")
    taxonomy_checked <- resy_check_taxonomy(species_data, parsed, col = "species")
  }

  # ---- 8. Column order ----
  data_sf <- data_sf |>
    dplyr::select(
      tidyselect::any_of(c(
        "PlotObservationID", "Altitude (m)", "Coast_EEA", "Dunes_Bohn",
        "Ecoreg", "Ecoreg_name", "Country", "Country_ID", "geometry"
      )),
      tidyselect::everything()
    )

  # ---- 9. Re-export WGS84 coordinates, drop geometry ----
  coords_wgs84       <- sf::st_transform(data_sf, 4326)
  coords_mat         <- sf::st_coordinates(coords_wgs84)
  data_sf$Longitude  <- coords_mat[, 1]
  data_sf$Latitude   <- coords_mat[, 2]

  sites_output <- as.data.frame(sf::st_drop_geometry(data_sf)) |>
    dplyr::select(-dplyr::any_of("...1"))

  list(sites = sites_output, species_checked = taxonomy_checked)
}
