# Trim Trailing Whitespace and Specific Patterns

Removes trailing whitespace, digits, or patterns like "- \<digit\>" from
strings. This is useful for cleaning up labels or identifiers with
trailing artifacts.

## Usage

``` r
trim.trailing(x)
```

## Arguments

- x:

  A character vector.

## Value

A character vector with trailing patterns removed. \#' @details This
function targets common trailing artifacts in RESY data, such as spaces
followed by digits or hyphen-digit combinations (e.g., " - 1"). It does
not handle all possible trailing patterns; for more complex cases, use
regular expressions directly

## See also

\[trim()\], \[trim.leading()\]

## Examples

``` r
trim.trailing("text  ")      # Returns "text"
#> Error in trim.trailing("text  "): could not find function "trim.trailing"
trim.trailing("text- 1")    # Returns "text-"
#> Error in trim.trailing("text- 1"): could not find function "trim.trailing"
trim.trailing("text 123")   # Returns "text"
#> Error in trim.trailing("text 123"): could not find function "trim.trailing"
```
