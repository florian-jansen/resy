# Check the format of plot data for ESy classification

Validates that the input data frame or sf object has the structure and
columns expected by
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md).
Performs coordinate transformation to EPSG:25832 and checks for
`PlotObservationID`, altitude, ecoregion, country, coast, and dune
columns. Missing `Ecoreg` and `Country` columns are assigned from the
bundled base maps; missing altitude, coast and dune columns are reported
as warnings.

## Usage

``` r
resy_check_data(data, source_crs = NULL, verbose = interactive())
```

## Arguments

- data:

  A data frame, tibble, or point `sf` object.

- source_crs:

  Integer EPSG code of the coordinates in a plain data frame. When
  `NULL` (default), coordinates that are all valid longitudes and
  latitudes are read as degrees (EPSG:4326); other coordinates need the
  code. Ignored when `data` is an `sf` object, which carries its own
  CRS. The optional package `sf` is required for `sf` input and CRS
  codes other than 4326, 4258 and 25832.

- verbose:

  Logical; if `TRUE`, informational messages about coordinate
  interpretation and transformation are shown. Defaults to
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

## Value

A `resy_sites` data frame in EPSG:25832 with a two-column coordinate
matrix `geometry` and a `resy_crs` attribute. For `sf` input, an `sf`
object is returned. All available ESy columns are ordered to the front:
`PlotObservationID`, `Altitude (m)`, `Coast_EEA`, `Dunes_Bohn`,
`Ecoreg`, `Ecoreg_name`, `Country`, `Country_ID`, `geometry`.

## See also

[`resy_harmonize_eunis()`](https://florian-jansen.github.io/resy/reference/resy_harmonize_eunis.md)
for the EUNIS-specific enrichment workflow.

## Examples

``` r
  data <- data.frame(
    PlotObservationID = 1L, Longitude = 701327, Latitude = 5364375
  )
  resy_check_data(data, source_crs = 25832)
#> Warning: "Altitude (m)" is missing. See the "Get altitude data" vignette; altitude rasters are available from mapsforeurope.org.
#> Warning: "Coast_EEA" is missing. Use run_coast_dunes = TRUE in resy_harmonize_eunis().
#> Warning: "Dunes_Bohn" is missing. Use run_coast_dunes = TRUE in resy_harmonize_eunis().
#>   PlotObservationID Ecoreg                        Ecoreg_name Country
#> 1                 1    686 Western European broadleaf forests Germany
#>   Country_ID geometry.X geometry.Y
#> 1         DE     701327    5364375
```
