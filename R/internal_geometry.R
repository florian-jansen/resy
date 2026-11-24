# Krueger's sixth-order series on GRS80, Karney (2011), Transverse Mercator
# with an accuracy of a few nanometers, doi:10.1007/s00190-011-0445-3.
# EPSG:4326 -> 25832 uses the null ETRS89/WGS84 operation and GRS80 UTM in
# PROJ: https://proj.org/operations/projections/tmerc.html.
.resy_tm <- local({
  f <- 1 / 298.257222101
  n <- f / (2 - f)
  list(e = sqrt(f * (2 - f)),
       radius = 6378137 / (1 + n) * (1 + n^2/4 + n^4/64 + n^6/256) * .9996,
       alpha = c(n/2 - 2*n^2/3 + 5*n^3/16 + 41*n^4/180 - 127*n^5/288 + 7891*n^6/37800,
                 13*n^2/48 - 3*n^3/5 + 557*n^4/1440 + 281*n^5/630 - 1983433*n^6/1935360,
                 61*n^3/240 - 103*n^4/140 + 15061*n^5/26880 + 167603*n^6/181440,
                 49561*n^4/161280 - 179*n^5/168 + 6601661*n^6/7257600,
                 34729*n^5/80640 - 3418889*n^6/1995840, 212378941*n^6/319334400),
       beta = c(n/2 - 2*n^2/3 + 37*n^3/96 - n^4/360 - 81*n^5/512 + 96199*n^6/604800,
                n^2/48 + n^3/15 - 437*n^4/1440 + 46*n^5/105 - 1118711*n^6/3870720,
                17*n^3/480 - 37*n^4/840 - 209*n^5/4480 + 5569*n^6/90720,
                4397*n^4/161280 - 11*n^5/504 - 830251*n^6/7257600,
                4583*n^5/161280 - 108847*n^6/3991680, 20648693*n^6/638668800))
})

.resy_project <- function(xy, inverse = FALSE) {
  e <- .resy_tm$e
  if (!inverse) {
    phi <- xy[, 2] * pi / 180
    lam <- ((xy[, 1] - 9 + 180) %% 360 - 180) * pi / 180
    tau <- tan(phi)
    sigma <- sinh(e * atanh(e * tau / sqrt(1 + tau^2)))
    tp <- tau * sqrt(1 + sigma^2) - sigma * sqrt(1 + tau^2)
    xi <- atan2(tp, cos(lam))
    eta <- asinh(sin(lam) / sqrt(tp^2 + cos(lam)^2))
    x <- eta; y <- xi
    for (j in seq_along(.resy_tm$alpha)) {
      a <- .resy_tm$alpha[j]
      x <- x + a * cos(2*j*xi) * sinh(2*j*eta)
      y <- y + a * sin(2*j*xi) * cosh(2*j*eta)
    }
    out <- cbind(X = 500000 + .resy_tm$radius * x, Y = .resy_tm$radius * y)
    # PROJ's extended transverse Mercator domain is |rectified eta| <= 150 degrees.
    out[!is.finite(x) | abs(x) > 2.623395162778 | abs(xy[, 2]) > 90, ] <- NA_real_
    return(out)
  }
  eta <- (xy[, 1] - 500000) / .resy_tm$radius
  xi <- xy[, 2] / .resy_tm$radius
  x <- eta; y <- xi
  for (j in seq_along(.resy_tm$beta)) {
    b <- .resy_tm$beta[j]
    x <- x - b * cos(2*j*xi) * sinh(2*j*eta)
    y <- y - b * sin(2*j*xi) * cosh(2*j*eta)
  }
  tp <- sin(y) / sqrt(sinh(x)^2 + cos(y)^2)
  tau <- tp / (1 - e^2)
  for (i in seq_len(5L)) {
    sigma <- sinh(e * atanh(e * tau / sqrt(1 + tau^2)))
    t <- tau * sqrt(1 + sigma^2) - sigma * sqrt(1 + tau^2)
    tau <- tau + (tp - t) * (1 + (1-e^2)*tau^2) /
      ((1-e^2) * sqrt(1+tau^2) * sqrt(1+t^2))
  }
  out <- cbind(X = (9 + atan2(sinh(x), cos(y)) * 180/pi + 180) %% 360 - 180,
               Y = atan(tau) * 180/pi)
  out[!is.finite(eta) | abs(eta) > 2.623395162778, ] <- NA_real_
  out
}

.resy_bbox <- function(xy) c(min(xy[, 1]), min(xy[, 2]), max(xy[, 1]), max(xy[, 2]))

# Pair query points with boxes using sorted x intervals and a y prefilter.
.resy_box_pairs <- function(xy, boxes, buffer = 0) {
  order <- order(xy[, 1], na.last = NA)
  order <- order[is.finite(xy[order, 1]) & is.finite(xy[order, 2])]
  x <- xy[order, 1]
  lo <- findInterval(boxes[, 1] - buffer, x, left.open = TRUE)
  hi <- findInterval(boxes[, 3] + buffer, x)
  n <- pmax(hi - lo, 0L)
  box <- rep.int(seq_len(nrow(boxes)), n)
  point <- order[rep.int(lo, n) + sequence(n)]
  keep <- xy[point, 2] >= boxes[box, 2] - buffer & xy[point, 2] <= boxes[box, 4] + buffer
  list(point = point[keep], box = box[keep])
}

# Error-free double products, Dekker splitting with 2^27 + 1.
.resy_product_tail <- function(a, b, product) {
  ca <- 134217729 * a; cb <- 134217729 * b
  ah <- ca - (ca - a); bh <- cb - (cb - b)
  al <- a - ah; bl <- b - bh
  ((ah * bh - product) + ah * bl + al * bh) + al * bl
}

# Adaptive determinant sign, including subtraction tails for collinear points.
# GEOS CGAlgorithmsDD uses extended precision for the same uncertain cases.
.resy_orientation <- function(ax, ay, bx, by, px, py) {
  dx <- bx - ax; dy <- by - ay; qx <- px - ax; qy <- py - ay
  l <- dx * qy; r <- dy * qx
  det <- l - r
  uncertain <- which(abs(det) <= 1e-15 * (abs(l) + abs(r)))
  if (length(uncertain)) {
    tail <- function(a, b, d) { z <- d - a; (a - (d - z)) - (b + z) }
    i <- uncertain
    dxl <- tail(bx[i], ax[i], dx[i]); dyl <- tail(by[i], ay[i], dy[i])
    qxl <- tail(px[i], ax[i], qx[i]); qyl <- tail(py[i], ay[i], qy[i])
    low <- .resy_product_tail(dx[i], qy[i], l[i]) - .resy_product_tail(dy[i], qx[i], r[i]) +
      dx[i]*qyl + dxl*qy[i] - dy[i]*qxl - dyl*qx[i]
    z <- det[i] - l[i]
    low <- low + ((l[i] - (det[i] - z)) - (r[i] + z))
    det[i] <- det[i] + low
  }
  sign(det)
}

# Horizontal ray parity with half-open y intervals and explicit boundaries.
# GEOS RayCrossingCounter and sp/src/pip.c describe the crossing convention:
# https://libgeos.org/doxygen/classgeos_1_1algorithm_1_1RayCrossingCounter.html
# https://github.com/edzer/sp/blob/master/src/pip.c
.resy_in_ring <- function(xy, ring) {
  a <- ring[-nrow(ring), , drop = FALSE]; b <- ring[-1L, , drop = FALSE]
  boxes <- cbind(rep(-Inf, nrow(a)), pmin(a[, 2], b[, 2]),
                 pmax(a[, 1], b[, 1]), pmax(a[, 2], b[, 2]))
  pairs <- .resy_box_pairs(xy, boxes)
  p <- pairs$point; s <- pairs$box
  orient <- .resy_orientation(a[s, 1], a[s, 2], b[s, 1], b[s, 2], xy[p, 1], xy[p, 2])
  boundary <- orient == 0 & xy[p, 1] >= pmin(a[s, 1], b[s, 1])
  crossing <- (a[s, 2] > xy[p, 2]) != (b[s, 2] > xy[p, 2])
  crossing <- crossing & (orient * sign(b[s, 2] - a[s, 2]) > 0)
  out <- as.integer(tabulate(p[crossing], nrow(xy)) %% 2L)
  out[unique(p[boundary])] <- 2L
  out
}

# A shell contains its holes' boundaries; hole interiors exclude the point.
# Multipart features contribute at most one match, in layer feature order.
.resy_intersects <- function(xy, layer) {
  pairs <- .resy_box_pairs(xy, layer$ring_bbox)
  candidates <- split(pairs$point, pairs$box)
  interiors <- boundaries <- vector('list', length(layer$rings))
  for (key in names(candidates)) {
    r <- as.integer(key); p <- candidates[[key]]
    loc <- .resy_in_ring(xy[p, , drop = FALSE], layer$rings[[r]])
    interiors[[r]] <- p[loc == 1L]
    boundaries[[r]] <- p[loc == 2L]
  }
  hits <- vector('list', nrow(layer$attributes))
  for (group in split(seq_along(layer$rings), layer$part)) {
    shell <- group[1L]
    inside <- setdiff(interiors[[shell]], unlist(interiors[group[-1L]], use.names = FALSE))
    p <- unique(c(inside, unlist(boundaries[group], use.names = FALSE)))
    f <- layer$feature[shell]
    hits[f] <- list(unique(c(hits[[f]], p)))
  }
  out <- rep(list(integer()), nrow(xy))
  p <- unlist(hits, use.names = FALSE)
  f <- rep.int(seq_along(hits), lengths(hits))
  grouped <- split(f, p)
  out[as.integer(names(grouped))] <- unname(grouped)
  out
}

# Orthogonal segment projection with endpoint clamping; GEOS Distance.cpp.
# https://github.com/libgeos/geos/blob/main/src/algorithm/Distance.cpp
.resy_segment_distance <- function(px, py, ax, ay, bx, by) {
  dx <- bx - ax; dy <- by - ay; length2 <- dx^2 + dy^2
  t <- ((px - ax)*dx + (py - ay)*dy) / length2
  d <- abs(((ay-py)*dx - (ax-px)*dy) / length2) * sqrt(length2)
  start <- length2 == 0 | (!is.na(t) & t <= 0)
  end <- !is.na(t) & t >= 1
  d[start] <- sqrt((px[start]-ax[start])^2 + (py[start]-ay[start])^2)
  d[end] <- sqrt((px[end]-bx[end])^2 + (py[end]-by[end])^2)
  d
}

.resy_within_distance <- function(xy, layer, distance) {
  seg <- layer$segments
  pairs <- .resy_box_pairs(xy, layer$segment_bbox, distance)
  p <- pairs$point; s <- pairs$box
  d <- .resy_segment_distance(xy[p, 1], xy[p, 2], seg[s, 1], seg[s, 2], seg[s, 3], seg[s, 4])
  keep <- d <= distance
  grouped <- split(layer$segment_feature[s[keep]], p[keep])
  out <- rep(list(integer()), nrow(xy))
  out[as.integer(names(grouped))] <- lapply(grouped, function(x) sort(unique(x)))
  out
}

# Douglas-Peucker retains endpoints and vertices further than tolerance from
# the candidate segment. The explicit stack bounds recursion depth.
.resy_simplify_line <- function(xy, tolerance) {
  n <- nrow(xy)
  if (n <= 2L || tolerance <= 0) return(xy)
  keep <- rep(FALSE, n); keep[c(1L, n)] <- TRUE
  stack <- list(c(1L, n))
  while (length(stack)) {
    ends <- stack[[length(stack)]]; stack[[length(stack)]] <- NULL
    if (diff(ends) <= 1L) next
    i <- seq.int(ends[1L]+1L, ends[2L]-1L)
    a <- xy[rep(ends[1L], length(i)), , drop = FALSE]
    b <- xy[rep(ends[2L], length(i)), , drop = FALSE]
    d <- .resy_segment_distance(xy[i, 1], xy[i, 2], a[, 1], a[, 2], b[, 1], b[, 2])
    k <- which.max(d)
    if (d[k] > tolerance) {
      at <- i[k]; keep[at] <- TRUE
      stack <- c(stack, list(c(ends[1L], at), c(at, ends[2L])))
    }
  }
  xy[keep, , drop = FALSE]
}
