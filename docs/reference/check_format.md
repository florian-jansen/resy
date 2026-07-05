# Check for the completeness of the data frame for running the EUNIS expert system

\`check_format()\` is used to run all specific functions of this package
to get the bring the data in the required shape (coordination system:
UTM zone 32N) and get the required data: coastal position, dune
location, ecoregion, and country. Furthermore, it is checked if
coordinates and altitude values are in the data frame.

## Usage

``` r
check_format(data = data, source_crs = source_crs)
```

## Arguments

- data:

  Input is a data frame, tibble or a point sf object

- source_crs:

  The coordination system of the original data as EPSG ID

## Value

An sf object with the same length as \`data\` and with the required
columns for the EUNIS expert system: 'RELEVE_NR', 'Altitude (m)',
'Coast_EEA', 'Dunes_Bohn', 'Ecoreg', and 'Country'.

## Examples

``` r
   data <- tibble::tibble(
      RELEVE_NR = 1L, x = 701327, y = 5364375
      ) |>
      sf::st_as_sf(coords = c("x", "y"), crs = 25832)
   check_format(data, source_crs = 25832)
#> Warning: Warning: The column "Altitude m" is missing in the tibble. You can find a raster file and a WMS connection at mapsforeurope.org
#> Warning: Warning: The column "Coast_EEA" is missing in the tibble.
#> Warning: Warning: The column "Dunes_Bohn" is missing in the tibble.
#> Simple feature collection with 1 feature and 5 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 701327 ymin: 5364375 xmax: 701327 ymax: 5364375
#> Projected CRS: ETRS89 / UTM zone 32N
#> # A tibble: 1 × 6
#>   RELEVE_NR Ecoreg Country Country_ID Ecoreg_name              geometry
#>       <int>  <dbl> <chr>   <chr>      <chr>                 <POINT [m]>
#> 1         1    686 Germany DE         Western Europea… (701327 5364375)
```
