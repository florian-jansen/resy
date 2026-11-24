# Each bundled GIS dataset loads as a non-empty coordinate list in EPSG:25832, under
# the object name the package code reads it by.

datasets <- c(
  dunes_bohn_500mbuffer_epsg25832 = "bohn",
  coastline_regions_epsg25832     = "co",
  ecoregions2017_epsg25832        = "ecoregions2017_epsg25832",
  europe_resolution_1_epsg25832   = "europe_resolution_1_epsg25832",
  europe_resolution_60_epsg25832  = "europe_resolution_60_epsg25832"
)

for (ds in names(datasets)) {
  test_that(paste(ds, "dataset loads correctly"), {
    env <- new.env()
    utils::data(list = ds, package = "RESY", envir = env)
    obj <- datasets[[ds]]

    expect_true(exists(obj, envir = env, inherits = FALSE))
    x <- get(obj, envir = env)
    expect_type(x, "list")
    expect_identical(x$crs, 25832L)
    expect_true(nrow(x$attributes) > 0)
    expect_length(x$feature, length(x$rings))
    expect_equal(nrow(x$ring_bbox), length(x$rings))
  })
}
