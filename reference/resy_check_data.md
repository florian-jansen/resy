# Check the format of plot data for ESy classification

Validates that the input data frame or sf object has the structure and
columns expected by \[resy_classify()\]. Performs coordinate
transformation to EPSG:25832 and checks for \`PlotObservationID\`,
altitude, ecoregion, country, coast, and dune columns. Missing
\`Ecoreg\` and \`Country\` columns are assigned from the bundled base
maps; missing altitude, coast and dune columns are reported as warnings.

## Usage

``` r
resy_check_data(data, source_crs = NULL)
```

## Arguments

- data:

  A data frame, tibble, or point \`sf\` object.

- source_crs:

  Integer EPSG code of the coordinates in a plain data frame. When
  \`NULL\` (default), coordinates that are all valid longitudes and
  latitudes are read as degrees (EPSG:4326); other coordinates need the
  code. Ignored when \`data\` is an \`sf\` object, which carries its own
  CRS.

## Value

An \`sf\` object in EPSG:25832 with all available ESy columns ordered to
the front: \`PlotObservationID\`, \`Altitude (m)\`, \`Coast_EEA\`,
\`Dunes_Bohn\`, \`Ecoreg\`, \`Ecoreg_name\`, \`Country\`,
\`Country_ID\`, \`geometry\`.

## See also

\[resy_harmonize_eunis()\] for the EUNIS-specific enrichment workflow.

## Examples

``` r
  data <- data.frame(
    PlotObservationID = 1L, x = 701327, y = 5364375
  ) |>
    sf::st_as_sf(coords = c("x", "y"), crs = 25832)
  resy_check_data(data, source_crs = 25832)
#> Warning: "Altitude (m)" is missing. See vignette "Altitude data" and mapsforeurope.org for a raster source.
#> Warning: "Coast_EEA" is missing. Use run_coast_dunes = TRUE in resy_harmonize_eunis().
#> Warning: "Dunes_Bohn" is missing. Use run_coast_dunes = TRUE in resy_harmonize_eunis().
#> Simple feature collection with 1 feature and 5 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 701327 ymin: 5364375 xmax: 701327 ymax: 5364375
#> Projected CRS: ETRS89 / UTM zone 32N
#>   PlotObservationID Ecoreg                        Ecoreg_name Country
#> 1                 1    686 Western European broadleaf forests Germany
#>   Country_ID               geometry
#> 1         DE POINT (701327 5364375)
```
