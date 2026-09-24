#' Check the format of plot data for ESy classification
#'
#' @description
#' Validates that the input data frame or sf object has the structure and
#' columns expected by [resy_classify()]. Performs coordinate transformation to
#' EPSG:25832 and checks for `PlotObservationID`, altitude, ecoregion, country,
#' coast, and dune columns. Missing `Ecoreg` and `Country` columns are
#' assigned from the bundled base maps; missing altitude, coast and dune
#' columns are reported as warnings.
#'
#' @param data A data frame, tibble, or point `sf` object.
#' @param source_crs Integer EPSG code of the coordinates in a plain data
#'   frame. When `NULL` (default), coordinates that are all valid longitudes and
#'   latitudes are read as degrees (EPSG:4326); other coordinates need the code.
#'   Ignored when `data` is an `sf` object, which carries its own CRS.
#' @return An `sf` object in EPSG:25832 with all available ESy columns ordered
#'   to the front: `PlotObservationID`, `Altitude (m)`, `Coast_EEA`, `Dunes_Bohn`,
#'   `Ecoreg`, `Ecoreg_name`, `Country`, `Country_ID`, `geometry`.
#' @seealso [resy_harmonize_eunis()] for the EUNIS-specific enrichment workflow.
#' @examples
#'   data <- data.frame(
#'     PlotObservationID = 1L, x = 701327, y = 5364375
#'   ) |>
#'     sf::st_as_sf(coords = c("x", "y"), crs = 25832)
#'   resy_check_data(data, source_crs = 25832)
#' @export
resy_check_data <- function(data, source_crs = NULL) {

  # 1 Coordinates / CRS ----

  data_sf <- .resy_check_coordinates(data = data, source_crs = source_crs)

  if (anyNA(data_sf$geometry))
    warning("Some sites have missing coordinates.")

  # 2 PlotObservationID ----

  if (!rlang::has_name(data_sf, "PlotObservationID"))
    stop('The column "PlotObservationID" is missing. Please insert or rename your plot ID column.')

  # 3 Ecoregions and countries, and what is missing ----

  sites <- .resy_assign_sites(data_sf)
  for (msg in .resy_site_warnings(sites$data, sites$assigned))
    warning(msg, call. = FALSE)

  # 4 Column order ----

  .resy_order_eunis_cols(sites$data)
}
