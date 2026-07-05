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
