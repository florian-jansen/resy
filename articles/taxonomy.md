# Harmonising taxonomy before classification

``` r

library(RESY)
```

## Why a separate step

[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
is taxonomy-agnostic: it classifies the species names it is given,
matching them against the vocabulary of the expert system. It works best
when the names in your plot data already match that vocabulary, which is
the case for data drawn from the European Vegetation Archive.

Plot data named under a general backbone (GBIF, World Flora Online,
POWO, Euro+Med, a national checklist) will often use different strings
for the same taxon: an accepted-name synonym, an author citation, or a
spelling variant. Those names have to be harmonised to the expert
vocabulary first. RESY keeps that as an explicit step rather than hiding
it inside the classifier, so the taxonomic decisions stay visible and
you can check them before they affect a classification.

The workflow is: resolve names, inspect the result, then classify.

## The shipped synonym table

RESY ships a synonym table that maps alternate species names to the
canonical name used by the EUNIS-ESy expert system. It pools synonymy
from six backbones (Euro+Med, WFO, GBIF, Catalogue of Life, ITIS, NCBI),
so a name coming from any of them can resolve without you having to say
which backbone it came from.

``` r

syn <- resy_read_synonyms()
nrow(syn)
#> [1] 60911
head(syn)
#>                    synonym          esy_canonical       source
#> 1       Abelmoschus bammia Abelmoschus esculentus col;gbif;wfo
#> 2  Abelmoschus longifolius Abelmoschus esculentus col;gbif;wfo
#> 3      Abelmoschus praecox Abelmoschus esculentus col;gbif;wfo
#> 4 Abelmoschus tuberculatus Abelmoschus esculentus col;gbif;wfo
#> 5          Hibiscus bammia Abelmoschus esculentus col;gbif;wfo
#> 6   Hibiscus hispidissimus Abelmoschus esculentus col;gbif;wfo
```

Each row is one alternate spelling (`synonym`), the canonical ESy name
it resolves to (`esy_canonical`), and the backbone(s) that support the
pairing (`source`).

## Resolve names

[`resy_resolve_taxa()`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md)
maps a column of names to the canonical vocabulary. A name already equal
to a canonical name resolves to itself (`"exact"`); otherwise it is
looked up in the synonym table (`"synonym"`); a name matching neither
stays `NA` and is flagged `"unresolved"`. Nothing is ever replaced with
a best guess.

``` r

plots <- data.frame(
  TaxonName = c(
    "Hibiscus praecox",        # a synonym in the shipped table
    "Abelmoschus longifolius",  # another synonym
    "Fagus sylvatica",          # already a canonical name
    "Not a real species 123"    # resolves to nothing
  ),
  stringsAsFactors = FALSE
)

resolved <- resy_resolve_taxa(plots, species_col = "TaxonName")
resolved
#>                 TaxonName              canonical taxon_confidence
#> 1        Hibiscus praecox Abelmoschus esculentus          synonym
#> 2 Abelmoschus longifolius Abelmoschus esculentus          synonym
#> 3         Fagus sylvatica        Fagus sylvatica            exact
#> 4  Not a real species 123                   <NA>       unresolved
```

[`resy_summarize_taxa()`](https://florian-jansen.github.io/resy/reference/resy_summarize_taxa.md)
reports how many names resolved, the breakdown by confidence, and the
distinct names that stayed unresolved.

``` r

resy_summarize_taxa(resolved, species_col = "TaxonName")
#> $n
#> [1] 4
#> 
#> $resolved
#> [1] 3
#> 
#> $unresolved
#> [1] 1
#> 
#> $by_confidence
#>   confidence n prop
#> 1      exact 1 0.25
#> 2    synonym 2 0.50
#> 3 unresolved 1 0.25
#> 
#> $unresolved_taxa
#> [1] "Not a real species 123"
```

The unresolved names are yours to handle: correct a spelling, add a row
to your own crosswalk, or leave them out. The package will not decide
for you.

## Bring your own crosswalk

You are not tied to the shipped table.
[`resy_resolve_taxa()`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md)
accepts any crosswalk with three columns: `synonym`, `esy_canonical`,
and `source`. A small example ships with the package.

``` r

cw_path <- system.file("extdata", "example_crosswalk.csv", package = "RESY")
crosswalk <- resy_read_synonyms(cw_path)
crosswalk
#>               synonym    esy_canonical               source
#> 1     Fagus silvatica  Fagus sylvatica orthographic variant
#> 2    Pinus silvestris Pinus sylvestris orthographic variant
#> 3     Abies pectinata       Abies alba    taxonomic synonym
#> 4   Nardus stricta L.   Nardus stricta      author citation
#> 5 Anemone nemorosa L. Anemone nemorosa      author citation
```

Pass it to `synonyms=`, and give the target names to `canonical=` so
resolution uses your table alone:

``` r

my_plots <- data.frame(
  TaxonName = c("Fagus silvatica", "Abies pectinata", "Quercus robur"),
  stringsAsFactors = FALSE
)

resy_resolve_taxa(
  my_plots,
  species_col = "TaxonName",
  synonyms    = crosswalk,
  canonical   = unique(crosswalk$esy_canonical)
)
#>         TaxonName       canonical taxon_confidence
#> 1 Fagus silvatica Fagus sylvatica          synonym
#> 2 Abies pectinata      Abies alba          synonym
#> 3   Quercus robur            <NA>       unresolved
```

If your crosswalk lives in an Excel sheet, read it yourself and pass the
data frame. RESY validates the columns and uses it directly, so no Excel
package is added as a dependency and the file stays in a format you can
review:

``` r

crosswalk <- readxl::read_excel("my_crosswalk.xlsx")
resy_resolve_taxa(my_plots, synonyms = crosswalk,
                  canonical = unique(crosswalk$esy_canonical))
```

A synonym that maps to more than one canonical name is dropped rather
than resolved to an arbitrary pick, so an ambiguous table never produces
a silent substitution.

## Classify the resolved data

Once names are in the expert vocabulary, classify as usual. Write the
resolved canonical name back to the name column, keeping the original
where a name did not resolve, and pass it to
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md).

``` r

library(readr)

species <- read_csv(
  system.file("extdata", "data_example_species.csv", package = "RESY"),
  show_col_types = FALSE
)
species <- head(species, 200)   # keep the example quick

obs <- data.frame(
  PlotObservationID = species$PlotObservationID,
  TaxonName         = species$species,
  Cover_Perc        = species$cover,
  stringsAsFactors  = FALSE
)
header <- as.data.frame(unique(obs["PlotObservationID"]))

res <- resy_classify(obs, header, scheme = "Apennine-test")
head(res$result.classification)
#> HU32 KW76 YB18 NX70 OL48 YL40 
#>  "F"  "F"  "F"  "F"  "F"  "F"
```

For a quick pass, `resy_classify(..., resolve_taxa = TRUE)` runs the
resolution against the expert vocabulary and then classifies in a single
call, and reports what it did in `res$taxon_resolution`. Doing it in two
steps, as above, is the recommended route: it keeps the resolution
result in your hands so you can check the unresolved names before they
reach the classifier.

## Building a crosswalk with taxify

To assemble a crosswalk from offline backbone tables (no API calls), the
[taxify](https://github.com/gcol33/taxify) package matches names against
Euro+Med, WFO, GBIF, Catalogue of Life, ITIS, and NCBI and records the
supporting backbone for each match. Its output maps to the `synonym` /
`esy_canonical` / `source` schema
[`resy_resolve_taxa()`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md)
expects.
