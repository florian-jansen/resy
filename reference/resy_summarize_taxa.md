# Summarise a taxonomy-resolution result

Diagnostic over the output of
[`resy_resolve_taxa`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md):
how many input records resolved to a canonical name, the breakdown by
confidence, and (optionally) the distinct input values that stayed
unresolved.

## Usage

``` r
resy_summarize_taxa(resolved, species_col = NULL)
```

## Arguments

- resolved:

  The data frame returned by
  [`resy_resolve_taxa`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md)
  (must carry a `taxon_confidence` column).

- species_col:

  Optional name of the original name column in `resolved`; when
  supplied, the distinct unresolved input values are listed.

## Value

A list with elements `n` (records), `resolved`, `unresolved`,
`by_confidence` (a data frame of confidence level, count, and
proportion), and `unresolved_taxa` (character vector, empty unless
`species_col` is given).

## See also

[`resy_resolve_taxa`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md)
