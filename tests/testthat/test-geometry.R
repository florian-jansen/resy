test_that('ring boundaries, holes and multipart features retain all matches', {
  square <- function(x, y, size) cbind(x + c(0,size,size,0,0), y + c(0,0,size,size,0))
  rings <- list(square(0,0,10), square(2,2,2), square(20,0,5), square(5,0,10))
  layer <- list(rings=rings, feature=c(1L,1L,1L,2L), part=c(1L,1L,2L,3L),
                ring=c(1L,2L,1L,1L), attributes=data.frame(code=c('a','b')),
                ring_bbox=do.call(rbind,lapply(rings,RESY:::.resy_bbox)))
  xy <- rbind(c(0,0),c(2,3),c(3,3),c(7,5),c(22,2),c(30,30),c(10,10))
  expected <- list(1L,1L,integer(),c(1L,2L),1L,integer(),c(1L,2L))
  expect_identical(RESY:::.resy_intersects(xy,layer),expected)
  layer$rings <- lapply(layer$rings,function(r) r[nrow(r):1,])
  expect_identical(RESY:::.resy_intersects(xy,layer),expected)
  input <- data.frame(id=seq_len(nrow(xy)),Longitude=xy[,1],Latitude=xy[,2])
  joined <- RESY:::.resy_geo_join(RESY:::.resy_check_coordinates(input,25832,FALSE),layer)
  expect_identical(joined$id,c(1L,2L,3L,4L,4L,5L,6L,7L,7L))
  expect_identical(joined$code,c('a','a',NA,'a','b','a',NA,'a','b'))
})

test_that('segment distance includes the buffer boundary and clamps endpoints', {
  xy <- rbind(c(5,5000-1e-6),c(5,5000),c(5,5000+1e-6),c(-3,4),c(13,4))
  layer <- list(segments=matrix(c(0,0,10,0),nrow=1), segment_bbox=matrix(c(0,0,10,0),nrow=1),
                segment_feature=1L)
  expect_identical(lengths(RESY:::.resy_within_distance(xy,layer,5000)),c(1L,1L,0L,1L,1L))
  d <- RESY:::.resy_segment_distance(xy[,1],xy[,2],rep(0,5),rep(0,5),rep(10,5),rep(0,5))
  expect_identical(d,c(5000-1e-6,5000,5000+1e-6,5,5))
})

test_that('plain coordinate input needs no spatial namespace', {
  sites <- data.frame(PlotObservationID=1:2,Longitude=c(9,16),Latitude=c(48,48))
  out <- suppressWarnings(resy_harmonize_eunis(sites,run_coast_dunes=TRUE,verbose=FALSE)$sites)
  expect_s3_class(out,'tbl_df')
  expect_equal(out$Longitude,sites$Longitude,tolerance=1e-10)
  expect_equal(out$Latitude,sites$Latitude,tolerance=1e-10)
  expect_false('geometry' %in% names(out))
  expect_null(attr(out,'resy_crs'))
  projected <- RESY:::.resy_check_coordinates(sites,verbose=FALSE)
  expect_identical(attr(projected[2:1,],'resy_crs'),25832)
  expect_identical(RESY:::.resy_coordinates(projected[2:1,]),RESY:::.resy_coordinates(projected)[2:1,])
})

test_that('projection agrees with PROJ across Europe and rejects its singularity', {
  skip_if_not_installed('sf')
  withr::local_seed(32)
  ll <- cbind(runif(100000,-25,45),runif(100000,30,72))
  ref <- sf::st_coordinates(sf::st_transform(sf::st_as_sf(data.frame(lon=ll[,1],lat=ll[,2]),
    coords=c('lon','lat'),crs=4326),25832))
  expect_lt(max(abs(RESY:::.resy_project(ll)-ref)),.001)
  expect_lt(max(abs(RESY:::.resy_project(ref,inverse=TRUE)-ll)),1e-8)
  expect_true(all(is.na(RESY:::.resy_project(matrix(c(99,0),nrow=1)))))
})

test_that('line simplification respects its distance tolerance', {
  xy <- cbind(0:6,c(0,.1,-.1,3,.1,-.1,0))
  expect_equal(RESY:::.resy_simplify_line(xy,.5),xy[c(1,3,4,5,7),],ignore_attr=TRUE)
  expect_identical(RESY:::.resy_simplify_line(xy,0),xy)
})
