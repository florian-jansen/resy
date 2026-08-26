# Read the taxonomy synonym table

Loads the shipped table of alternate species names mapped to their
canonical ESy name. Each synonym is an alternate string a plot dataset
might carry, keyed to the canonical ESy species it resolves to; `source`
records the taxonomic backbone(s) that support the pairing
(`;`-separated when more than one). Pass `path = NULL` for the shipped
table, a file path for a user CSV, or a data frame to validate one
already in memory.

## Usage

``` r
resy_read_synonyms(path = NULL)
```

## Arguments

- path:

  `NULL` (default) loads the shipped `inst/extdata/esy_synonyms.csv.xz`.
  A character path loads a user CSV (optionally `.gz`/`.xz`) with the
  same schema. A data frame is validated and returned unchanged.

## Value

A data frame with columns `synonym`, `esy_canonical`, and `source`.

## See also

[`resy_resolve_taxa`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md),
[`resy_canonical_species`](https://florian-jansen.github.io/resy/reference/resy_canonical_species.md)
