library(testthat)
library(sf)

# ---- Test data helpers ----

# Create test data with valid European coordinates
create_test_data <- function(
    lon = c(8.6753, 2.3522, 16.3738),
    lat = c(50.1109, 48.8566, 48.2082),
    altitude = c(100, 50, 200)
    ) {
  
  data.frame(
    PlotObservationID = seq_along(lon),
    `Altitude (m)` = altitude,
    Longitude = lon,
    Latitude = lat,
    check.names = FALSE
  )
  
}

# Create test species data
create_test_species <- function(n_plots = 3) {
  
  data.frame(
    PlotObservationID = rep(1:n_plots, each = 2),
    species = c(
      "Lemna gibba", "Lemna minor",
      "Poa annua", "Poa pratensis",
      "Carex acuta", "Juncus effusus"
    ),
    cover = c(50, 30, 20, 40, 15, 25)
  )
  
}

# ---- Test: Basic functionality (data frame input) ----

test_that("resy_harmonize_eunis accepts data frame with required columns", {
  
  test_data <- create_test_data()
  
  res <- suppressWarnings(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326,
      run_taxonomy = FALSE,
      run_coast_dunes = FALSE
    )
  )
  
  expect_type(res, "list")
  expect_true(all(c("sites", "species_checked") %in% names(res)))
  expect_s3_class(res$sites, "data.frame")
  expect_equal(nrow(res$sites), nrow(test_data))
  expect_null(res$species_checked)
  
})

# ---- Test: Output structure and coordinate handling ----

test_that("resy_harmonize_eunis outputs correct columns", {
  
  test_data <- create_test_data()
  
  res <- suppressWarnings(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326,
      run_taxonomy = FALSE,
      run_coast_dunes = FALSE
    )
  )
  
  # Check required columns are present
  expect_true("PlotObservationID" %in% names(res$sites))
  expect_true("Longitude" %in% names(res$sites))
  expect_true("Latitude" %in% names(res$sites))
  
  # Check coordinates are valid WGS84
  expect_true(all(res$sites$Longitude >= -180 & res$sites$Longitude <= 180))
  expect_true(all(res$sites$Latitude >= -90 & res$sites$Latitude <= 90))
  
  # Check geometry is dropped
  expect_false(inherits(res$sites, "sf"))
  
})

# ---- Test: sf input handling ----

test_that("resy_harmonize_eunis accepts sf objects", {
  
  test_data <- create_test_data()
  test_sf <- sf::st_as_sf(
    test_data,
    coords = c("Longitude", "Latitude"),
    crs = 4326
  )
  
  res <- suppressWarnings(
    RESY:::resy_harmonize_eunis(
      data = test_sf,
      source_crs = NULL,  # Should be ignored for sf input
      run_taxonomy = FALSE,
      run_coast_dunes = FALSE
    )
  )
  
  expect_equal(nrow(res$sites), nrow(test_data))
  expect_false(inherits(res$sites, "sf"))
  
})

# ---- Test: Missing required columns ----

test_that("resy_harmonize_eunis errors when PlotObservationID is missing", {
  
  test_data <- create_test_data()
  test_data$PlotObservationID <- NULL
  
  expect_error(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326
    ),
    'Column "PlotObservationID" is missing'
  )
  
})

test_that("resy_harmonize_eunis errors when coordinates are missing (data frame)", {
  
  test_data <- create_test_data()
  test_data$Longitude <- NULL
  
  expect_error(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326
    ),
    'Data frame must contain columns "Longitude" and "Latitude"'
  )
  
})

test_that("resy_harmonize_eunis errors when source_crs is missing (data frame)", {
  
  test_data <- create_test_data()
  
  expect_error(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = NULL
    ),
    "source_crs must be provided for plain data frames"
  )
  
})

# ---- Test: Missing optional data ----

test_that("resy_harmonize_eunis warns about missing Altitude column", {
  
  test_data <- create_test_data()
  test_data$`Altitude (m)` <- NULL
  
  expect_warning(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326,
      run_taxonomy = FALSE,
      run_coast_dunes = FALSE
    ),
    '"Altitude \\(m\\)" is missing'
  )
  
})

test_that("resy_harmonize_eunis warns about NA values in Altitude", {
  
  test_data <- create_test_data()
  test_data$`Altitude (m)`[1] <- NA
  
  expect_warning(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326,
      run_taxonomy = FALSE,
      run_coast_dunes = FALSE
    ),
    'NA values in "Altitude \\(m\\)"'
  )
  
})

# ---- Test: Taxonomy validation ----

test_that("resy_harmonize_eunis errors when run_taxonomy = TRUE without species_data", {
  
  test_data <- create_test_data()
  
  expect_error(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326,
      run_taxonomy = TRUE,
      species_data = NULL,
      parsed = NULL,
      run_coast_dunes = FALSE
    ),
    "species_data must be provided when run_taxonomy = TRUE"
  )
  
})

test_that("resy_harmonize_eunis errors when run_taxonomy = TRUE without parsed", {
  
  test_data <- create_test_data()
  test_species <- create_test_species()
  
  expect_error(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326,
      run_taxonomy = TRUE,
      species_data = test_species,
      parsed = NULL,
      run_coast_dunes = FALSE
    ),
    "parsed must be provided when run_taxonomy = TRUE"
  )
  
})

# ---- Test: Ecoregion assignment ----

test_that("resy_harmonize_eunis assigns ecoregions", {
  
  test_data <- create_test_data()
  
  res <- suppressWarnings(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326,
      run_taxonomy = FALSE,
      run_coast_dunes = FALSE
    )
  )
  
  # Check that Ecoreg column is present
  expect_true("Ecoreg" %in% names(res$sites))
  
})

test_that("resy_harmonize_eunis respects pre-assigned ecoregions", {
  
  test_data <- create_test_data()
  test_data$Ecoreg <- "TestEcoreg"
  
  res <- suppressWarnings(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326,
      run_taxonomy = FALSE,
      run_coast_dunes = FALSE
    )
  )
  
  # Pre-assigned values should be preserved
  expect_equal(res$sites$Ecoreg, rep("TestEcoreg", 3))
  
})

# ---- Test: Country assignment ----

test_that("resy_harmonize_eunis assigns countries", {
  
  test_data <- create_test_data()
  
  res <- suppressWarnings(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326,
      run_taxonomy = FALSE,
      run_coast_dunes = FALSE
    )
  )
  
  # Check that Country column is present
  expect_true("Country" %in% names(res$sites))
  
})

# ---- Test: CRS handling ----

test_that("resy_harmonize_eunis transforms to UTM 32N internally", {
  
  test_data <- create_test_data()
  
  # This test ensures the function doesn't error during CRS transformation
  res <- suppressWarnings(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326,
      run_taxonomy = FALSE,
      run_coast_dunes = FALSE
    )
  )
  
  expect_equal(nrow(res$sites), nrow(test_data))
  
})

# ---- Test: Missing coordinates error ----

test_that("resy_harmonize_eunis errors when coordinates contain NA values", {
  
  test_data <- create_test_data()
  test_data$Latitude[1] <- NA
  
  expect_error(
    RESY:::resy_harmonize_eunis(
      data = test_data,
      source_crs = 4326,
      run_taxonomy = FALSE,
      run_coast_dunes = FALSE
    ),
    "missing values in coordinates not allowed"
  )
  
})

# ---- Test: Coast/dunes (commented - requires spatial layers) ----

# test_that("resy_harmonize_eunis assigns coast and dune flags", {
#   test_data <- create_test_data()
#   
#   res <- suppressWarnings(
#     RESY:::resy_harmonize_eunis(
#       data = test_data,
#       source_crs = 4326,
#       run_taxonomy = FALSE,
#       run_coast_dunes = TRUE,
#       coast_buffer = 5000
#     )
#   )
#   
#   expect_true("Coast_EEA" %in% names(res$sites))
#   expect_true("Dunes_Bohn" %in% names(res$sites))
#   expect_true(is.logical(res$sites$Coast_EEA))
#   expect_true(is.logical(res$sites$Dunes_Bohn))
# })
