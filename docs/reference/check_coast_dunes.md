# Check if Points Intersect Coastline or Dune Areas (EPSG:25832)

Flags points based on whether they fall within a buffer of the coastline
or within known coastal dune formations. Input must be an \`sf\` object
in EPSG:25832. Returns only the flag columns for integration into the
main EUNIS workflow.

## Usage

``` r
check_coast_dunes(data_sf, buffer_dist = 5000)
```

## Arguments

- data_sf:

  An \`sf\` object containing point geometries in EPSG:25832.

- buffer_dist:

  Numeric. The distance (in meters) to buffer the coastline. Default
  is 5000. Must be a single positive value.

## Value

A tibble with two columns:

- `Coast_EEA`:

  "coastal" if point is within the buffered coastline, "non_coastal"
  otherwise.

- `Dunes_Bohn`:

  "Y_DUNES" if point intersects dune area, "N_DUNES" otherwise.

## Details

The function performs the following steps:

1.  Crops coastline and dune spatial layers to the bounding box of the
    points.

2.  Buffers the coastline by the user-defined \`buffer_dist\`.

3.  Performs spatial intersections to identify points within coastal and
    dune zones.

## Note

This function requires the following files:

- `coastline_epsg25832.rda` (object `co`)

- `dunes_bohn_500mbuffer_epsg25832.rda` (object `bohn`)
