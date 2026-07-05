#' Check the format of plot data for ESy classification
#'
#' @description
#' Validates that the input data frame or sf object has the structure and
#' columns expected by [resy_classify()]. Performs coordinate transformation to
#' EPSG:25832 and checks for `PlotObservationID`, altitude, ecoregion, country,
#' coast, and dune columns. Missing geographic columns are filled automatically
#' by calling the internal EUNIS geo-assignment helpers.
#'
#' @param data A data frame, tibble, or point `sf` object.
#' @param source_crs Integer EPSG code of the input CRS. Required when `data`
#'   is not an `sf` object.
#' @return An `sf` object in EPSG:25832 with all available ESy columns ordered
#'   to the front: `PlotObservationID`, `Altitude (m)`, `Coast_EEA`, `Dunes_Bohn`,
#'   `Ecoreg`, `Country`, `Country_ID`, `Ecoreg_name`, `geometry`.
#' @seealso [resy_harmonize_eunis()] for the EUNIS-specific enrichment workflow.
#' @examples
#'   data <- tibble::tibble(
#'     PlotObservationID = 1L, x = 701327, y = 5364375
#'   ) |>
#'     sf::st_as_sf(coords = c("x", "y"), crs = 25832)
#'   resy_check_data(data, source_crs = 25832)
#' @export
resy_check_data <- function(data, source_crs) {

  # Coordinates / CRS ----
  data_sf <- .resy_check_coordinates(data = data, source_crs = source_crs)

  if (anyNA(data_sf$geometry))
    warning("Some sites have missing coordinates.")

  # PlotObservationID ----
  if (!rlang::has_name(data_sf, "PlotObservationID"))
    stop('The column "PlotObservationID" is missing. Please insert or rename your plot ID column.')

  # Altitude ----
  if (rlang::has_name(data_sf, "Altitude (m)")) {
    if (anyNA(data_sf$`Altitude (m)`))
      warning('NAs in "Altitude (m)". See mapsforeurope.org for a raster source.')
  } else {
    warning('The column "Altitude (m)" is missing. See mapsforeurope.org for a raster source.')
  }

  # Coast_EEA ----
  if (!rlang::has_name(data_sf, "Coast_EEA"))
    warning('The column "Coast_EEA" is missing.')

  # Dunes_Bohn ----
  if (!rlang::has_name(data_sf, "Dunes_Bohn"))
    warning('The column "Dunes_Bohn" is missing.')

  # Ecoreg ----
  if (rlang::has_name(data_sf, "Ecoreg")) {
    if (anyNA(data_sf$Ecoreg))
      warning('NAs in "Ecoreg" from provided data.')
  } else {
    data_sf <- .resy_assign_ecoregions(data_sf)
    if (anyNA(data_sf$Ecoreg))
      warning('NAs in "Ecoreg": some sites could not be matched to an ecoregion.')
  }

  # Country ----
  if (rlang::has_name(data_sf, "Country")) {
    if (anyNA(data_sf$Country))
      warning('NAs in "Country" from provided data.')
  } else {
    data_sf <- .resy_assign_country(data_sf)
    if (anyNA(data_sf$Country))
      warning('NAs in "Country": some sites could not be matched to a country.')
  }

  # Column order ----
  data_sf |>
    dplyr::select(
      tidyselect::any_of(c(
        "PlotObservationID", "Altitude (m)", "Coast_EEA", "Dunes_Bohn",
        "Ecoreg", "Country", "Country_ID", "Ecoreg_name", "geometry"
      )),
      tidyselect::everything()
    )
}
