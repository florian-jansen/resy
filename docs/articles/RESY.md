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
  [FloraVeg.EU](https://floraveg.eu/))
- **Apennine-test** (a simplified test system for the Italian Apennines)

For EUNIS specifically, many formulas also require geographic columns
(`Ecoreg`, `Country`, `Coast_EEA`, `Dunes_Bohn`) in a sites header
table. Those preparation steps are covered in
[`vignette("EUNIS")`](https://loe.gitlab.uni-rostock.de/publications/r-esy/articles/EUNIS.md).

``` r

library(readr)
library(dplyr)
library(RESY)
```

------------------------------------------------------------------------

## 1. Load and prepare species data

[`resy_classify()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_classify.md)
expects the observation table to have three columns:

| Column              | Description                                   |
|---------------------|-----------------------------------------------|
| `PlotObservationID` | Plot identifier (auto-detected)               |
| `TaxonName`         | Species name                                  |
| `Cover_Perc`        | Cover value (percent or Braun-Blanquet scale) |

``` r

data_species <- read_csv(
  system.file("extdata", "data_example_species.csv", package = "RESY"),
  show_col_types = FALSE
) |>
  rename(TaxonName = species, Cover_Perc = cover)

glimpse(data_species)
#> Rows: 3,580
#> Columns: 3
#> $ PlotObservationID <chr> "HU32", "HU32", "HU32", "HU32", "HU32", "HU32", "HU3…
#> $ Cover_Perc        <dbl> 0.1, 0.1, 0.5, 0.5, 0.5, 0.5, 87.5, 3.0, 3.0, 3.0, 0…
#> $ TaxonName         <chr> "Dryopteris filix-mas (L.) Schott", "Cephalanthera l…
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

[`resy_available_classifications()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_available_classifications.md)
lists all schemes and versions available (# function
resy_available_classifications() only gives esy files bundled in the
package so far. Either expand or delete the function.

``` r

resy_available_classifications() |> select(scheme, version)
#>          scheme    version
#> 1 Apennine-test 2026-06-27
#> 2         EUNIS 2025-10-03
```

To add a custom expert system, use
[`resy_add_classification()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_add_classification.md).

[`resy_load_expert()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_load_expert.md)
parses a bundled classification into a `resy_parsed_expert` object, used
here for taxonomy checking.
[`resy_classify()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_classify.md)
loads the expert internally from `scheme`/`version`.

``` r

parsed_apennine <- resy_load_expert(scheme = "Apennine-test")
```

## 3. Check taxonomy

[`resy_check_taxonomy()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_check_taxonomy.md)
maps observation names against Section 1 of the expert system (canonical
names + synonyms). This is classification-specific: a name may resolve
in one system but not another.

``` r

tax_apennine <- resy_check_taxonomy(
  obs    = data_species,
  parsed = parsed_apennine,
  col    = "TaxonName"
)
cat("Apennine-test — matched:", sum(tax_apennine$matched),
    "/ unmatched:", sum(!tax_apennine$matched), "\n")
#> Apennine-test — matched: 1009 / unmatched: 0
```

## 4. Classify

[`resy_classify()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_classify.md)
evaluates all membership formulas and returns a `resy_result` object.
Pass `scheme` to select the bundled expert system; it will be loaded
automatically.

``` r

res_apennine <- resy_classify(
  obs    = data_species,
  header = header,
  scheme = "Apennine-test"
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
[`resy_view_expert()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_view_expert.md).

### Vegetation type details

[`resy_eval_type()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_eval_type.md)
shows conditiosn of a type is evaluated.

``` r

resy_eval_type(res_apennine, t = "FB")
#> FB    Beech-fir montane forest
#> 
#> (<#TC Beech-forest-trees GR 15> AND <#TC Beech-forest-herbs GR 10>)
#> 
#> (col2 & col3)
#> 
#>   expressions                 
#> 2 #TC Beech-forest-trees GR 15
#> 3 #TC Beech-forest-herbs GR 10
```

### Long table of candidates for all plots

[`resy_candidates()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_candidates.md)
extracts ranked classification results. Use `top_n` to limit the number
of types returned per plot.

``` r

cand_apennine <- resy_candidates(res_apennine, top_n = 3)
head(cand_apennine)
#>    plot_id   type priority priority_rank
#>     <char> <char>    <ord>         <int>
#> 1:    AM30      F        2             1
#> 2:    AN57      F        2             1
#> 3:    BE71      F        2             1
#> 4:    BE71     FB        5             3
#> 5:    BK34      N        2             1
#> 6:    BK34     NS        3             2
```

### Plot-level details

[`resy_eval_plot()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_eval_plot.md)
prints the full evidence for one plot: which species matched, which
group conditions fired, and which vegetation-type formulas evaluated to
`TRUE`.

``` r

# Replace "AN57" with a PlotObservationID present in your data
resy_eval_plot(res_apennine, p = "AN57")
#> Plant observations for plot AN57 :
#>     PlotObservationID Cover_Perc               TaxonName        group_names
#>                <char>      <num>                  <char>             <char>
#>  1:              AN57        0.1 Gymnocarpium dryopteris               <NA>
#>  2:              AN57        0.1   Athyrium filix-femina               <NA>
#>  3:              AN57        0.1     Prenanthes purpurea Beech-forest-herbs
#>  4:              AN57        0.1      Dryopteris expansa               <NA>
#>  5:              AN57        0.1      Polypodium vulgare               <NA>
#>  6:              AN57        0.5       Oxalis acetosella Beech-forest-herbs
#>  7:              AN57        0.5        Sorbus aucuparia               <NA>
#>  8:              AN57        0.5              Abies alba Beech-forest-trees
#>  9:              AN57       62.5         Fagus sylvatica Beech-forest-trees
#> 10:              AN57       37.5     Vaccinium myrtillus   Nardus-grassland
#> Possible types of plot "AN57" (135): F
#> Priorities of these types: 1 
#> Classified as: F
```

## Next steps

- For EUNIS with geographic enrichment (ecoregion, country, coast), see
  [`vignette("EUNIS")`](https://loe.gitlab.uni-rostock.de/publications/r-esy/articles/EUNIS.md).
- To validate an ESy text file before importing, use
  [`resy_validate_esy()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_validate_esy.md).
