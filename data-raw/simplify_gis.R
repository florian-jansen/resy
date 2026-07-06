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
# europe_resolution_1 is not used by the assignment path, so it is simplified
# aggressively; europe_resolution_60 (country lookup) is left untouched.

library(sf)
library(rmapshaper)

src <- "data-raw/gis_full"

keep <- c(
  coastline_regions_epsg25832     = 0.30,  # buffered 5 km before use; 0 flips
  ecoregions2017_epsg25832        = 0.40,  # 0 flips
  dunes_bohn_500mbuffer_epsg25832 = 0.40,  # 0 flips
  dunes_bohn_500mbuffer_25832     = 0.40,
  europe_resolution_1_epsg25832   = 0.05   # not used by the assignment path
)

for (f in list.files(src, pattern = "\\.rda$")) {
  b  <- sub("\\.rda$", "", f)
  e  <- new.env(); load(file.path(src, f), envir = e); nm <- ls(e)[1]; g <- e[[nm]]
  if (b %in% names(keep) && inherits(g, c("sf", "sfc"))) {
    g <- sf::st_zm(g, drop = TRUE, what = "ZM")
    g <- rmapshaper::ms_simplify(g, keep = keep[[b]], keep_shapes = TRUE)
  }
  assign(nm, g)
  save(list = nm, file = file.path("data", f), compress = "xz")
}
