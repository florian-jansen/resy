geometry_sf <- function(layer, lines = FALSE) {
  geometries <- lapply(seq_len(nrow(layer$attributes)), function(f) {
    at <- which(layer$feature == f)
    if (lines) return(sf::st_multilinestring(layer$rings[at]))
    parts <- split(at, factor(layer$part[at], levels = unique(layer$part[at])))
    sf::st_multipolygon(lapply(parts, function(i) layer$rings[i]))
  })
  sf::st_sf(layer$attributes, geometry = sf::st_sfc(geometries, crs = layer$crs))
}

geometry_reference <- function(xy, layers, buffer = 5000) {
  p <- sf::st_as_sf(data.frame(id = seq_len(nrow(xy)), x = xy[, 1], y = xy[, 2]),
                    coords = c('x', 'y'), crs = 25832)
  e <- sf::st_join(p, layers$eco, left = TRUE, largest = FALSE)
  e <- e[, c('id', 'ECO_ID', 'ECO_NAME')]
  e <- sf::st_join(e, layers$country, left = TRUE, largest = FALSE)
  box <- sf::st_bbox(e)
  box[c('xmin','ymin')] <- box[c('xmin','ymin')] - buffer
  box[c('xmax','ymax')] <- box[c('xmax','ymax')] + buffer
  coast <- suppressWarnings(sf::st_crop(layers$coast, box))
  dunes <- suppressWarnings(sf::st_crop(layers$dunes, box))
  names(e)[match(c('ECO_ID','ECO_NAME','NUTS_ID','NUTS_NAME'),names(e))] <-
    c('Ecoreg','Ecoreg_name','Country_ID','Country')
  country <- RESY:::.country_map[toupper(e$Country)]
  e$Country[!is.na(country)] <- unname(country[!is.na(country)])
  e$Coast_EEA <- vapply(sf::st_is_within_distance(e, coast, dist = buffer),
                        function(i) if (length(i)) coast$COAST_EEA[i[1L]] else 'N_COAST', character(1))
  e$Dunes_Bohn <- ifelse(lengths(sf::st_intersects(e,dunes)) > 0, 'Y_DUNES','N_DUNES')
  sf::st_drop_geometry(e)[, c('id','Ecoreg','Ecoreg_name','Country','Country_ID','Coast_EEA','Dunes_Bohn')]
}

geometry_samples <- function(layer, n, rings = seq_along(layer$rings), offset = 100) {
  r <- sample(rings, n, replace = TRUE)
  seg <- vapply(r, function(i) sample.int(nrow(layer$rings[[i]]) - 1L, 1L), integer(1))
  a <- t(vapply(seq_len(n), function(i) layer$rings[[r[i]]][seg[i], ], numeric(2)))
  b <- t(vapply(seq_len(n), function(i) layer$rings[[r[i]]][seg[i]+1L, ], numeric(2)))
  along <- runif(n)
  v <- b - a
  normal <- cbind(-v[, 2], v[, 1]) / sqrt(rowSums(v^2))
  normal[!is.finite(normal)] <- 0
  xy <- a + along * v + runif(n, -offset, offset) * normal
  list(xy = xy, a = a, b = b, normal = normal)
}
