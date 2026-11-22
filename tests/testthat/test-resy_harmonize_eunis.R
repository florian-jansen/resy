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
  
  res <- 
    suppressWarnings(
      RESY:::resy_harmonize_eunis(
        data = test_data,
        source_crs = 4326,
        run_taxonomy = FALSE,
        run_coast_dunes = FALSE,
        verbose = FALSE
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
  
  res <- 
    suppressWarnings(
      RESY:::resy_harmonize_eunis(
        data = test_data,
        source_crs = 4326,
        run_taxonomy = FALSE,
        run_coast_dunes = FALSE,
        verbose = FALSE
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
  
  res <- 
    suppressWarnings(
      RESY:::resy_harmonize_eunis(
        data = test_sf,
        source_crs = NULL,  # Should be ignored for sf input
        run_taxonomy = FALSE,
        run_coast_dunes = FALSE,
        verbose = FALSE
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
      source_crs = 4326,
      verbose = FALSE
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
      source_crs = 4326,
      verbose = FALSE
    ),
    '"Longitude" and/or "Latitude" columns are missing'
  )
  
})

test_that("resy_harmonize_eunis reads degree coordinates as EPSG:4326 without source_crs", {
  
  test_data <- create_test_data()
  
  # NULL is now valid for degree coordinates; identical to explicit EPSG:4326
  res_null <- RESY:::resy_harmonize_eunis(
    data = test_data, source_crs = NULL, run_coast_dunes = FALSE,
    verbose = FALSE
    )
  res_4326 <- RESY:::resy_harmonize_eunis(
    data = test_data, source_crs = 4326, run_coast_dunes = FALSE,
    verbose = FALSE
    )
  expect_equal(res_null$sites, res_4326$sites)
  
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
      run_coast_dunes = FALSE,
      verbose = FALSE
    ),
    '"Altitude \\(m\\)" is missing'
  )
  
})

test_that("resy_harmonize_eunis tolerates NA values in Altitude without warning", {
  
  test_data <- create_test_data()
  test_data$`Altitude (m)`[1] <- NA
  
  res <- 
    suppressWarnings(
      RESY:::resy_harmonize_eunis(
        data = test_data,
        source_crs = 4326,
        run_taxonomy = FALSE,
        run_coast_dunes = FALSE,
        verbose = FALSE
      )
    )
  expect_equal(nrow(res$sites), nrow(test_data))
  expect_true(is.na(res$sites$`Altitude (m)`[1]))
  
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
  s <- suppressWarnings(
    resy_harmonize_eunis(
      harmonize_sites(), source_crs = 4326, verbose = FALSE
      )$sites
    )
  expect_equal(s$DEG_LON, s$Longitude)
  expect_equal(s$DEG_LAT, s$Latitude)
  expect_equal(s$DEG_LAT, harmonize_sites()$Latitude, tolerance = 1e-6)
})

test_that("coordinates in degrees are read as EPSG:4326 when source_crs is not given", {
  suppressMessages(
    expect_message(
      s <- suppressWarnings(
        resy_harmonize_eunis(harmonize_sites(), verbose = TRUE)$sites
      ),
      "EPSG:4326"
    )
  )
  ref <- suppressWarnings(
    resy_harmonize_eunis(
      harmonize_sites(), source_crs = 4326, verbose = FALSE
    )$sites
  )
  expect_equal(s, ref)
})

test_that("projected coordinates without source_crs are refused", {
  utm <- harmonize_sites()
  utm$Longitude <- c(700000, 800000, 900000)
  utm$Latitude  <- c(4650000, 5800000, 5100000)
  expect_error(
    resy_harmonize_eunis(utm, verbose = FALSE),
    "not longitude/latitude in degrees"
    )
})

test_that("coordinates in any CRS end up at the same position", {
  deg <- harmonize_sites()
  pts <- sf::st_transform(
    sf::st_as_sf(deg, coords = c("Longitude", "Latitude"), crs = 4326), 25832
  )
  utm <- deg
  utm$Longitude <- sf::st_coordinates(pts)[, 1]
  utm$Latitude  <- sf::st_coordinates(pts)[, 2]

  s_utm <- suppressWarnings(
    resy_harmonize_eunis(utm, source_crs = 25832, verbose = FALSE)$sites
    )
  s_deg <- suppressWarnings(
    resy_harmonize_eunis(deg, source_crs = 4326, verbose = FALSE)$sites
    )
  expect_equal(s_utm$DEG_LON, s_deg$DEG_LON, tolerance = 1e-6)
  expect_equal(s_utm$DEG_LAT, s_deg$DEG_LAT, tolerance = 1e-6)
  expect_equal(s_utm$Country, s_deg$Country)
})

test_that("a CRS that places no site in Europe is reported", {
  expect_warning(
    expect_warning(
      resy_harmonize_eunis(
        harmonize_sites(),
        source_crs = 25832,
        verbose = FALSE
      ),
      "No site falls inside the ecoregion base map"
    ),
    "No site falls inside the country base map"
  )
})
