# Trim Leading Whitespace

Removes leading whitespace (spaces, tabs, newlines) from a character
vector.

## Usage

``` r
.resy_trim_leading(x)
```

## Arguments

- x:

  A character vector.

## Value

A character vector with leading whitespace removed.

## See also

\[trim()\], \[trim.trailing()\]

## Examples

``` r
trim.leading("  hello")  # Returns "hello"
#> Error in trim.leading("  hello"): could not find function "trim.leading"
```
