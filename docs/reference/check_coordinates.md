# Transform the coordinates into UTM32N

\`check_coordinates()\` is used to to transform the coordinates into the
coordination system UTM zone 32. Additionally, if the \`data\` ia a data
frame, it is transformed into a sf object.

## Usage

``` r
check_coordinates(data = data, source_crs = source_crs)
```

## Arguments

- data:

  Input is a data frame or tibble with the columns 'Longitude' and
  'Latitude' or a sf object

- source_crs:

  Coordination system as EPSG ID of the original data

## Value

A point sf object with the coorination system UTM zone 32N / EPSG:25832
and the same length as \`data\`

## Examples

``` r
   data <- tibble::tibble(
   plot = "1a", Latitude = "48.40035", Longitude = 11.72014
   )
   check_coordinates(data, source_crs = 4326)
#> Coordination system transformed to ETRS89 / UTM zone 32N / EPSG:25832
#> Simple feature collection with 1 feature and 1 field
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 701326.4 ymin: 5364374 xmax: 701326.4 ymax: 5364374
#> Projected CRS: ETRS89 / UTM zone 32N
#> # A tibble: 1 × 2
#>   plot            geometry
#> * <chr>        <POINT [m]>
#> 1 1a    (701326.4 5364374)
```
