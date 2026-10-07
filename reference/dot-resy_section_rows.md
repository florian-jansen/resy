# Locate the Rows of Section Markers

Finds the line numbers in a character vector that match the \`SECTION
\<n\>\` opener or closing marker.

## Usage

``` r
.resy_section_rows(lines, n)
```

## Arguments

- lines:

  character vector containing the lines of a parsed expert-system
  document.

- n:

  integer section number to search for, e.g. \`2\` for \`SECTION 2\`.

## Value

integer vector of matching line numbers.
