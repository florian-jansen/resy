# Check the format of plot data for ESy classification

Validates that the input data frame or sf object has the structure and
columns expected by \[resy_classify()\]. Performs coordinate
transformation to EPSG:25832 and checks for \`PlotObservationID\`,
altitude, ecoregion, country, coast, and dune columns. Missing
geographic columns are filled automatically by calling the internal
EUNIS geo-assignment helpers.

## Usage

``` r
resy_check_data(data, source_crs)
```

## Arguments

- data:

  A data frame, tibble, or point \`sf\` object.

- source_crs:

  Integer EPSG code of the input CRS. Required when \`data\` is not an
  \`sf\` object.

## Value

An \`sf\` object in EPSG:25832 with all available ESy columns ordered to
the front: \`PlotObservationID\`, \`Altitude (m)\`, \`Coast_EEA\`,
\`Dunes_Bohn\`, \`Ecoreg\`, \`Country\`, \`Country_ID\`,
\`Ecoreg_name\`, \`geometry\`.

## See also

\[resy_harmonize_eunis()\] for the EUNIS-specific enrichment workflow.

## Examples

``` r
  data <- tibble::tibble(
    PlotObservationID = 1L, x = 701327, y = 5364375
  ) |>
    sf::st_as_sf(coords = c("x", "y"), crs = 25832)
  resy_check_data(data, source_crs = 25832)
#> Warning: The column "Altitude (m)" is missing. See mapsforeurope.org for a raster source.
#> Warning: The column "Coast_EEA" is missing.
#> Warning: The column "Dunes_Bohn" is missing.
#> Simple feature collection with 1 feature and 5 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 701327 ymin: 5364375 xmax: 701327 ymax: 5364375
#> Projected CRS: ETRS89 / UTM zone 32N
#> # A tibble: 1 × 6
#>   PlotObservationID Ecoreg Country Country_ID Ecoreg_name                       
#>               <int>  <dbl> <chr>   <chr>      <chr>                             
#> 1                 1    686 Germany DE         Western European broadleaf forests
#> # ℹ 1 more variable: geometry <POINT [m]>
```
