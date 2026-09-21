library(testthat)
library(sf)

test_that("resy_harmonize_eunis works correctly with list output", {

  test_data <- data.frame(
    PlotObservationID = 1:3,
    `Altitude (m)` = c(100, 200, 150),
    Longitude = c(12.4924, 13.4050, 14.5058),
    Latitude  = c(41.8902, 52.5200, 46.0569),
    check.names = FALSE
  )

  test_species <- data.frame(
    PlotObservationID = c(1, 1, 2, 2, 3, 3),
    species   = c("Lemna gibba", "Lemna minor", "Poa annua",
                  "Poa pratensis", "Carex sp.", "Juncus sp."),
    cover     = c(50, 30, 20, 40, 15, 25)
  )

  # Basic run without optional features
  res <- RESY:::resy_harmonize_eunis(
    data            = test_data,
    source_crs      = 4326,
    run_taxonomy    = FALSE,
    run_coast_dunes = FALSE
  )

  expect_type(res, "list")
  expect_true(all(c("sites", "species_checked") %in% names(res)))
  expect_s3_class(res$sites, "data.frame")
  expect_equal(nrow(res$sites), nrow(test_data))
  expect_true("PlotObservationID" %in% names(res$sites))
  expect_true("Altitude (m)" %in% names(res$sites))
  expect_null(res$species_checked)

  # run_taxonomy = TRUE without parsed should error
  expect_error(
    RESY:::resy_harmonize_eunis(
      data            = test_data,
      source_crs      = 4326,
      run_taxonomy    = TRUE,
      species_data    = test_species,
      run_coast_dunes = FALSE
    ),
    "parsed must be provided"
  )

  # Commented out: requires spatial layers at runtime
  # res_coast <- RESY:::resy_harmonize_eunis(
  #   data = test_data, source_crs = 4326,
  #   run_taxonomy = FALSE, run_coast_dunes = TRUE
  # )
  # expect_true("Coast_EEA" %in% names(res_coast$sites))
  # expect_true("Dunes_Bohn" %in% names(res_coast$sites))
})

harmonize_sites <- function() {
  data.frame(
    PlotObservationID = 1:3,
    `Altitude (m)` = c(100, 200, 150),
    Longitude = c(12.4924, 13.4050, 14.5058),
    Latitude  = c(41.8902, 52.5200, 46.0569),
    check.names = FALSE
  )
}

test_that("the plot position is also written as DEG_LON and DEG_LAT", {
  s <- resy_harmonize_eunis(harmonize_sites(), source_crs = 4326)$sites
  expect_equal(s$DEG_LON, s$Longitude)
  expect_equal(s$DEG_LAT, s$Latitude)
  expect_equal(s$DEG_LAT, harmonize_sites()$Latitude, tolerance = 1e-6)
})

test_that("coordinates in degrees are read as EPSG:4326 when source_crs is not given", {
  expect_message(
    s <- resy_harmonize_eunis(harmonize_sites())$sites,
    "EPSG:4326"
  )
  ref <- resy_harmonize_eunis(harmonize_sites(), source_crs = 4326)$sites
  expect_equal(s, ref)
})

test_that("projected coordinates without source_crs are refused", {
  utm <- harmonize_sites()
  utm$Longitude <- c(700000, 800000, 900000)
  utm$Latitude  <- c(4650000, 5800000, 5100000)
  expect_error(resy_harmonize_eunis(utm), "not longitude/latitude in degrees")
})

test_that("coordinates in any CRS end up at the same position", {
  deg <- harmonize_sites()
  pts <- sf::st_transform(
    sf::st_as_sf(deg, coords = c("Longitude", "Latitude"), crs = 4326), 25832
  )
  utm <- deg
  utm$Longitude <- sf::st_coordinates(pts)[, 1]
  utm$Latitude  <- sf::st_coordinates(pts)[, 2]

  s_utm <- resy_harmonize_eunis(utm, source_crs = 25832)$sites
  s_deg <- resy_harmonize_eunis(deg, source_crs = 4326)$sites
  expect_equal(s_utm$DEG_LON, s_deg$DEG_LON, tolerance = 1e-6)
  expect_equal(s_utm$DEG_LAT, s_deg$DEG_LAT, tolerance = 1e-6)
  expect_equal(s_utm$Country, s_deg$Country)
})

test_that("a CRS that places no site in Europe is reported", {
  expect_warning(
    resy_harmonize_eunis(harmonize_sites(), source_crs = 25832),
    "No site falls inside the ecoregion base map"
  )
})
