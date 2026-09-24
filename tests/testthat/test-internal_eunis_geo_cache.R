# .resy_gis() is the one accessor for the GIS layers in data/. A layer is read
# on first use and kept for the session, so attaching RESY reads no layer and a
# second call does not read the file again. The tests pin that every registered
# layer loads as the sf object stored in its file, that a cached layer is served
# without re-reading, and that an unknown layer name fails.

test_that("every registered GIS layer loads as the object stored in its file", {
  for (ds in names(RESY:::.resy_gis_layers)) {
    env <- new.env()
    utils::data(list = ds, package = "RESY", envir = env)
    obj <- RESY:::.resy_gis(ds)
    expect_s3_class(obj, "sf")
    expect_identical(obj, get(RESY:::.resy_gis_layers[[ds]], envir = env))
  }
})

test_that("a cached layer is served without reading the file again", {
  cache <- RESY:::.resy_gis_cache
  ds <- "dunes_bohn_500mbuffer_epsg25832"
  RESY:::.resy_gis(ds)
  real <- get(ds, envir = cache)
  withr::defer(assign(ds, real, envir = cache))

  sentinel <- structure(list(), class = "cached_sentinel")
  assign(ds, sentinel, envir = cache)
  expect_identical(RESY:::.resy_gis(ds), sentinel)
})

test_that("the geo helpers read their layers through the cache", {
  pts <- sf::st_as_sf(
    data.frame(PlotObservationID = 1L, x = 701327, y = 5364375),
    coords = c("x", "y"), crs = 25832
  )
  a <- RESY:::.resy_assign_ecoregions(pts)
  b <- RESY:::.resy_assign_ecoregions(pts)
  expect_identical(a, b)
  expect_true(exists("ecoregions2017_epsg25832",
                     envir = RESY:::.resy_gis_cache, inherits = FALSE))
})

test_that("an unknown layer name is an error", {
  expect_error(RESY:::.resy_gis("no_such_layer"), "Unknown GIS layer")
})
