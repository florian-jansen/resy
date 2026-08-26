# Resolve plot species names to canonical ESy names

Maps a column of plot species names to the canonical ESy names used by
the expert system, so the result can be classified with
[`resy_classify`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
without hand-harmonising names. A name already equal to a canonical ESy
name resolves to itself (`"exact"`); otherwise it is looked up in the
synonym table (`"synonym"`); a name matching neither is left `NA` and
flagged `"unresolved"` – never replaced with a best guess.

## Usage

``` r
resy_resolve_taxa(
  obs,
  species_col = "TaxonName",
  synonyms = NULL,
  canonical = NULL
)
```

## Arguments

- obs:

  A data frame (or `data.table`) of plot observations.

- species_col:

  Name of the column in `obs` holding the species name (default
  `"TaxonName"`).

- synonyms:

  `NULL` (default) uses the shipped synonym table; pass a path or data
  frame to override it.

- canonical:

  `NULL` (default) uses the shipped canonical list for the exact-match
  step; pass a path, a data frame, or a character vector of names to
  override it
  ([`resy_classify`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
  passes the expert system's own vocabulary here, so any name the expert
  already knows is left untouched).

## Value

`obs` with two appended columns: `canonical` (the resolved ESy name,
`NA` when unresolved) and `taxon_confidence` (`"exact"`, `"synonym"`, or
`"unresolved"`).

## Details

The synonym table pools synonymy from six backbones (Euro+Med, WFO,
GBIF, COL, ITIS, NCBI), so plot data named under any of them resolves
without the caller needing to say which backbone the names came from.

## See also

[`resy_read_synonyms`](https://florian-jansen.github.io/resy/reference/resy_read_synonyms.md),
[`resy_summarize_taxa`](https://florian-jansen.github.io/resy/reference/resy_summarize_taxa.md),
[`resy_classify`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
