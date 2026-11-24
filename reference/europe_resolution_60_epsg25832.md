# European countries at low resolution (EPSG:25832)

Country boundaries (NUTS level 0, columns `NUTS_ID` and `NUTS_NAME`) at
the 1:60 million scale, in EPSG:25832, for maps.

## Usage

``` r
data(europe_resolution_60_epsg25832)
```

## Format

A plain coordinate list with 37 polygon features. See
[dunes_bohn_500mbuffer_epsg25832](https://florian-jansen.github.io/resy/reference/dunes_bohn_500mbuffer_epsg25832.md)
for the ring and attribute fields. `land` holds simplified EPSG:3857
outlines for map export.

## Source

Eurostat GISCO: NUTS boundaries.
