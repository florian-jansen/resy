# European countries at high resolution (EPSG:25832)

Country boundaries (NUTS level 0, columns `NUTS_ID` and `NUTS_NAME`) at
the 1:1 million scale, in EPSG:25832. Used to set `Country` in
[`resy_harmonize_eunis()`](https://florian-jansen.github.io/resy/reference/resy_harmonize_eunis.md).

## Usage

``` r
data(europe_resolution_1_epsg25832)
```

## Format

A plain coordinate list with 37 polygon features. See
[dunes_bohn_500mbuffer_epsg25832](https://florian-jansen.github.io/resy/reference/dunes_bohn_500mbuffer_epsg25832.md)
for the ring and attribute fields. `land` holds simplified EPSG:3857
outlines for map export.

## Source

Eurostat GISCO: NUTS boundaries.
