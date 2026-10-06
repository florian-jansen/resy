# Calculate Total Cover from Individual Cover Values

Computes the total coverage from a vector of individual cover
percentages, accounting for overlapping coverage between species or
layers. Uses the complement method: total cover = 1 - (product of
complements).

## Usage

``` r
.total_cover(x)
```

## Arguments

- x:

  numeric vector of cover values (0-100), typically representing
  individual species or layer coverage percentages in a vegetation plot.

## Value

numeric scalar representing the total cover percentage (0-100), rounded
to 10 decimal places.

## Details

This function is designed for use with vegetation plot data where
multiple species or layers can overlap. Instead of simple addition,
which would overestimate total cover, this function uses the
mathematical complement formula:

Total Cover = (1 - ∏(1 - cover_i/100)) × 100

This approach is standard in vegetation science for combining cover
values from different species or strata where overlapping coverage
exists.

The result is rounded to 10 decimal places to minimize floating-point
arithmetic artifacts.

## Examples

``` r
# Single species
.total_cover(50)
#> Error in .total_cover(50): could not find function ".total_cover"

# Two species with overlapping coverage
.total_cover(c(50, 30))
#> Error in .total_cover(c(50, 30)): could not find function ".total_cover"

# Multiple species with various coverages
.total_cover(c(60, 40, 20))
#> Error in .total_cover(c(60, 40, 20)): could not find function ".total_cover"
```
