example_species <- function() {
  utils::read.csv(
    system.file("extdata", "data_example_species.csv", package = "RESY")
  )
}

test_that("Darwin Core columns classify like the RESY columns", {
  sp <- example_species()
  header <- unique(sp["PlotObservationID"])

  res <- suppressMessages(
    resy_classify(sp, header, scheme = "Apennine-test",
                  species_col = "scientificName", mc = 1L)
  )

  dwc <- data.frame(
    eventID              = sp$PlotObservationID,
    scientificName       = sp$scientificName,
    organismQuantity     = sp$Cover_Perc,
    organismQuantityType = "% cover"
  )
  dwc_header <- data.frame(eventID = unique(sp$PlotObservationID))
  res_dwc <- suppressMessages(
    resy_classify(dwc, dwc_header, scheme = "Apennine-test", mc = 1L)
  )

  key <- function(r) {
    out <- as.data.frame(r$result.classification)
    out[order(out[[1]]), , drop = FALSE]
  }
  expect_equal(key(res_dwc), key(res), ignore_attr = TRUE)
})

test_that("cover is taken from organismQuantity only for percent cover", {
  d <- data.frame(organismQuantity = c(10, 20),
                  organismQuantityType = c("% cover", "percent cover"))
  expect_equal(RESY:::.resy_dwc_cover(d), c(10, 20))

  d$organismQuantityType[2] <- "Braun-Blanquet Scale"
  expect_error(RESY:::.resy_dwc_cover(d), "Braun-Blanquet Scale", fixed = TRUE)

  expect_null(RESY:::.resy_dwc_cover(data.frame(organismQuantity = 1)))
})

test_that("altitude is taken from the Darwin Core elevation range", {
  d <- data.frame(minimumElevationInMeters = c(100, 200, NA),
                  maximumElevationInMeters = c(100, 300, 400))
  expect_warning(alt <- RESY:::.resy_dwc_elevation(d), "1 plot(s)", fixed = TRUE)
  expect_equal(alt, c(100, 250, 400))

  expect_equal(
    RESY:::.resy_dwc_elevation(data.frame(minimumElevationInMeters = 50)), 50
  )
  expect_null(RESY:::.resy_dwc_elevation(data.frame(x = 1)))
})

test_that("Altitude is accepted for Altitude (m) before the elevation range", {
  d <- data.frame(Altitude = 120, minimumElevationInMeters = 500)
  expect_equal(RESY:::.resy_adopt_columns(d, "Altitude (m)")$`Altitude (m)`, 120)

  d$Altitude <- NULL
  expect_equal(RESY:::.resy_adopt_columns(d, "Altitude (m)")$`Altitude (m)`, 500)
})

test_that("RESY columns already present are kept", {
  d <- data.frame(Country = "Italy", country = "Austria")
  expect_equal(RESY:::.resy_adopt_columns(d, "Country")$Country, "Italy")

  dt <- data.table::data.table(country = "Austria")
  out <- RESY:::.resy_adopt_columns(dt, "Country")
  expect_equal(out$Country, "Austria")
  expect_false("Country" %in% names(dt))
})

test_that("site checks accept Darwin Core names", {
  d <- data.frame(eventID = "p1", decimalLongitude = 11.5,
                  decimalLatitude = 43.3, country = "Italy",
                  minimumElevationInMeters = 300,
                  maximumElevationInMeters = 300)
  sf_sites <- RESY:::.resy_check_coordinates(d, verbose = FALSE)
  expect_true(all(c("PlotObservationID", "Country", "Altitude (m)") %in%
                    names(sf_sites)))
  expect_equal(sf_sites$PlotObservationID, "p1")
  expect_equal(sf_sites$`Altitude (m)`, 300)
})

test_that("resy_check_taxonomy finds scientificName without col", {
  parsed <- resy_load_expert(scheme = "Apennine-test")
  obs <- data.frame(scientificName = c("Fagus sylvatica", "Planta inventa"))
  checked <- resy_check_taxonomy(obs, parsed)
  expect_equal(sum(checked$matched), 1)
})
