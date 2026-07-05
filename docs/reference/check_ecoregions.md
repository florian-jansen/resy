# Identify the ecoregion in which your vegetation surveys were conducted

\`check_ecoregion()\` is used to intersect the coordinates of the
vegetation surveys with a shape of the European ecoregions (Dinerstein
et al. 2017) to assign to each survey an ecoregion. Ecoregions is
sometimes used by the expert system.

## Usage

``` r
check_ecoregions(data = data)
```

## Arguments

- data:

  Input is a point sf object and the coordination system EPSG 25832.

## Value

A point sf object with the same length as \`data\` but with the
additional columns 'Ecoreg' for ecoregion IDs and 'Ecoreg_name'.

## Examples

``` r
   data <- tibble::tibble(
      plot = "1a", x = 701327, y = 5364375
      ) |>
      sf::st_as_sf(coords = c("x", "y"), crs = 25832)
   check_ecoregions(data)
```
