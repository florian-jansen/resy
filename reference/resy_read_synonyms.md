# Read the taxonomy synonym table

Returns the table of alternate species names mapped to the species names
of an expert system. Each row is a synonym pair: an alternate string a
plot dataset might carry, keyed to the name of the expert system it
resolves to; `source` records the taxonomic backbone(s) that support the
synonym pair (`;`-separated when more than one).

## Usage

``` r
resy_read_synonyms(path = NULL, expert = NULL)
```

## Arguments

- path:

  `NULL` (default) anchors the shipped synonym layer on `expert`. A
  character path loads a user CSV (optionally `.gz`/`.xz`) with the same
  schema. A data frame is validated and returned unchanged.

- expert:

  An expert system read with
  [`resy_load_expert`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md),
  used when `path = NULL`. `NULL` (default) uses the newest EUNIS
  release, the expert system
  [`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md)
  reads by default.

## Value

A data frame with columns `synonym`, `esy_canonical`, and `source`, and
`accepted_in` when the table has it.

## Details

RESY ships one synonym layer for all expert systems and all their
releases: the synonym pairs of six taxonomic backbones (Euro+Med, WFO,
GBIF, COL, ITIS, NCBI). With `path = NULL`, the layer is anchored on the
expert system given in `expert`, so each release gets a table that fits
its own species names:

- A pair is kept when its target is a name the expert system evaluates:
  an aggregate name of Section 1, or a species that a species group or a
  membership condition names and that no aggregate absorbs.

- A synonym with more than one such target is resolved by Euro+Med, the
  taxonomy of the EUNIS expert system. Its single answer is kept;
  otherwise the synonym is dropped.

- A name the expert system already uses is never remapped.

- A synonym that Euro+Med accepts as a species is kept only when it is
  the same Euro+Med concept as its target (an orthographic or gender
  variant).

The anchored table is kept for the rest of the session.

The table also has an `accepted_in` column: the backbones that list the
synonym as an accepted name under the same author as the synonym rows
supporting the synonym pair. A backbone appears in both `source` and
`accepted_in` when it holds an accepted row and a synonym row for the
name. The column is empty when no backbone accepts the name. The
synonyms are binomials (genus and species epithet); infraspecific names,
hybrid formulas, and bare genera are not in it. The build date of the
layer and the version of each backbone are recorded in
`inst/extdata/esy_synonym_layer_build.csv` and
`inst/extdata/esy_synonym_layer_backbones.csv`.

## See also

[`resy_resolve_taxa`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md),
[`resy_canonical_species`](https://florian-jansen.github.io/resy/reference/resy_canonical_species.md)

## Examples

``` r
synonyms <- resy_read_synonyms()
head(synonyms)
#>                    synonym          esy_canonical       source accepted_in
#> 1       Abelmoschus bammia Abelmoschus esculentus col;gbif;wfo        <NA>
#> 2  Abelmoschus longifolius Abelmoschus esculentus col;gbif;wfo        <NA>
#> 3      Abelmoschus praecox Abelmoschus esculentus col;gbif;wfo        <NA>
#> 4 Abelmoschus tuberculatus Abelmoschus esculentus col;gbif;wfo        <NA>
#> 5          Hibiscus bammia Abelmoschus esculentus col;gbif;wfo        <NA>
#> 6      Hibiscus ficifolius Abelmoschus esculentus col;gbif;wfo        <NA>
```
