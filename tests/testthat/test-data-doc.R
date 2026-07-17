test_that("dunes_bohn_500mbuffer_epsg25832 dataset loads correctly", {
  # Load the dataset
  data("dunes_bohn_500mbuffer_epsg25832", package = "RESY", envir = environment())
  
  # Check if the dataset exists
  expect_true(exists("dunes_bohn_500mbuffer_epsg25832", envir = environment()))
  
  # Check if it is an sf object
  expect_s3_class(dunes_bohn_500mbuffer_epsg25832, "sf")
  
  # Check CRS
  expect_equal(st_crs(dunes_bohn_500mbuffer_epsg25832)$epsg, 25832)
  
  # Check if it is not empty
  expect_true(nrow(dunes_bohn_500mbuffer_epsg25832) > 0)
})

---
  
  test_that("coastline_regions_epsg25832 dataset loads correctly", {
    # Load the dataset
    data("coastline_regions_epsg25832", package = "RESY", envir = environment())
    
    # Check if the dataset exists
    expect_true(exists("coastline_regions_epsg25832", envir = environment()))
    
    # Check if it is an sf object
    expect_s3_class(coastline_regions_epsg25832, "sf")
    
    # Check CRS
    expect_equal(st_crs(coastline_regions_epsg25832)$epsg, 25832)
    
    # Check if it is not empty
    expect_true(nrow(coastline_regions_epsg25832) > 0)
  })

---
  
  test_that("ecoregions2017_epsg25832 dataset loads correctly", {
    # Load the dataset
    data("ecoregions2017_epsg25832", package = "RESY", envir = environment())
    
    # Check if the dataset exists
    expect_true(exists("ecoregions2017_epsg25832", envir = environment()))
    
    # Check if it is an sf object
    expect_s3_class(ecoregions2017_epsg25832, "sf")
    
    # Check CRS
    expect_equal(st_crs(ecoregions2017_epsg25832)$epsg, 25832)
    
    # Check if it is not empty
    expect_true(nrow(ecoregions2017_epsg25832) > 0)
  })

---
  test_that("europe_resolution_1_epsg25832 dataset loads correctly", {
    # Load the dataset
    data("europe_resolution_1_epsg25832", package = "RESY", envir = environment())
    
    # Check if the dataset exists
    expect_true(exists("europe_resolution_1_epsg25832", envir = environment()))
    
    # Check if it is an sf object
    expect_s3_class(europe_resolution_1_epsg25832, "sf")
    
    # Check CRS
    expect_equal(st_crs(europe_resolution_1_epsg25832)$epsg, 25832)
    
    # Check if it is not empty
    expect_true(nrow(europe_resolution_1_epsg25832) > 0)
  })

---
  test_that("europe_resolution_60_epsg25832 dataset loads correctly", {
    # Load the dataset
    data("europe_resolution_60_epsg25832", package = "RESY", envir = environment())
    
    # Check if the dataset exists
    expect_true(exists("europe_resolution_60_epsg25832", envir = environment()))
    
    # Check if it is an sf object
    expect_s3_class(europe_resolution_60_epsg25832, "sf")
    
    # Check CRS
    expect_equal(st_crs(europe_resolution_60_epsg25832)$epsg, 25832)
    
    # Check if it is not empty
    expect_true(nrow(europe_resolution_60_epsg25832) > 0)
  })
