# Internal geographic helper functions for the EUNIS workflow.
# Called by resy_check_data() and resy_harmonize_eunis().

# ---- Bundled GIS layers ------------------------------------------------------

# Dataset in data/ -> name of the sf object it holds.
.resy_gis_layers <- c(
  coastline_regions_epsg25832     = "co",
  dunes_bohn_500mbuffer_epsg25832 = "bohn",
  ecoregions2017_epsg25832        = "ecoregions2017_epsg25832",
  europe_resolution_1_epsg25832   = "europe_resolution_1_epsg25832",
  europe_resolution_60_epsg25832  = "europe_resolution_60_epsg25832"
)

.resy_gis_cache <- new.env(parent = emptyenv())

# Return a bundled GIS layer. Each layer is read from data/ on first use and
# kept for the rest of the session, so attaching the package reads nothing and
# repeated calls do not re-read the file.
.resy_gis <- function(dataset) {
  if (!dataset %in% names(.resy_gis_layers))
    stop("Unknown GIS layer: '", dataset, "'.", call. = FALSE)

  if (!exists(dataset, envir = .resy_gis_cache, inherits = FALSE)) {
    env <- new.env(parent = emptyenv())
    utils::data(list = dataset, package = "RESY", envir = env)
    obj <- .resy_gis_layers[[dataset]]
    if (!exists(obj, envir = env, inherits = FALSE))
      stop("Object `", obj, "` not found after loading `", dataset, "`.",
           call. = FALSE)
    assign(dataset, get(obj, envir = env), envir = .resy_gis_cache)
  }
  get(dataset, envir = .resy_gis_cache, inherits = FALSE)
}

# ---- Coordinate transformation -----------------------------------------------

# CRS of the bundled GIS layers and of the sites while they are matched to them.
.resy_eunis_crs <- 25832

# Sites as an sf object in .resy_eunis_crs. An sf object keeps its own CRS; a
# data frame needs `Longitude` and `Latitude` in the CRS `source_crs`. Without
# `source_crs`, coordinates that are all valid longitudes and latitudes are read
# as degrees (EPSG:4326); other coordinates need the code.
.resy_check_coordinates <- function(data, source_crs = NULL) {

  if (!inherits(data, "sf")) {

    if (!rlang::has_name(data, "Longitude") || !rlang::has_name(data, "Latitude"))
      stop('"Longitude" and/or "Latitude" columns are missing.', call. = FALSE)

    if (is.null(source_crs)) {
      lon <- suppressWarnings(as.numeric(data$Longitude))
      lat <- suppressWarnings(as.numeric(data$Latitude))
      if (!all(abs(lon) <= 180 & abs(lat) <= 90, na.rm = TRUE))
        stop("The coordinates are not longitude/latitude in degrees; ",
             "give their EPSG code as `source_crs`.", call. = FALSE)
      message("`source_crs` not given; the coordinates are read as ",
              "longitude/latitude in degrees (EPSG:4326).")
      source_crs <- 4326
    }

    data <- sf::st_as_sf(data, coords = c("Longitude", "Latitude"), crs = source_crs)
  }

  if (isTRUE(sf::st_crs(data)$epsg == .resy_eunis_crs)) return(data)
  message("Transforming coordinates to ETRS89 / UTM zone 32N (EPSG:25832).")
  sf::st_transform(data, crs = .resy_eunis_crs)
}

# ---- EUNIS site columns -----------------------------------------------------

# Header columns of the EUNIS workflow, in the order they are put first.
.resy_eunis_cols <- c(
  "PlotObservationID", "Altitude (m)", "Coast_EEA", "Dunes_Bohn",
  "Ecoreg", "Ecoreg_name", "Country", "Country_ID", "geometry"
)

# Move the EUNIS columns to the front.
.resy_order_eunis_cols <- function(data) {
  dplyr::select(data, tidyselect::any_of(.resy_eunis_cols), tidyselect::everything())
}

# Assign Ecoreg and Country to sites that lack the column. Returns the data and
# the names of the columns that were assigned.
.resy_assign_sites <- function(data) {
  assigned <- character()
  if (!rlang::has_name(data, "Ecoreg")) {
    data <- .resy_assign_ecoregions(data)
    assigned <- c(assigned, "Ecoreg")
  }
  if (!rlang::has_name(data, "Country")) {
    data <- .resy_assign_country(data)
    assigned <- c(assigned, "Country")
  }
  list(data = data, assigned = assigned)
}

# Messages about missing or incomplete EUNIS columns. `assigned` names the
# columns that were just assigned from the base maps; `coast_dunes = FALSE`
# leaves out the coast and dune columns.
.resy_site_warnings <- function(data, assigned = character(), coast_dunes = TRUE) {
  out <- character()

  if (!rlang::has_name(data, "Altitude (m)"))
    out <- c(out, '"Altitude (m)" is missing. See vignette "Altitude data" and mapsforeurope.org for a raster source.')
  else if (anyNA(data$`Altitude (m)`))
    out <- c(out, '"Altitude (m)" contains NA values.')

  for (col in c("Ecoreg", "Country")) {
    map <- if (col == "Ecoreg") "ecoregion" else "country"
    if (col %in% assigned) {
      if (all(is.na(data[[col]])))
        out <- c(out, sprintf(paste0(
          "No site falls inside the %s base map. Check that `source_crs` ",
          "matches the coordinates (longitude/latitude in degrees is 4326)."), map))
      else if (anyNA(data[[col]]))
        out <- c(out, sprintf('"%s" contains NA values: some sites are outside the %s base map.', col, map))
    } else if (!rlang::has_name(data, col)) {
      out <- c(out, sprintf('"%s" is missing and will be assigned by resy_harmonize_eunis().', col))
    } else if (anyNA(data[[col]])) {
      out <- c(out, sprintf('"%s" contains NA values (in the provided data).', col))
    }
  }

  if (coast_dunes) for (col in c("Coast_EEA", "Dunes_Bohn"))
    if (!rlang::has_name(data, col))
      out <- c(out, sprintf('"%s" is missing. Use run_coast_dunes = TRUE in resy_harmonize_eunis().', col))

  out
}

# ---- Ecoregion assignment ----------------------------------------------------

#' @keywords internal
.resy_assign_ecoregions <- function(data) {
  
  ecoregions_sf <- .resy_gis("ecoregions2017_epsg25832")

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
  
  country_sf <- .resy_gis("europe_resolution_1_epsg25832")
  
  data <- sf::st_transform(data, sf::st_crs(country_sf))
  
  data |>
    sf::st_join(country_sf, left = TRUE, largest = FALSE) |>
    dplyr::rename(Country_ID = "NUTS_ID", Country = "NUTS_NAME") |>
    dplyr::mutate(
      Country = dplyr::recode(toupper(Country), !!!.country_map, .default = Country)
      )
  
}

# ---- Coast and dune assignment -----------------------------------------------

.resy_assign_coast_dunes <- function(data_sf, buffer_dist = 5000) {
  
  if (!inherits(data_sf, "sf"))
    stop("`data_sf` must be an sf object.", call. = FALSE)
  
  if (isFALSE(sf::st_crs(data_sf)$epsg == .resy_eunis_crs))
    stop("`data_sf` must be in EPSG:", .resy_eunis_crs, ".", call. = FALSE)
  
  if (!is.numeric(buffer_dist) || length(buffer_dist) != 1 || buffer_dist <= 0)
    stop(
      "`buffer_dist` must be a single positive number (metres).", call. = FALSE
      )

  bbox <- sf::st_bbox(data_sf)

  coastline <- .resy_gis("coastline_regions_epsg25832") |>
    sf::st_zm() |> sf::st_crop(bbox) |> sf::st_buffer(dist = buffer_dist)

  dunes <- .resy_gis("dunes_bohn_500mbuffer_epsg25832") |> sf::st_crop(bbox)

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
