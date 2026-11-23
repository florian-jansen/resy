# Resolve plot species names to canonical ESy names

Maps a column of plot species names to the canonical ESy names used by
the expert system, so the result can be classified with
[`resy_classify`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
without hand-harmonising names. A name already equal to a canonical ESy
name resolves to itself (`"exact"`); otherwise it is looked up in the
synonym table (`"synonym"`). A name that matches neither as given is
tried again with its author citation removed by
[`resy_clean_names`](https://florian-jansen.github.io/resy/reference/resy_clean_names.md)
(`"cleaned_exact"`, `"cleaned_synonym"`); the cleaned form is used only
for matching, so a name is never altered when it already matches. A name
that still matches nothing is left `NA` and flagged `"unresolved"`; it
is never replaced with a best guess.

## Usage

``` r
resy_resolve_taxa(
  obs,
  species_col = NULL,
  synonyms = NULL,
  canonical = NULL,
  expert = NULL
)
```

## Arguments

- obs:

  A data frame (or `data.table`) of plot observations.

- species_col:

  Name of the column in `obs` holding the species name. If `NULL`
  (default), uses `TaxonName`, then Darwin Core `scientificName`.

- synonyms:

  `NULL` (default) uses the shipped synonym layer anchored on `expert`
  (see
  [`resy_read_synonyms`](https://florian-jansen.github.io/resy/reference/resy_read_synonyms.md));
  pass a path or data frame to override it.

- canonical:

  `NULL` (default) uses every species name `expert` knows for the
  exact-match step, so a name the expert system already uses is left
  untouched; pass a path, a data frame, or a character vector of names
  to override it.

- expert:

  An expert system read with
  [`resy_load_expert`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md),
  whose species names the plot names are resolved to. `NULL` (default)
  uses the newest EUNIS release. Not read when both `synonyms` and
  `canonical` are given.

## Value

A `resy_taxa` data frame: `obs` with three appended columns, `canonical`
(the resolved ESy name, `NA` when unresolved), `taxon_confidence`
(`"exact"`, `"synonym"`, `"cleaned_exact"`, `"cleaned_synonym"`, or
`"unresolved"`), and `matched` (`TRUE` unless unresolved).

## Details

The synonym table pools synonymy from six backbones (Euro+Med, WFO,
GBIF, COL, ITIS, NCBI), so plot data named under any of them resolves
without the caller needing to say which backbone the names came from.

The result is a `resy_taxa` data frame, the same class
[`resy_check_taxonomy`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md)
returns. Printing it shows what each column holds and how many distinct
names resolved; [`summary()`](https://rdrr.io/r/base/summary.html)
returns the counts per name and per record, the records by match type,
and the names that stayed unresolved.

## See also

[`resy_read_synonyms`](https://florian-jansen.github.io/resy/reference/resy_read_synonyms.md),
[`resy_check_taxonomy`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md),
[`resy_classify`](https://florian-jansen.github.io/resy/reference/resy_classify.md)

## Examples

``` r
obs <- data.frame(
  PlotObservationID = c("p1", "p2"),
  TaxonName = c("Quercus robur", "Poa annua")
)

resolved <- resy_resolve_taxa(obs, species_col = "TaxonName")
resolved[, c("PlotObservationID", "TaxonName", "canonical", "taxon_confidence", "matched")]
#> <resy_taxa> 2 name(s) from column `TaxonName` resolved against 121877 reference names
#>   TaxonName         name as submitted
#>   canonical         resolved canonical name; NA when unresolved
#>   taxon_confidence  exact, synonym, cleaned_exact, cleaned_synonym or unresolved
#>   matched           TRUE if the name resolved
#>   (1 other column(s) not shown: PlotObservationID)
#> 2 matched (100.0%), 0 unmatched
#> 
#>       TaxonName     canonical taxon_confidence matched
#> 1 Quercus robur Quercus robur            exact    TRUE
#> 2     Poa annua     Poa annua            exact    TRUE
```
