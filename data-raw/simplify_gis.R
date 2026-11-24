# Simplify the bundled GIS layers with rmapshaper (topology-aware Visvalingam)
# so the source tarball stays under the CRAN 5 MB limit.
#
# Input : full-resolution layers in data-raw/gis_full/ (the versions tracked
#         before this change; also recoverable from git history). Not shipped
#         (data-raw is in .Rbuildignore) and not committed (see .gitignore).
# Output: data-raw/gis_simplified/*.rda for build_geometry.R.
#
# Per-layer keep fractions are the strongest simplification that leaves the
# coast, ecoregion and dune assignments on inst/extdata's 200-plot example
# unchanged (0 flips, checked against the full-resolution layers).
# On 16,521 random points 4-6 km from the full-resolution coastline, where the
# 5 km coast rule can change, keep 0.30 changes the coast of 96 points; keep
# 0.15 changes 561. Rounding the kept vertices to a 10 m grid adds 3 changes
# and cuts the file from 1.21 to 0.41 MB (median segment length is 1.3 km).
# On 20,000 random points within 2 km of a full-resolution polygon border,
# ecoregions at keep 0.40 assign 340 points differently, dunes at keep 0.40 63.
# A 10 m grid raises this to 349 and 69 and cuts the files from 552 to 251 KB
# (ecoregions) and from 123 to 49 KB (dunes).
#
# europe_resolution_1 is the country lookup. Dropping vertices moves coastal
# plots out of their country at every keep fraction tried (keep 0.5: 1 of 1,046
# test points; keep 0.05: 12 of the 200 example plots), so its vertices are all
# kept and only rounded to a 1 m grid instead: 0 of 858 points within 2 km of a
# border or coast change country. europe_resolution_60 is left untouched.

library(sf)
library(rmapshaper)

src <- "data-raw/gis_full"
out <- "data-raw/gis_simplified"
dir.create(out, showWarnings = FALSE)

keep <- c(
  coastline_regions_epsg25832     = 0.30,  # 5 km distance rule; 0 flips on the example
  ecoregions2017_epsg25832        = 0.40,  # 0 flips
  dunes_bohn_500mbuffer_epsg25832 = 0.40   # 0 flips
)

# Grid size in metres to which the coordinates of a layer are rounded.
grid <- c(
  europe_resolution_1_epsg25832   = 1,
  coastline_regions_epsg25832     = 10,
  ecoregions2017_epsg25832        = 10,
  dunes_bohn_500mbuffer_epsg25832 = 10
)

# Attribute columns removed before saving.
drop_cols <- list(coastline_regions_epsg25832 = "path")

round_to_grid <- function(g, size) {
  geom <- lapply(sf::st_geometry(g), function(x)
    rapply(x, function(m) round(m / size) * size, how = "replace"))
  sf::st_geometry(g) <- sf::st_make_valid(sf::st_sfc(geom, crs = sf::st_crs(g)))
  g
}

shipped <- list.files("data", pattern = "\\.rda$")

for (f in intersect(list.files(src, pattern = "\\.rda$"), shipped)) {
  b  <- sub("\\.rda$", "", f)
  e  <- new.env(); load(file.path(src, f), envir = e); nm <- ls(e)[1]; g <- e[[nm]]
  if (b %in% names(keep) && inherits(g, c("sf", "sfc"))) {
    g <- sf::st_zm(g, drop = TRUE, what = "ZM")
    g <- rmapshaper::ms_simplify(g, keep = keep[[b]], keep_shapes = TRUE)
  }
  if (b %in% names(grid)) g <- round_to_grid(g, grid[[b]])
  if (b %in% names(drop_cols)) g <- g[, setdiff(names(g), drop_cols[[b]])]
  assign(nm, g)
  save(list = nm, file = file.path(out, f), compress = "xz")
}
