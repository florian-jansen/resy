#' Check plot data for EUNIS classification requirements
#'
#' @description
#' Validates that the input data frame or sf object meets the structural
#' requirements for EUNIS habitat classification. This is a pure check — it
#' reports issues without modifying data. Use [resy_harmonize_eunis()] to
#' actually enrich and prepare the data.
#'
#' Checks performed:
#' \itemize{
#'   \item `PlotObservationID` column is present.
#'   \item Coordinates are present and can be transformed to EPSG:25832.
#'   \item `Altitude (m)` column is present and free of `NA`.
#'   \item `Ecoreg` and `Country` columns are present (or will need to be assigned).
#'   \item `Coast_EEA` and `Dunes_Bohn` columns are present when coastal/dune
#'     classification is relevant.
#' }
#'
#' @param data A data frame, tibble, or point `sf` object.
#' @param source_crs Integer EPSG code of the input CRS. Required when `data`
#'   is not an `sf` object.
#' @param verbose Logical; if `TRUE` (default), print a summary of issues.
#' @return A list with:
#'   \describe{
#'     \item{`ok`}{`TRUE` when no blocking issues were found.}
#'     \item{`errors`}{Character vector of errors that will prevent classification.}
#'     \item{`warnings`}{Character vector of warnings about missing or incomplete
#'       columns that [resy_harmonize_eunis()] can fill automatically.}
#'   }
#' @seealso [resy_harmonize_eunis()]
#' @export
resy_check_eunis <- function(data, source_crs = NULL, verbose = TRUE) {
  errors   <- character()
  warnings <- character()

  # --- Coordinates / CRS
  data_sf <- tryCatch(
    .resy_check_coordinates(data, source_crs = if (is.null(source_crs)) missing else source_crs),
    error = function(e) {
      errors <<- c(errors, paste0("Coordinate error: ", conditionMessage(e)))
      NULL
    }
  )

  if (is.null(data_sf)) {
    ok <- FALSE
    if (verbose) message("EUNIS check: FAILED (coordinate conversion error)")
    return(list(ok = ok, errors = errors, warnings = warnings))
  }

  if (anyNA(sf::st_coordinates(data_sf)))
    errors <- c(errors, "Some sites have missing coordinates (NA in geometry).")

  # --- PlotObservationID
  if (!rlang::has_name(data_sf, "PlotObservationID"))
    errors <- c(errors, 'Column "PlotObservationID" is missing.')

  # --- Altitude
  if (!rlang::has_name(data_sf, "Altitude (m)"))
    warnings <- c(warnings, '"Altitude (m)" is missing. See mapsforeurope.org.')
  else if (anyNA(data_sf$`Altitude (m)`))
    warnings <- c(warnings, '"Altitude (m)" contains NA values.')

  # --- Ecoreg
  if (!rlang::has_name(data_sf, "Ecoreg"))
    warnings <- c(warnings, '"Ecoreg" is missing and will be assigned by resy_harmonize_eunis().')
  else if (anyNA(data_sf$Ecoreg))
    warnings <- c(warnings, '"Ecoreg" contains NA values (likely sites outside the base map).')

  # --- Country
  if (!rlang::has_name(data_sf, "Country"))
    warnings <- c(warnings, '"Country" is missing and will be assigned by resy_harmonize_eunis().')
  else if (anyNA(data_sf$Country))
    warnings <- c(warnings, '"Country" contains NA values (likely sites outside the base map).')

  # --- Coast / dunes (optional but noted)
  if (!rlang::has_name(data_sf, "Coast_EEA"))
    warnings <- c(warnings, '"Coast_EEA" is missing. Use run_coast_dunes = TRUE in resy_harmonize_eunis().')
  if (!rlang::has_name(data_sf, "Dunes_Bohn"))
    warnings <- c(warnings, '"Dunes_Bohn" is missing. Use run_coast_dunes = TRUE in resy_harmonize_eunis().')

  ok <- !length(errors)
  if (verbose) {
    message(
      "EUNIS check: ", if (ok) "OK" else "FAILED",
      " (", length(errors), " error(s), ", length(warnings), " warning(s))"
    )
  }
  list(ok = ok, errors = unique(errors), warnings = unique(warnings))
}
