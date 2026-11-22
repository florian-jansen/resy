# Simplify the bundled GIS layers with rmapshaper (topology-aware Visvalingam)
# so the source tarball stays under the CRAN 5 MB limit.
#
# Input : full-resolution layers in data-raw/gis_full/ (the versions tracked
#         before this change; also recoverable from git history). Not shipped
#         (data-raw is in .Rbuildignore) and not committed (see .gitignore).
# Output: data/*.rda, with object names unchanged (co, bohn, ecoregions2017_...).
#
# Per-layer keep fractions are the strongest simplification that leaves the
# coast, ecoregion and dune assignments on inst/extdata's 200-plot example
# unchanged (0 flips, checked against the full-resolution layers).
#
# europe_resolution_1 is the country lookup. Dropping vertices moves coastal
# plots out of their country at every keep fraction tried (keep 0.5: 1 of 1,046
# test points; keep 0.05: 12 of the 200 example plots), so its vertices are all
# kept and only rounded to a 1 m grid instead: 0 of 858 points within 2 km of a
# border or coast change country. europe_resolution_60 is left untouched.

library(sf)
library(rmapshaper)

src <- "data-raw/gis_full"

keep <- c(
  coastline_regions_epsg25832     = 0.30,  # buffered 5 km before use; 0 flips
  ecoregions2017_epsg25832        = 0.40,  # 0 flips
  dunes_bohn_500mbuffer_epsg25832 = 0.40,  # 0 flips
  dunes_bohn_500mbuffer_25832     = 0.40
)

# Grid size in metres to which the coordinates of a layer are rounded.
grid <- c(europe_resolution_1_epsg25832 = 1)

round_to_grid <- function(g, size) {
  geom <- lapply(sf::st_geometry(g), function(x)
    rapply(x, function(m) round(m / size) * size, how = "replace"))
  sf::st_geometry(g) <- sf::st_make_valid(sf::st_sfc(geom, crs = sf::st_crs(g)))
  g
}

for (f in list.files(src, pattern = "\\.rda$")) {
  b  <- sub("\\.rda$", "", f)
  e  <- new.env(); load(file.path(src, f), envir = e); nm <- ls(e)[1]; g <- e[[nm]]
  if (b %in% names(keep) && inherits(g, c("sf", "sfc"))) {
    g <- sf::st_zm(g, drop = TRUE, what = "ZM")
    g <- rmapshaper::ms_simplify(g, keep = keep[[b]], keep_shapes = TRUE)
  }
  if (b %in% names(grid)) g <- round_to_grid(g, grid[[b]])
  assign(nm, g)
  save(list = nm, file = file.path("data", f), compress = "xz")
}
