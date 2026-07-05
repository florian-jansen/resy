# Remove taxonomic authorities from scientific names

Strips author citations from scientific plant names while keeping
infraspecific ranks (`subsp.`, `var.`, `f.`, ...), so that names from
different taxonomic backbones resolve against the canonical names and
synonyms of an expert system. The genus and species epithet are always
kept; when an infraspecific rank marker is present, the marker and its
epithet are kept too. Names with fewer than two words are returned
unchanged.

## Usage

``` r
resy_clean_names(x)
```

## Arguments

- x:

  A character vector of scientific names, optionally carrying author
  citations (for example `"Fagus sylvatica L."`).

## Value

A character vector the same length as `x` with author citations removed.
`NA` values are preserved.

## Examples

``` r
resy_clean_names(c(
  "Fagus sylvatica L.",
  "Epipactis helleborine (L.) Crantz subsp. helleborine",
  "Senecio ovatus (G.Gaertn., B.Mey. & Scherb.) Willd."
))
#> [1] "Fagus sylvatica"                         
#> [2] "Epipactis helleborine subsp. helleborine"
#> [3] "Senecio ovatus"                          
```
