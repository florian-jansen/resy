library(testthat)
library(sf)

# ---- Helper: Create valid test data ----

.create_valid_data <- function() {
  tibble::tibble(
    PlotObservationID = 1:2,
    `Altitude (m)` = c(100, 200),
    Longitude = c(12.4924, 13.4050),
    Latitude = c(41.8902, 52.5200),
    check.names = FALSE
  )
}

.create_valid_sf <- function() {
  sf::st_sfc(
    sf::st_point(c(12.4924, 41.8902)),
    sf::st_point(c(13.4050, 52.5200)),
    crs = 4326
  ) |>
    sf::st_sf(
      PlotObservationID = 1:2,
      `Altitude (m)` = c(100, 200),
      check.names = FALSE
    ) |>
    sf::st_transform(crs = 25832)
}

# ---- resy_check_eunis: Success cases ----

test_that("resy_check_eunis: valid data frame with all columns returns ok = TRUE", {
  
  data <- .create_valid_data() |>
    dplyr::mutate(
      Ecoreg = "Medi",
      Country = "Italy",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, source_crs = 4326, verbose = FALSE)
  
  expect_type(result, "list")
  expect_true(result$ok)
  expect_length(result$errors, 0)
  expect_length(result$warnings, 0)
  
})

test_that("resy_check_eunis: valid sf object returns ok = TRUE", {
  
  data <- .create_valid_sf() |>
    dplyr::mutate(
      Ecoreg = "Medi",
      Country = "Germany",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  expect_type(result, "list")
  expect_true(result$ok)
  expect_length(result$errors, 0)
  expect_length(result$warnings, 0)
  
})

test_that("resy_check_eunis: verbose = TRUE prints message on success", {
  
  data <- .create_valid_data() |>
    dplyr::mutate(
      Ecoreg = "Medi",
      Country = "Italy",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  expect_message(
    RESY::resy_check_eunis(data, source_crs = 4326, verbose = TRUE),
    "EUNIS check: OK"
  )
  
})

# ---- resy_check_eunis: Coordinate errors ----

test_that("resy_check_eunis: missing source_crs for non-sf data sets ok = FALSE", {
  
  data <- .create_valid_data()
  
  result <- RESY::resy_check_eunis(data, source_crs = NULL, verbose = FALSE)
  
  expect_type(result, "list")
  expect_false(result$ok)
  expect_length(result$errors, 1)
  expect_match(result$errors[1], "Coordinate error")
  
})

test_that("resy_check_eunis: missing Longitude/Latitude columns sets ok = FALSE", {
  
  data <- tibble::tibble(
    PlotObservationID = 1,
    `Altitude (m)` = 100
  )
  
  result <- RESY::resy_check_eunis(data, source_crs = 4326, verbose = FALSE)
  
  expect_false(result$ok)
  expect_length(result$errors, 1)
  expect_match(result$errors[1], "Coordinate error")
  
})

test_that("resy_check_eunis: coordinate error halts further checks", {
  
  data <- tibble::tibble(
    PlotObservationID = 1,
    `Altitude (m)` = 100
  )
  
  result <- RESY::resy_check_eunis(data, source_crs = 4326, verbose = FALSE)
  
  # Should exit early with coordinate error, not checking other columns
  expect_length(result$errors, 1)
  
})

# ---- resy_check_eunis: PlotObservationID ----

test_that("resy_check_eunis: missing PlotObservationID is an error", {
  
  data <- .create_valid_sf() |>
    dplyr::select(-PlotObservationID) |>
    dplyr::mutate(
      Ecoreg = "Medi",
      Country = "Italy",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  expect_false(result$ok)
  expect_true(
    any(grepl("PlotObservationID", result$errors))
  )
  
})

# ---- resy_check_eunis: Altitude ----

test_that("resy_check_eunis: missing Altitude (m) generates warning", {
  
  data <- .create_valid_sf() |>
    dplyr::select(-`Altitude (m)`) |>
    dplyr::mutate(
      Ecoreg = "Medi",
      Country = "Italy",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  expect_true(result$ok)  # Not an error, just a warning
  expect_true(
    any(grepl('Altitude.*missing', result$warnings))
  )
  
})

test_that("resy_check_eunis: NA in Altitude (m) generates warning", {
  
  data <- .create_valid_sf() |>
    dplyr::mutate(
      `Altitude (m)` = c(100, NA),
      Ecoreg = "Medi",
      Country = "Italy",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  expect_true(result$ok)  # Not an error
  expect_true(
    any(grepl('Altitude.*NA', result$warnings))
  )
  
})

# ---- resy_check_eunis: Ecoreg ----

test_that("resy_check_eunis: missing Ecoreg generates warning", {
  
  data <- .create_valid_sf() |>
    dplyr::mutate(
      Country = "Italy",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  expect_true(result$ok)
  expect_true(
    any(grepl("Ecoreg.*missing", result$warnings))
  )
  
})

test_that("resy_check_eunis: NA in Ecoreg generates warning", {
  
  data <- .create_valid_sf() |>
    dplyr::mutate(
      Ecoreg = c("Medi", NA),
      Country = "Italy",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  expect_true(result$ok)
  expect_true(
    any(grepl("Ecoreg.*NA", result$warnings))
  )
  
})

# ---- resy_check_eunis: Country ----

test_that("resy_check_eunis: missing Country generates warning", {
  
  data <- .create_valid_sf() |>
    dplyr::mutate(
      Ecoreg = "Medi",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  expect_true(result$ok)
  expect_true(
    any(grepl("Country.*missing", result$warnings))
  )
  
})

test_that("resy_check_eunis: NA in Country generates warning", {
  
  data <- .create_valid_sf() |>
    dplyr::mutate(
      Ecoreg = "Medi",
      Country = c("Italy", NA),
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  expect_true(result$ok)
  expect_true(
    any(grepl("Country.*NA", result$warnings))
  )
  
})

# ---- resy_check_eunis: Coastal / dune columns ----

test_that("resy_check_eunis: missing Coast_EEA generates warning", {
  
  data <- .create_valid_sf() |>
    dplyr::mutate(
      Ecoreg = "Medi",
      Country = "Italy",
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  expect_true(
    any(grepl("Coast_EEA", result$warnings))
  )
  
})

test_that("resy_check_eunis: missing Dunes_Bohn generates warning", {
  
  data <- .create_valid_sf() |>
    dplyr::mutate(
      Ecoreg = "Medi",
      Country = "Italy",
      Coast_EEA = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  expect_true(
    any(grepl("Dunes_Bohn", result$warnings))
  )
  
})

test_that("resy_check_eunis: all optional columns present removes coastal/dune warnings", {
  
  data <- .create_valid_sf() |>
    dplyr::mutate(
      Ecoreg = "Medi",
      Country = "Italy",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  # Should not have warnings about Coast_EEA or Dunes_Bohn
  expect_false(any(grepl("Coast_EEA|Dunes_Bohn", result$warnings)))
  
})

# ---- resy_check_eunis: Multiple errors/warnings ----

test_that("resy_check_eunis: multiple issues are all reported", {
  
  data <- .create_valid_sf() |>
    dplyr::select(-PlotObservationID, -`Altitude (m)`)
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  expect_false(result$ok)
  expect_true(any(grepl("PlotObservationID", result$errors)))
  expect_true(any(grepl("Altitude", result$warnings)))
  
})

test_that("resy_check_eunis: duplicate messages are removed", {
  
  data <- .create_valid_sf() |>
    dplyr::mutate(
      Ecoreg = c(NA, NA),
      Country = "Italy",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, verbose = FALSE)
  
  # Should have unique warnings, not repeated
  ecoreg_warnings <- result$warnings[grepl("Ecoreg", result$warnings)]
  expect_length(ecoreg_warnings, 1)
  
})

# ---- resy_check_eunis: Return structure ----

test_that("resy_check_eunis: return value has correct structure", {
  
  data <- .create_valid_data() |>
    dplyr::mutate(
      Ecoreg = "Medi",
      Country = "Italy",
      Coast_EEA = 0,
      Dunes_Bohn = 0
    )
  
  result <- RESY::resy_check_eunis(data, source_crs = 4326, verbose = FALSE)
  
  expect_named(result, c("ok", "errors", "warnings"))
  expect_type(result$ok, "logical")
  expect_length(result$ok, 1)
  expect_type(result$errors, "character")
  expect_type(result$warnings, "character")
  
})

test_that("resy_check_eunis: verbose prints FAILED message on coordinate error", {
  
  data <- tibble::tibble(
    PlotObservationID = 1,
    `Altitude (m)` = 100
  )
  
  expect_message(
    RESY::resy_check_eunis(data, source_crs = NULL, verbose = TRUE),
    "EUNIS check: FAILED.*coordinate"
  )
  
})

test_that("resy_check_eunis: verbose prints error/warning counts", {
  
  data <- .create_valid_sf() |>
    dplyr::select(-PlotObservationID)
  
  expect_message(
    result <- RESY::resy_check_eunis(data, verbose = TRUE),
    "error\\(s\\)|warning\\(s\\)"
  )
  
})
