test_that('geography agrees with GEOS at borders, holes, multipart features and coast buffers', {
  skip_if_not_installed('sf')
  withr::local_seed(25832)
  layers <- lapply(c(eco = 'ecoregions2017_epsg25832', country = 'europe_resolution_1_epsg25832',
                    coast = 'coastline_regions_epsg25832', dunes = 'dunes_bohn_500mbuffer_epsg25832'),
                   RESY:::.resy_gis)
  refs <- Map(geometry_sf, layers, names(layers) == 'coast')
  eco <- geometry_samples(layers$eco, 20000)
  country <- geometry_samples(layers$country, 20000)
  dunes <- geometry_samples(layers$dunes, 15000)
  holes <- geometry_samples(layers$eco, 10000, which(layers$eco$ring > 1L))
  part_counts <- tapply(layers$country$part, layers$country$feature, function(x) length(unique(x)))
  multipart <- as.integer(names(part_counts)[part_counts > 1L])
  parts <- geometry_samples(layers$country, 10000, which(layers$country$feature %in% multipart))
  coast <- geometry_samples(layers$coast, 25002, offset = 0)
  distance <- rep(c(5000 - 1e-6, 5000, 5000 + 1e-6), 8334)
  coast$xy <- coast$xy + distance * coast$normal
  points <- rbind(eco$xy, country$xy, dunes$xy, holes$xy, parts$xy, coast$xy,
                  eco$a[1:1000, ], (eco$a + eco$b)[1:1000, ]/2,
                  country$a[1:1000, ], (country$a + country$b)[1:1000, ]/2,
                  dunes$a[1:1000, ], (dunes$a + dunes$b)[1:1000, ]/2,
                  holes$a[1:1000, ], (holes$a + holes$b)[1:1000, ]/2)
  category <- rep(c('ecoregion', 'country', 'dunes', 'holes', 'multipart', 'coast',
                    'eco_vertex','eco_edge','country_vertex','country_edge',
                    'dune_vertex','dune_edge','hole_vertex','hole_edge'),
                  c(20000,20000,15000,10000,10000,25002,rep(1000,8)))
  expect_equal(nrow(points), 108002)
  overlap <- c(eco = 0L, country = 0L)
  interior_overlap <- overlap
  max_error <- 0
  for (start in seq.int(1L, nrow(points), by = 2000L)) {
    at <- seq.int(start, min(start+1999L,nrow(points)))
    xy <- points[at, , drop = FALSE]
    expected <- geometry_reference(xy, refs)
    input <- data.frame(id = seq_len(nrow(xy)), Longitude = xy[, 1], Latitude = xy[, 2])
    actual <- RESY:::.resy_check_coordinates(input, 25832, FALSE)
    actual <- RESY:::.resy_assign_country(RESY:::.resy_assign_ecoregions(actual))
    flags <- RESY:::.resy_assign_coast_dunes(actual)
    actual$Coast_EEA <- flags$Coast_EEA; actual$Dunes_Bohn <- flags$Dunes_Bohn
    for (column in names(expected)) {
      expect_identical(actual[[column]], expected[[column]], info = paste(start,column))
    }
    overlap <- overlap + vapply(c('eco','country'), function(k)
      sum(lengths(sf::st_intersects(sf::st_as_sf(input,coords=c('Longitude','Latitude'),crs=25832),refs[[k]]))>1L), integer(1))
    p <- sf::st_as_sf(input,coords=c('Longitude','Latitude'),crs=25832)
    interior_overlap <- interior_overlap + vapply(c('eco','country'), function(k)
      sum(lengths(sf::st_within(p,refs[[k]]))>1L), integer(1))
    ll <- sf::st_coordinates(sf::st_transform(p,4326))
    max_error <- max(max_error, max(abs(RESY:::.resy_project(ll) - xy)))
    expect_lt(max_error, .001)
  }
  cat('\nGeometry categories:', paste(names(table(category)), table(category), collapse='; '),
      '\nOverlapping matches:', paste(names(overlap), overlap, collapse='; '),
      '\nInterior overlaps:', paste(names(interior_overlap), interior_overlap, collapse='; '),
      '\nProjection maximum error (m):', max_error, '\n')
})

test_that('bundled examples have identical geographic columns', {
  skip_if_not_installed('sf')
  si <- read.csv(system.file('extdata','data_example_sites.csv',package='RESY'))
  layers <- lapply(c(eco='ecoregions2017_epsg25832',country='europe_resolution_1_epsg25832',
                    coast='coastline_regions_epsg25832',dunes='dunes_bohn_500mbuffer_epsg25832'),RESY:::.resy_gis)
  refs <- Map(geometry_sf,layers,names(layers)=='coast')
  xy <- sf::st_coordinates(sf::st_transform(sf::st_as_sf(si,coords=c('Longitude','Latitude'),crs=4326),25832))
  ref <- geometry_reference(xy,refs)
  actual <- suppressWarnings(resy_harmonize_eunis(si,run_coast_dunes=TRUE,verbose=FALSE)$sites)
  expect_equal(nrow(actual),nrow(ref))
  for (column in setdiff(names(ref),'id')) expect_identical(actual[[column]],ref[[column]])
})
