# Classifying vegetation surveys with RESY

## Introduction

RESY implements the **Expert System (ESy)** framework for vegetation
classification (Bruelheide [1997](https://doi.org/10.1007/BF02803883);
Chytrý et al. [2020](https://doi.org/10.1111/avsc.12519)). An ESy file
encodes three sections:

1.  **Taxonomy** – species aggregations and synonyms  
2.  **Taxon groups** – species assemblages referenced in classification
    conditions  
3.  **Vegetation types** – logical formulas that combine group
    thresholds into named habitat types

The package can work with any ESy-compliant classification. This
vignette uses two bundled systems:

- **EUNIS** (European Nature Information System habitat types;
  [FloraVeg.EU](https://floraveg.eu/habitat/))
- **Apennine-test** (a simplified test system for the Italian Apennines)

For EUNIS specifically, many formulas also require geographic columns
(`Ecoreg`, `Country`, `Coast_EEA`, `Dunes_Bohn`) in a sites header
table. Those preparation steps are covered in
[`vignette("EUNIS")`](https://florian-jansen.github.io/resy/articles/EUNIS.md).

``` r

library(readr)
library(dplyr)
library(RESY)
```

------------------------------------------------------------------------

## 1. Load and prepare species data

[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
expects the observation table to have three columns. The species column
can have any name, passed as `species_col`:

| Column              | Description                                         |
|---------------------|-----------------------------------------------------|
| `PlotObservationID` | Plot identifier (auto-detected)                     |
| `TaxonName`         | Species name (`species_col`, here `scientificName`) |
| `Cover_Perc`        | Cover value (percent or Braun-Blanquet scale)       |

``` r

data_species <- read_csv(
  system.file("extdata", "data_example_species.csv", package = "RESY"),
  show_col_types = FALSE
)

glimpse(data_species)
#> Rows: 3,580
#> Columns: 3
#> $ PlotObservationID <chr> "HU32", "HU32", "HU32", "HU32", "HU32", "HU32", "HU3…
#> $ Cover_Perc        <dbl> 0.1, 0.1, 0.5, 0.5, 0.5, 0.5, 87.5, 3.0, 3.0, 3.0, 0…
#> $ scientificName    <chr> "Dryopteris filix-mas (L.) Schott", "Cephalanthera l…
```

A minimal **header** table (one row per plot) is required even when no
geographic conditions are used. It must contain the same plot ID column
as the observation table.

``` r

header <- data_species |>
  distinct(PlotObservationID) |>
  as.data.frame()
```

------------------------------------------------------------------------

## 2. Load expert systems

[`resy_available_classifications()`](https://florian-jansen.github.io/resy/reference/resy_available_classifications.md)
lists the schemes and versions bundled with the package.

``` r

resy_available_classifications() |> select(scheme, version)
#>          scheme    version
#> 1 Apennine-test 2026-06-27
#> 2         EUNIS 2025-10-03
```

To add a custom expert system, use
[`resy_add_classification()`](https://florian-jansen.github.io/resy/reference/resy_add_classification.md).

[`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md)
parses a bundled classification into a `resy_parsed_expert` object, used
here for taxonomy checking.
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
loads the expert internally from `scheme`/`version`.

``` r

parsed_apennine <- resy_load_expert(scheme = "Apennine-test")
```

## 3. Check taxonomy

[`resy_check_taxonomy()`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md)
maps observation names against Section 1 of the expert system (canonical
names + synonyms). This is classification-specific: a name may resolve
in one system but not another. The result has one row per distinct name:
`scientificName` is the name as submitted, `TaxonName` the canonical
name the classifier uses (`NA` when unmatched), and `matched` whether it
was found. Printing it lists what each column holds and how many names
matched.

``` r

tax_apennine <- resy_check_taxonomy(
  obs    = data_species,
  parsed = parsed_apennine,
  col    = "scientificName"
)
tax_apennine
#> <resy_taxa> 1009 name(s) from column `scientificName` checked against 950 Section 1 species
#>   scientificName  Name as submitted
#>   TaxonName       Canonical name used by resy_classify(); NA when unmatched
#>   matched         TRUE if found as a canonical name or Section 1 synonym
#> 1009 matched (100.0%), 0 unmatched
#> 
#>                                          scientificName
#> 1                      Dryopteris filix-mas (L.) Schott
#> 2                 Cephalanthera longifolia (L.) Fritsch
#> 3                                Prenanthes purpurea L.
#> 4                                   Anemone nemorosa L.
#> 5  Epipactis helleborine (L.) Crantz subsp. helleborine
#> 6                  Sorbus aucuparia L. subsp. aucuparia
#> 7                                    Fagus sylvatica L.
#> 8                           Rubus hirtus Waldst. & Kit.
#> 9                                      Abies alba Mill.
#> 10                                 Oxalis acetosella L.
#>                   TaxonName matched
#> 1      Dryopteris filix-mas    TRUE
#> 2  Cephalanthera longifolia    TRUE
#> 3       Prenanthes purpurea    TRUE
#> 4          Anemone nemorosa    TRUE
#> 5     Epipactis helleborine    TRUE
#> 6          Sorbus aucuparia    TRUE
#> 7           Fagus sylvatica    TRUE
#> 8              Rubus hirtus    TRUE
#> 9                Abies alba    TRUE
#> 10        Oxalis acetosella    TRUE
#> # ... 999 more row(s)
```

[`summary()`](https://rspatial.github.io/terra/reference/summary.html)
gives the match counts and lists the names that did not match:

``` r

summary(tax_apennine)
#> 1009 names checked: 1009 matched (100.0%), 0 not matched (0.0%).
```

## 4. Classify

[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
evaluates all membership formulas and returns a `resy_result` object.
Pass `scheme` to select the bundled expert system; it will be loaded
automatically.

``` r

res_apennine <- resy_classify(
  obs         = data_species,
  header      = header,
  scheme      = "Apennine-test",
  species_col = "scientificName"
)
```

------------------------------------------------------------------------

## 5. Inspect results

### Print classification hierarchy

``` r

tree_filled <- resy_expert_tree(parsed_apennine, fill = TRUE)
print(tree_filled)
#> <resy_expert_tree> 5 node(s), 2 top-level
#> F Forest
#>   FB Beech-fir montane forest
#> N Non-forest
#>   NG Nardus acidic grassland
#>   NS Sub-Mediterranean scrub and woodland
```

To browse the type hierarchy of a loaded system, use
[`resy_view_expert()`](https://florian-jansen.github.io/resy/reference/resy_view_expert.md).

### Long table of candidates for all plots

[`resy_candidates()`](https://florian-jansen.github.io/resy/reference/resy_candidates.md)
extracts ranked classification results. Use `top_n` to limit the number
of types returned per plot.

``` r

cand_apennine <- resy_candidates(res_apennine, top_n = 3)
head(cand_apennine)
#>    plot_id   type priority priority_rank
#>     <char> <char>    <ord>         <int>
#> 1:    AM30      F        2             1
#> 2:    AN57      F        2             1
#> 3:    BE71     FB        5             3
#> 4:    BE71      F        2             1
#> 5:    BK34     NS        3             2
#> 6:    BK34      N        2             1
```

### Plot-level details

[`resy_eval_plot()`](https://florian-jansen.github.io/resy/reference/resy_eval_plot.md)
prints the full evidence for one plot: its species, which
vegetation-type formulas evaluated to `TRUE`, and the type it is
classified as. It then lists the lower-level types the plot did not
reach, with the result of each of their conditions, which shows why the
classification stopped at this level.

``` r

# Replace "AN57" with a PlotObservationID present in your data
resy_eval_plot(res_apennine, p = "AN57")
#> Types whose rule holds: F (priority 2)
#> Classified as F (Forest).
#> 
#> Plot AN57: 10 species
#>  species                 cover
#>  Fagus sylvatica         62.5 
#>  Vaccinium myrtillus     37.5 
#>  Abies alba               0.5 
#>  Oxalis acetosella        0.5 
#>  Sorbus aucuparia         0.5 
#>  Athyrium filix-femina    0.1 
#>  Dryopteris expansa       0.1 
#>  Gymnocarpium dryopteris  0.1 
#>  Polypodium vulgare       0.1 
#>  Prenanthes purpurea      0.1 
#> 
#> Why not a lower level of F:
#> 
#> FB    Beech-fir montane forest: rule not met
#>       Rule: [1] and [2]
#>       [1] met      total cover of Beech-forest-trees is 62.7%, needs more than 15%
#>                    Fagus sylvatica 62.5, Abies alba 0.5
#>       [2] not met  total cover of Beech-forest-herbs is 0.6%, needs more than 10%
#>                    Oxalis acetosella 0.5, Prenanthes purpurea 0.1
```

Passing `type` explains any other type in the same way, whether or not
its rule holds for the plot:

``` r

resy_eval_plot(res_apennine, p = "AN57", type = "F")
#> Types whose rule holds: F (priority 2)
#> Classified as F (Forest).
#> 
#> Plot AN57: 10 species
#>  species                 cover
#>  Fagus sylvatica         62.5 
#>  Vaccinium myrtillus     37.5 
#>  Abies alba               0.5 
#>  Oxalis acetosella        0.5 
#>  Sorbus aucuparia         0.5 
#>  Athyrium filix-femina    0.1 
#>  Dryopteris expansa       0.1 
#>  Gymnocarpium dryopteris  0.1 
#>  Polypodium vulgare       0.1 
#>  Prenanthes purpurea      0.1 
#> 
#> Why not a lower level of F:
#> 
#> FB    Beech-fir montane forest: rule not met
#>       Rule: [1] and [2]
#>       [1] met      total cover of Beech-forest-trees is 62.7%, needs more than 15%
#>                    Fagus sylvatica 62.5, Abies alba 0.5
#>       [2] not met  total cover of Beech-forest-herbs is 0.6%, needs more than 10%
#>                    Oxalis acetosella 0.5, Prenanthes purpurea 0.1
#> 
#> F     Forest: rule holds
#>       Rule: [1]
#>       [1] met      total cover of Beech-forest-trees is 62.7%, needs more than 10%
#>                    Fagus sylvatica 62.5, Abies alba 0.5
```

## Next steps

- For EUNIS with geographic enrichment (ecoregion, country, coast), see
  [`vignette("EUNIS")`](https://florian-jansen.github.io/resy/articles/EUNIS.md).
- To validate an ESy text file before importing, use
  [`resy_validate_esy()`](https://florian-jansen.github.io/resy/reference/resy_validate_esy.md).
