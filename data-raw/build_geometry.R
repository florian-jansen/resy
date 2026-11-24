# Encode the EPSG:25832 sf layers as coordinate rings and attribute tables.
# Input is the output directory of simplify_gis.R; output is data/.
args <- commandArgs(trailingOnly = TRUE)
src <- if (length(args)) args[1L] else 'data-raw/gis_simplified'
source('R/internal_geometry.R')
source('R/internal_eunis_geo.R')

encode_layer <- function(g) {
  g <- sf::st_zm(g)
  rings <- list(); feature <- part <- ring <- integer(); next_part <- 0L
  add <- function(geometry, owner) {
    type <- class(geometry)[2L]
    if (type %in% c('MULTIPOLYGON', 'GEOMETRYCOLLECTION')) {
      children <- if (type == 'MULTIPOLYGON') lapply(geometry, sf::st_polygon) else geometry
      for (child in children) add(child, owner)
    } else {
      parts <- switch(type, POLYGON = list(unclass(geometry)),
                      LINESTRING = list(list(unclass(geometry))),
                      MULTILINESTRING = lapply(unclass(geometry), list),
                      stop('Unsupported layer geometry: ', type))
      for (p in parts) {
        next_part <<- next_part + 1L
        for (j in seq_along(p)) {
          if (!nrow(p[[j]])) next
          rings[[length(rings)+1L]] <<- unname(p[[j]][, 1:2, drop = FALSE])
          feature <<- c(feature, owner); part <<- c(part, next_part); ring <<- c(ring, j)
        }
      }
    }
  }
  for (i in seq_len(nrow(g))) add(sf::st_geometry(g)[[i]], i)
  boxes <- do.call(rbind, lapply(rings, .resy_bbox))
  fb <- t(vapply(seq_len(nrow(g)), function(i) {
    b <- boxes[feature == i, , drop = FALSE]
    c(min(b[, 1]), min(b[, 2]), max(b[, 3]), max(b[, 4]))
  }, numeric(4)))
  out <- list(crs = sf::st_crs(g)$epsg, attributes = sf::st_drop_geometry(g),
              rings = rings, feature = feature, part = part, ring = ring,
              ring_bbox = boxes, bbox = fb)
  if (all(sf::st_geometry_type(g) %in% c('LINESTRING', 'MULTILINESTRING'))) {
    out$segments <- do.call(rbind, lapply(rings, function(x) cbind(x[-nrow(x), ], x[-1L, ])))
    s <- out$segments
    out$segment_bbox <- cbind(pmin(s[, 1], s[, 3]), pmin(s[, 2], s[, 4]),
                              pmax(s[, 1], s[, 3]), pmax(s[, 2], s[, 4]))
    out$segment_feature <- rep.int(feature, vapply(rings, nrow, integer(1)) - 1L)
  }
  out
}

for (dataset in names(.resy_gis_layers)) {
  env <- new.env()
  load(file.path(src, paste0(dataset, '.rda')), env)
  name <- .resy_gis_layers[[dataset]]
  g <- env[[name]]
  stopifnot(inherits(g, 'sf'), sf::st_crs(g)$epsg == 25832)
  layer <- encode_layer(g)
  if (startsWith(dataset, 'europe_resolution')) {
    land <- encode_layer(sf::st_transform(g, 3857))
    # Half a pixel at Leaflet's maximum zoom (18), or at the coarse-layer cutoff.
    tolerance <- if (grepl('_60_', dataset)) 2500 else 2*pi*6378137 / (256*2^18) / 2
    land$rings <- lapply(land$rings, .resy_simplify_line, tolerance = tolerance)
    land$ring_bbox <- do.call(rbind, lapply(land$rings, .resy_bbox))
    # Centimetre units bound per-axis quantisation below 0.01 pixel at zoom 18.
    outlines <- lapply(land$rings, function(x) matrix(as.integer(round(x * 100)), ncol = 2L))
    layer$land <- list(rings = outlines, feature = land$feature,
                       ring_bbox = land$ring_bbox, unit = .01)
  }
  env[[name]] <- layer
  save(list = name, envir = env, file = file.path('data', paste0(dataset, '.rda')), compress = 'xz')
  cat(dataset, nrow(g), 'features,', length(layer$rings), 'rings,',
      sum(vapply(layer$rings, nrow, integer(1))), 'vertices\n')
}
