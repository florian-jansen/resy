# Harmonize plot data for EUNIS classification

**\[experimental\]** Prepares vegetation plot header data for EUNIS
habitat classification. Converts coordinates to EPSG:25832 (ETRS89 / UTM
zone 32N), assigns WWF ecoregions and country identifiers, optionally
computes coast/dune flags, and optionally checks and harmonizes species
taxonomy.

Use
[`resy_check_eunis()`](https://florian-jansen.github.io/resy/reference/resy_check_eunis.md)
first to verify that the input data meets all requirements before
running this function.

## Usage

``` r
resy_harmonize_eunis(
  data,
  source_crs = NULL,
  run_taxonomy = FALSE,
  species_data = NULL,
  parsed = NULL,
  run_coast_dunes = FALSE,
  coast_buffer = 5000,
  verbose = interactive()
)
```

## Arguments

- data:

  A data frame or `sf` object containing plot data. If not an `sf`
  object, columns `Longitude` and `Latitude` must be present. Darwin
  Core names are accepted: `eventID`, `decimalLongitude`,
  `decimalLatitude`, `country`, and
  `minimumElevationInMeters`/`maximumElevationInMeters` for
  `Altitude (m)`, which can also be given as `Altitude`.

- source_crs:

  Integer EPSG code of the coordinates in a plain data frame, in any
  coordinate reference system; they are converted as needed. When `NULL`
  (default), coordinates that are all valid longitudes and latitudes are
  read as degrees (EPSG:4326); other coordinates need the code. Ignored
  when `data` is an `sf` object, which carries its own CRS.

- run_taxonomy:

  Logical; if `TRUE`, runs
  [`resy_check_taxonomy()`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md)
  on `species_data`.

- species_data:

  A data frame with a column `scientificName`. Required when
  `run_taxonomy = TRUE`.

- parsed:

  A `resy_parsed_expert` object from
  [`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md).
  Required when `run_taxonomy = TRUE`.

- run_coast_dunes:

  Logical; if `TRUE`, assigns `Coast_EEA` and `Dunes_Bohn` flags via
  spatial intersection.

- coast_buffer:

  Numeric buffer in metres for coastline proximity (default 5000).

- verbose:

  Logical; if `TRUE`, informational messages about coordinate
  interpretation and transformation are shown. Defaults to
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

## Value

A named list:

- `sites`:

  Tibble of harmonised plot data, geometry dropped, WGS84 `Longitude`
  and `Latitude` added, and the same values as `DEG_LON` and `DEG_LAT`,
  the header fields EUNIS-ESy reads.

- `species_checked`:

  Output from
  [`resy_check_taxonomy()`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md)
  when `run_taxonomy = TRUE`, otherwise `NULL`.

## See also

[`resy_check_eunis()`](https://florian-jansen.github.io/resy/reference/resy_check_eunis.md),
[`resy_check_taxonomy()`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md),
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)

## Examples

``` r
plots <- data.frame(
  PlotObservationID = c("site_1", "site_2"),
  Longitude = c(8.15, 8.35),
  Latitude = c(53.55, 53.65)
)

harmonized <- resy_harmonize_eunis(
  data = plots,
  source_crs = 4326,
  verbose = FALSE
)
#> Warning: "Altitude (m)" is missing. See the "Get altitude data" vignette; altitude rasters are available from mapsforeurope.org.
#> Warning: No site falls inside the ecoregion base map. Check that `source_crs`matches the coordinates (longitude/latitude in degrees is 4326).
#> Warning: "Country" is missing for some plots because they fall outside the country map.

harmonized$sites
#> # A tibble: 2 × 9
#>   PlotObservationID Ecoreg Ecoreg_name Country Country_ID Longitude Latitude
#>   <chr>              <dbl> <chr>       <chr>   <chr>          <dbl>    <dbl>
#> 1 site_1                NA NA          Germany DE              8.15     53.6
#> 2 site_2                NA NA          NA      NA              8.35     53.6
#> # ℹ 2 more variables: DEG_LON <dbl>, DEG_LAT <dbl>
```
