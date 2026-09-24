library(testthat)
library(sf)

# ---- .resy_gis ---------------------------------------------------------------

test_that(".resy_gis loads bundled GIS layers and rejects unknown ones", {
  expect_s3_class(RESY:::.resy_gis("ecoregions2017_epsg25832"), "sf")
  expect_s3_class(RESY:::.resy_gis("europe_resolution_1_epsg25832"), "sf")
  expect_error(RESY:::.resy_gis("not_a_layer"), "Unknown GIS layer")
})

# ---- .resy_check_coordinates --------------------------------------------------

test_that(".resy_check_coordinates: sf already in 25832 passes through", {
  df <- sf::st_read(
    system.file("shape/nc.shp", package = "sf"), quiet = TRUE
  ) |>
    sf::st_transform(crs = 25832)
  
  expect_silent(out <- RESY:::.resy_check_coordinates(df))
  expect_equal(sf::st_crs(out)$epsg, 25832)
})

test_that(".resy_check_coordinates: sf not in 25832 transforms with message", {
  df <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  
  expect_message(
    out <- RESY:::.resy_check_coordinates(df),
    "Transforming coordinates"
  )
  expect_equal(sf::st_crs(out)$epsg, 25832)
})

test_that(".resy_check_coordinates: projected data frame without source_crs errors", {
  df <- data.frame(Longitude = 700000, Latitude = 5000000)
  
  expect_error(RESY:::.resy_check_coordinates(df), "source_crs")
})

test_that(".resy_check_coordinates: data frame with Lon/Lat and source_crs works", {
  df <- data.frame(Longitude = 10, Latitude = 50)
  
  expect_message(
    out <- RESY:::.resy_check_coordinates(df, source_crs = 4326),
    "Transforming"
  )
  expect_equal(sf::st_crs(out)$epsg, 25832)
})

test_that(".resy_check_coordinates: missing Longitude/Latitude columns errors", {
  df <- data.frame(Latitude = 50)
  
  expect_error(RESY:::.resy_check_coordinates(df, source_crs = 4326), "Longitude")
})

# ---- .resy_order_eunis_cols ---------------------------------------------------

test_that(".resy_order_eunis_cols moves EUNIS columns to the front", {
  df <- data.frame(
    Country = "Germany",
    PlotObservationID = "p1",
    x = 1,
    `Altitude (m)` = 100
  )
  
  out <- RESY:::.resy_order_eunis_cols(df)
  
  expect_true("PlotObservationID" %in% names(out))
  expect_true("Country" %in% names(out))
  expect_true("x" %in% names(out))
  expect_true(match("PlotObservationID", names(out)) < match("x", names(out)))
})

# ---- .resy_assign_sites -------------------------------------------------------

test_that(".resy_assign_sites assigns missing Ecoreg and Country columns", {
  df <- sf::st_sf(
    geometry = sf::st_sfc(sf::st_point(c(11.73, 48.40)), crs = 4326)
  ) |>
    sf::st_transform(crs = 25832)
  
  out <- RESY:::.resy_assign_sites(df)
  
  expect_true(all(c("Ecoreg", "Country") %in% names(out$data)))
  expect_equal(out$assigned, c("Ecoreg", "Country"))
})

# ---- .resy_site_warnings ------------------------------------------------------

test_that(".resy_site_warnings reports missing altitude and missing base-map columns", {
  df <- data.frame(PlotObservationID = "p1")
  
  out <- RESY:::.resy_site_warnings(
    df,
    assigned = c("Ecoreg", "Country"),
    coast_dunes = TRUE
  )
  
  expect_true(any(grepl("Altitude", out)))
  expect_true(any(grepl("Ecoreg", out) | grepl("Country", out)))
})

# ---- .resy_assign_country -----------------------------------------------------

test_that(".resy_assign_country adds Country and Country_ID columns", {
  df <- sf::st_sfc(sf::st_point(c(11.73, 48.40)), crs = 4326) |>
    sf::st_sf() |>
    sf::st_transform(crs = 25832)
  
  out <- RESY:::.resy_assign_country(df)
  
  expect_s3_class(out, "sf")
  expect_true(all(c("Country_ID", "Country") %in% names(out)))
  expect_identical(out$Country, "Germany")
})

test_that(".resy_assign_country returns NA for points outside Europe", {
  df <- sf::st_sfc(sf::st_point(c(999999, 9999999)), crs = 25832) |>
    sf::st_sf()
  
  out <- RESY:::.resy_assign_country(df)
  
  expect_true(is.na(out$Country))
})

# ---- .resy_assign_ecoregions --------------------------------------------------

test_that(".resy_assign_ecoregions adds Ecoreg and Ecoreg_name columns", {
  df <- sf::st_sfc(sf::st_point(c(11.73, 48.40)), crs = 4326) |>
    sf::st_sf() |>
    sf::st_transform(crs = 25832)
  
  out <- RESY:::.resy_assign_ecoregions(df)
  
  expect_s3_class(out, "sf")
  expect_true(all(c("Ecoreg", "Ecoreg_name") %in% names(out)))
  expect_false(any(c("OBJECTID", "BIOME_NUM", "BIOME_NAME") %in% names(out)))
})

test_that(".resy_assign_ecoregions returns NA for points outside the ecoregion layer", {
  df <- sf::st_sfc(sf::st_point(c(999999, 9999999)), crs = 25832) |>
    sf::st_sf()
  
  out <- RESY:::.resy_assign_ecoregions(df)
  
  expect_true(is.na(out$Ecoreg))
})

# ---- .resy_assign_coast_dunes --------------------------------------------------

test_that(".resy_assign_coast_dunes errors on non-sf input", {
  df <- data.frame(x = 450000, y = 5800000)
  
  expect_error(RESY:::.resy_assign_coast_dunes(df), "sf object")
})

test_that(".resy_assign_coast_dunes errors on wrong CRS", {
  df <- sf::st_sfc(sf::st_point(c(11.73, 48.40)), crs = 4326) |>
    sf::st_sf()
  
  expect_error(RESY:::.resy_assign_coast_dunes(df), "EPSG:25832")
})

test_that(".resy_assign_coast_dunes returns coast and dune flags for valid sf input", {
  df <- sf::st_sf(
    geometry = sf::st_sfc(sf::st_point(c(11.73, 48.40)), crs = 4326)
  ) |>
    sf::st_transform(crs = 25832)
  
  out <- RESY:::.resy_assign_coast_dunes(df)
  
  expect_s3_class(out, "tbl_df")
  expect_true(all(c("Coast_EEA", "Dunes_Bohn") %in% names(out)))
  expect_equal(nrow(out), nrow(df))
})
