# Identify the country in which your vegetation surveys were conducted

\`check_country()\` is used to intersect the coordinates of the
vegetation surveys with a shape of the European countries to assign to
each survey a country. Country is sometimes used by the expert system.

## Usage

``` r
check_country(data)
```

## Arguments

- data:

  Input is a point sf object and the coordination system EPSG 25832.

## Value

A point sf object with the same length as \`data\` but with the columns
'Country_ID' and 'Country' which is the name written out.

## Examples

``` r
data <- tibble::tibble(
  plot = "1a",
  x = 701327,
  y = 5364375
) |>
  sf::st_as_sf(coords = c("x", "y"), crs = 25832)

check_country(data)
#> Simple feature collection with 1 feature and 3 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 701327 ymin: 5364375 xmax: 701327 ymax: 5364375
#> Projected CRS: ETRS89 / UTM zone 32N
#> # A tibble: 1 × 4
#>   plot          geometry Country_ID Country
#> * <chr>      <POINT [m]> <chr>      <chr>  
#> 1 1a    (701327 5364375) DE         Germany
```
