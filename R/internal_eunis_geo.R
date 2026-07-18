# Internal geographic helper functions for the EUNIS workflow.
# Called by resy_check_data() and resy_harmonize_eunis().

# ---- Coordinate transformation -----------------------------------------------

#' @keywords internal
.resy_check_coordinates <- function(data, source_crs) {
  
  if (methods::is(data, "sf")) {
    if (isTRUE(sf::st_crs(data)$epsg == 25832)) return(data)
    message("Transforming coordinates to ETRS89 / UTM zone 32N (EPSG:25832).")
    return(sf::st_transform(data, crs = 25832))
    
  }

  if (missing(source_crs))
    stop('No "source_crs" provided.', call. = FALSE)
  
  if (!rlang::has_name(data, "Longitude") || !rlang::has_name(data, "Latitude"))
    stop('"Longitude" and/or "Latitude" columns are missing.', call. = FALSE)

  data_sf <- sf::st_as_sf(
    data, coords = c("Longitude", "Latitude"), crs = source_crs
    )
  
  if (sf::st_crs(data_sf)$epsg != 25832) {
    message("Transforming coordinates to ETRS89 / UTM zone 32N (EPSG:25832).")
    
    data_sf <- sf::st_transform(data_sf, crs = 25832)
    
  }
  data_sf
}

# ---- Ecoregion assignment ----------------------------------------------------

#' @keywords internal
.resy_assign_ecoregions <- function(data) {
  
  utils::data(
    "ecoregions2017_epsg25832", package = "RESY", envir = environment()
    )
  
  ecoregions_sf <- get("ecoregions2017_epsg25832", inherits = FALSE)

  data |>
    sf::st_join(ecoregions_sf, left = TRUE, largest = FALSE) |>
    dplyr::select(
      -dplyr::any_of(c(
        "OBJECTID", "BIOME_NUM", "BIOME_NAME", "REALM", "COLOR", "LICENSE"
        )),
      dplyr::any_of(c("ECO_ID", "ECO_NAME"))
    ) |>
    dplyr::rename(
      Ecoreg      = "ECO_ID",
      Ecoreg_name = "ECO_NAME"
    )
}

# ---- Country assignment ------------------------------------------------------

.country_map <- c(
  "\u00d6STERREICH"                                                              = "Austria",
  "BELGIQUE-BELGI\u00cb"                                                         = "Belgium",
  "\u0411\u042a\u041b\u0413\u0410\u0420\u0418\u042f"                            = "Bulgaria",
  "HRVATSKA"                                                                     = "Croatia",
  "\u010cESK\u00c1 REPUBLIKA"                                                    = "Czechia",
  "DANMARK"                                                                      = "Denmark",
  "DEUTSCHLAND"                                                                  = "Germany",
  "EESTI"                                                                        = "Estonia",
  "SUOMI / FINLAND"                                                              = "Finland",
  "FRANCE"                                                                       = "France",
  "\u0395\u039b\u039b\u0391\u0394\u0391"                                        = "Greece",
  "MAGYARORSZ\u00c1G"                                                            = "Hungary",
  "IRELAND"                                                                      = "Ireland",
  "ITALIA"                                                                       = "Italy",
  "LATVIJA"                                                                      = "Latvia",
  "LIETUVA"                                                                      = "Lithuania",
  "LUXEMBOURG"                                                                   = "Luxembourg",
  "MALTA"                                                                        = "Malta",
  "NEDERLAND"                                                                    = "Netherlands",
  "POLSKA"                                                                       = "Poland",
  "PORTUGAL"                                                                     = "Portugal",
  "ROM\u00c2NIA"                                                                 = "Romania",
  "SLOVENIJA"                                                                    = "Slovenia",
  "ESPA\u00d1A"                                                                  = "Spain",
  "SVERIGE"                                                                      = "Sweden",
  "SHQIP\u00cbRIA"                                                               = "Albania",
  "\u039a\u03a5\u03a0\u03a1\u039f\u03a3"                                        = "Cyprus",
  "\u00cdSLAND"                                                                  = "Iceland",
  "LIECHTENSTEIN"                                                                = "Liechtenstein",
  "\u0426\u0420\u041d\u0410 \u0413\u041e\u0420\u0410"                           = "Montenegro",
  "NORGE"                                                                        = "Norway",
  "North Macedonia"                                                              = "North Macedonia",
  "REPUBLIKA SRBIJA /\u0420\u0415\u041f\u0423\u0411\u041b\u0418\u041a\u0410 \u0421\u0420\u0411\u0418\u0408\u0410" = "Serbia",
  "SCHWEIZ/SUISSE/SVIZZERA"                                                      = "Switzerland",
  "T\u00dcRKIYE"                                                                 = "Turkey",
  "UNITED KINGDOM"                                                               = "United Kingdom"
)

#' @keywords internal
.resy_assign_country <- function(data) {
  
  if (!inherits(data, "sf"))
    stop("`data` must be an sf object.", call. = FALSE)
  
  utils::data(
    "europe_resolution_1_epsg25832", package = "RESY", envir = environment()
    )
  
  country_sf <- get("europe_resolution_1_epsg25832", inherits = FALSE)
  
  data <- sf::st_transform(data, sf::st_crs(country_sf))
  
  data |>
    sf::st_join(country_sf, left = TRUE, largest = FALSE) |>
    dplyr::rename(Country_ID = "NUTS_ID", Country = "NUTS_NAME") |>
    dplyr::mutate(
      Country = dplyr::recode(Country, !!!.country_map, .default = Country)
      )
  
}

# ---- Coast and dune assignment -----------------------------------------------

#' @importFrom sf st_bbox st_crop st_buffer st_intersects st_zm
#' @importFrom dplyr tibble
#' @keywords internal
.resy_assign_coast_dunes <- function(data_sf, buffer_dist = 5000) {
  
  if (!inherits(data_sf, "sf"))
    stop("`data_sf` must be an sf object.", call. = FALSE)
  
  if (isFALSE(sf::st_crs(data_sf)$epsg == 25832))
    stop("`data_sf` must be in EPSG:25832.", call. = FALSE)
  
  if (!is.numeric(buffer_dist) || length(buffer_dist) != 1 || buffer_dist <= 0)
    stop(
      "`buffer_dist` must be a single positive number (metres).", call. = FALSE
      )

  bbox <- sf::st_bbox(data_sf)

  coast_env <- new.env(parent = emptyenv())
  
  utils::data("coastline_regions_epsg25832", package = "RESY", envir = coast_env)
  
  if (!exists("co", envir = coast_env, inherits = FALSE))
    stop('Object `co` not found after loading `coastline_regions_epsg25832`.')
  
  coastline <- get("co", envir = coast_env) |>
    sf::st_zm() |> sf::st_crop(bbox) |> sf::st_buffer(dist = buffer_dist)

  dune_env <- new.env(parent = emptyenv())
  
  utils::data("dunes_bohn_500mbuffer_epsg25832", package = "RESY", envir = dune_env)
  
  if (!exists("bohn", envir = dune_env, inherits = FALSE))
    stop('Object `bohn` not found after loading `dunes_bohn_500mbuffer_epsg25832`.')
  
  dunes <- get("bohn", envir = dune_env) |> sf::st_crop(bbox)

  coast_join <- sf::st_join(data_sf, coastline, left = TRUE)
  
  coast_flag <- coast_join$COAST_EEA
  
  if (length(coast_flag) != nrow(data_sf)) {
    
    coast_flag <- vapply(sf::st_intersects(data_sf, coastline), function(x)
      if (length(x) == 0L) "N_COAST" else coastline$COAST_EEA[x[1L]], character(1))
    
  }
  
  coast_flag[is.na(coast_flag)] <- "N_COAST"

  dune_flag <- ifelse(
    rowSums(sf::st_intersects(data_sf, dunes, sparse = FALSE)) > 0,
    "Y_DUNES", "N_DUNES"
    )

  dplyr::tibble(Coast_EEA = coast_flag, Dunes_Bohn = dune_flag)
  
}
