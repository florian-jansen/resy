# Coastal vegetation of the Bohn map with a 500 m buffer (EPSG:25832)

Polygons of the coastal vegetation (formation P) of the Map of the
Natural Vegetation of Europe (Bohn et al.), buffered by 500 m, in
EPSG:25832. The dataset holds the list `bohn`; `attributes$DUNE` marks
dune polygons. Used to set `Dunes_Bohn` in
[`resy_harmonize_eunis()`](https://florian-jansen.github.io/resy/reference/resy_harmonize_eunis.md).

## Usage

``` r
data(dunes_bohn_500mbuffer_epsg25832)
```

## Format

A plain list for 367 polygon features: `rings` holds two-column
coordinate matrices, `feature`, `part` and `ring` identify each ring,
`ring_bbox` and `bbox` hold bounding boxes, `attributes` holds the
feature table, and `crs` is the EPSG code. Ring 1 is the shell; later
rings are holes.

## Source

Bohn, U. et al.: Map of the Natural Vegetation of Europe.
