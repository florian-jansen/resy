# Export the canonical species names of an expert system

Returns the canonical species names of an expert system: the names its
classifier evaluates, which is the target column a user builds a
translation table against. These are the aggregate names of Section 1,
and the species that a species group or a membership condition names and
that no aggregate absorbs.

## Usage

``` r
resy_canonical_species(path = NULL, expert = NULL)
```

## Arguments

- path:

  `NULL` (default) takes the canonical names from `expert`. A character
  path or data frame (with an `esy_canonical` column) reads the
  canonical names from an override instead.

- expert:

  An expert system read with
  [`resy_load_expert`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md),
  used when `path = NULL`. `NULL` (default) uses the newest EUNIS
  release.

## Value

A sorted character vector of unique canonical species names.

## See also

[`resy_read_synonyms`](https://florian-jansen.github.io/resy/reference/resy_read_synonyms.md),
[`resy_resolve_taxa`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md)

## Examples

``` r
canonical <- resy_canonical_species()
head(canonical)
#> [1] "ARC_COAST"              "ATL_COAST"              "Abelmoschus esculentus"
#> [4] "Abies alba"             "Abies balsamea"         "Abies borisii-regis"   
```
