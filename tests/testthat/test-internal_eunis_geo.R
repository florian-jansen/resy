library(testthat)
library(sf)

# ---- .resy_check_coordinates -------------------------------------------------

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
    out <- RESY:::.resy_check_coordinates(df), "Transforming coordinates"
    )
  expect_equal(sf::st_crs(out)$epsg, 25832)
  
})

test_that(".resy_check_coordinates: data frame without source_crs errors", {
  
  df <- data.frame(Longitude = 10, Latitude = 50)
  expect_error(RESY:::.resy_check_coordinates(df), "source_crs")
  
})

test_that(".resy_check_coordinates: data frame with Lon/Lat and source_crs works", {
  
  df <- data.frame(Longitude = 10, Latitude = 50)
  expect_message(
    out <- RESY:::.resy_check_coordinates(df, source_crs = 4326), "Transforming"
    )
  expect_equal(sf::st_crs(out)$epsg, 25832)
  
})

test_that(".resy_check_coordinates: missing Longitude/Latitude columns errors", {
  
  df <- data.frame(Latitude = 50)
  expect_error(RESY:::.resy_check_coordinates(df, source_crs = 4326), "Longitude")
  
})

# ---- .resy_assign_country ----------------------------------------------------

test_that(".resy_assign_country adds Country and Country_ID columns", {
  
  df <- sf::st_sfc(sf::st_point(c(11.73, 48.40)), crs = 4326) |>
    sf::st_sf() |>
    sf::st_transform(crs = 25832)
  
  out <- RESY:::.resy_assign_country(df)
  expect_s3_class(out, "sf")
  expect_true(all(c("Country_ID", "Country") %in% names(out)))
  expect_identical(out$Country, "Germany")
  
})

test_that(".resy_assign_country returns NA for point outside Europe", {
  
  df <- sf::st_sfc(sf::st_point(c(999999, 9999999)), crs = 25832) |>
    sf::st_sf()
  
  out <- RESY:::.resy_assign_country(df)
  expect_true(is.na(out$Country))
  
})

# ---- .resy_assign_ecoregions -------------------------------------------------

test_that(".resy_assign_ecoregions adds Ecoreg and Ecoreg_name columns", {
  
  df <- sf::st_sfc(sf::st_point(c(11.73, 48.40)), crs = 4326) |>
    sf::st_sf() |>
    sf::st_transform(crs = 25832)
  
  out <- RESY:::.resy_assign_ecoregions(df)
  expect_s3_class(out, "sf")
  expect_true(all(c("Ecoreg", "Ecoreg_name") %in% names(out)))
  expect_false(any(c("OBJECTID", "BIOME_NUM", "BIOME_NAME") %in% names(out)))
  
})

test_that(".resy_assign_ecoregions returns NA for point outside ecoregion layer", {
  
  df <- sf::st_sfc(sf::st_point(c(999999, 9999999)), crs = 25832) |>
    sf::st_sf()
  
  out <- RESY:::.resy_assign_ecoregions(df)
  expect_true(is.na(out$Ecoreg))
  
})

# ---- .resy_assign_coast_dunes ------------------------------------------------

test_that(".resy_assign_coast_dunes errors on non-sf input", {
  
  df <- data.frame(x = 450000, y = 5800000)
  expect_error(RESY:::.resy_assign_coast_dunes(df), "sf object")
  
})

test_that(".resy_assign_coast_dunes errors on wrong CRS", {
  
  df <- sf::st_sfc(sf::st_point(c(11.73, 48.40)), crs = 4326) |>
    sf::st_sf()
  
  expect_error(RESY:::.resy_assign_coast_dunes(df), "EPSG:25832")
  
})
