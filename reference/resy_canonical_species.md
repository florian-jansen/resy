# Export the canonical ESy species list

Returns the canonical ESy species names – the set the expert system
aggregates over, and the target column a user builds a translation table
against. Also the authority used by
[`resy_resolve_taxa`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md)
for the exact-match step.

## Usage

``` r
resy_canonical_species(path = NULL)
```

## Arguments

- path:

  `NULL` (default) loads the shipped
  `inst/extdata/esy_canonical.csv.xz`. A character path or data frame
  (with an `esy_canonical` column) reads the canonical names from an
  override instead.

## Value

A sorted character vector of unique canonical ESy species names.

## See also

[`resy_read_synonyms`](https://florian-jansen.github.io/resy/reference/resy_read_synonyms.md),
[`resy_resolve_taxa`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md)
