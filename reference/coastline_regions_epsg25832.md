# Regional seas around Europe (EPSG:25832)

The regional seas around Europe (Marine Strategy Framework Directive
regions) in EPSG:25832. The dataset holds the list `co`;
`attributes$COAST_EEA` gives the coast code of each sea (for example
`MED_COAST`). Used to set `Coast_EEA` in
[`resy_harmonize_eunis()`](https://florian-jansen.github.io/resy/reference/resy_harmonize_eunis.md).

## Usage

``` r
data(coastline_regions_epsg25832)
```

## Format

A plain coordinate list with 5 multiline features. See
[dunes_bohn_500mbuffer_epsg25832](https://florian-jansen.github.io/resy/reference/dunes_bohn_500mbuffer_epsg25832.md)
for the ring and attribute fields. `segments`, `segment_bbox` and
`segment_feature` index the line segments.

## Source

European Environment Agency: Regional seas around Europe.
