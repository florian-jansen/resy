library(testthat)
library(sf)
library(tibble)

test_that("transforms sf with non-25832 CRS to EPSG:25832 and returns sf", {
  d <- tibble::tibble(
    PlotObservationID = 1L,
    Ecoreg = 1L,
    Country = "Austria",
    `Altitude (m)` = 100,
    Coast_EEA = FALSE,
    Dunes_Bohn = FALSE,
    lon = 9,
    lat = 48
  ) |> sf::st_as_sf(coords = c("lon", "lat"), crs = 4326)
  
  expect_message(res <- resy_check_data(d), "Transforming coordinates")
  expect_s3_class(res, "sf")
  expect_equal(sf::st_crs(res)$epsg, 25832)
  expect_true("PlotObservationID" %in% names(res))
})

test_that("errors when PlotObservationID is missing", {
  df <- tibble::tibble(Longitude = 9, Latitude = 48)
  expect_error(
    resy_check_data(df, source_crs = 4326),
    'The column "PlotObservationID" is missing'
    )
})

test_that("warns when Altitude (m) is NA", {
  d <- tibble::tibble(
    PlotObservationID = 1L,
    Ecoreg = 1L,
    Country = "Austria",
    `Altitude (m)` = NA_real_,
    Coast_EEA = FALSE,
    Dunes_Bohn = FALSE,
    lon = 9, lat = 48
  ) |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = 4326)
  
  expect_warning(resy_check_data(d), 'NAs in "Altitude \\(m\\)"')
})

test_that("warns when Ecoreg is NA when provided", {
  d <- tibble::tibble(
    PlotObservationID = 1L,
    Ecoreg = NA_integer_,
    Country = "Austria",
    `Altitude (m)` = 10,
    Coast_EEA = FALSE,
    Dunes_Bohn = FALSE,
    lon = 9, lat = 48
  ) |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = 4326)
  
  expect_warning(resy_check_data(d), 'NAs in "Ecoreg" from provided data')
})

test_that("warns when Country is NA when provided", {
  d <- tibble::tibble(
    PlotObservationID = 1L,
    Ecoreg = 1L,
    Country = NA_character_,
    `Altitude (m)` = 10,
    Coast_EEA = FALSE,
    Dunes_Bohn = FALSE,
    lon = 9, lat = 48
  ) |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = 4326)
  
  expect_warning(resy_check_data(d), 'NAs in "Country" from provided data')
})

test_that("warns when Coast_EEA and Dunes_Bohn are missing", {
  # Provide Ecoreg/Country so assignments are not triggered
  d <- tibble::tibble(
    PlotObservationID = 1L,
    Ecoreg = 1L,
    Country = "Austria",
    `Altitude (m)` = 10,
    lon = 9, lat = 48
  ) |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = 4326)
  
  # resy_check_data should warn about missing Coast_EEA and Dunes_Bohn
  warnings <- testthat::capture_warnings(resy_check_data(d))
  expect_true(any(grepl("Coast_EEA", warnings)))
  expect_true(any(grepl("Dunes_Bohn", warnings)))
})
