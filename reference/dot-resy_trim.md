# Trim Leading and Trailing Whitespace

Removes leading and trailing whitespace (including spaces, tabs, and
newlines) from a character vector.

## Usage

``` r
.resy_trim(x)
```

## Arguments

- x:

  A character vector.

## Value

A character vector with leading/trailing whitespace removed.

## Examples

``` r
trim("  hello world  ")  # Returns "hello world"
#> Error in trim("  hello world  "): could not find function "trim"
trim(c("  a ", "b  ", " c "))  # Returns c("a", "b", "c")
#> Error in trim(c("  a ", "b  ", " c ")): could not find function "trim"
```
