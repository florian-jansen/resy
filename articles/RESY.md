# Classifying vegetation plots with RESY

This vignette classifies 200 example vegetation plots from Tuscany with
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md),
from reading the species table to looking at why a plot was assigned to
its type. It assumes basic knowledge of R and data frames.

RESY assigns plots to vegetation or habitat types with an expert system
(ESy; Bruelheide [1997](https://doi.org/10.1007/BF02803883); Bruelheide
et al. [2021](https://doi.org/10.1111/avsc.12562)), a text file of rules
with three sections:

1.  **Taxonomy**: which species names count as one taxon, for example a
    species and its subspecies.
2.  **Species groups**: sets of indicator species, such as beech-forest
    herbs, that the rules refer to.
3.  **Vegetation types**: for each type, a rule on the cover of the
    species groups, for example “beech and silver fir together cover
    more than 15%”.

RESY can use any expert system written in this format. This vignette
uses `Apennine-test`, a small expert system for the Italian Apennines
whose rules need no site data. The EUNIS expert system (Chytrý et al.
[2020](https://doi.org/10.1111/avsc.12519)) also uses site data, such as
the ecoregion and the country;
[`vignette("EUNIS")`](https://florian-jansen.github.io/resy/articles/EUNIS.md)
shows how to add them.

``` r

library(readr)
library(dplyr)
library(RESY)
```

## Load and prepare species data

[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
expects a species table (argument `obs`) with one row per species in
each plot and three columns. Each column can also have its [Darwin
Core](https://dwc.tdwg.org/) name, the standard set of field names for
biodiversity data:

| Column | Darwin Core name | Description |
|----|----|----|
| `PlotObservationID` | `eventID` | Plot identifier |
| `TaxonName` | `scientificName` | Species name |
| `Cover_Perc` | `organismQuantity`, with `organismQuantityType` `"% cover"` | Cover of the species in percent |

For a species column with any other name, set `species_col`. The example
data uses `scientificName`.

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

The **header** table has one row per plot, with the plot ID and the site
data the rules use, such as the country or the altitude. `Apennine-test`
uses no site data, so here the header table contains only the plot IDs,
but
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
still requires it. It must contain the same plot ID column as the
species table.

``` r

header <- data_species |>
  distinct(PlotObservationID) |>
  as.data.frame()
```

## Load expert systems

[`resy_available_classifications()`](https://florian-jansen.github.io/resy/reference/resy_available_classifications.md)
lists the schemes and versions bundled with the package.

``` r

resy_available_classifications() |> select(scheme, version)
#>          scheme    version
#> 1 Apennine-test 2026-06-27
#> 2         EUNIS 2025-10-03
```

To add your own expert system, use
[`resy_add_classification()`](https://florian-jansen.github.io/resy/reference/resy_add_classification.md).

[`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md)
reads a bundled expert system into a `resy_parsed_expert` object, which
the taxonomy check below uses.
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
does not need this object: it loads the expert system itself from
`scheme` and `version`.

``` r

parsed_apennine <- resy_load_expert(scheme = "Apennine-test")
```

The types of an expert system form a hierarchy.
[`resy_expert_tree()`](https://florian-jansen.github.io/resy/reference/resy_expert_tree.md)
prints it; `fill = TRUE` adds the group levels that the type codes imply
but the expert system does not list:

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

`Apennine-test` has two top-level types, forest (`F`) and non-forest
(`N`), each with lower-level types. To browse the hierarchy in the
browser, use
[`resy_view_expert()`](https://florian-jansen.github.io/resy/reference/resy_view_expert.md).

## Check taxonomy

[`resy_check_taxonomy()`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md)
checks the species names of the species table against the species list
of the expert system, including its synonyms. Each expert system has its
own list, so a name can match in one system and not in another. The
result has one row per distinct name: `scientificName` is the name as
submitted, `TaxonName` the name the expert system uses for it (`NA` when
unmatched), and `matched` whether it was found. Printing it lists what
each column holds and how many names matched.

``` r

tax_apennine <- resy_check_taxonomy(obs = data_species, parsed = parsed_apennine)
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

## Classify

[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
evaluates the rules of every type for every plot and returns a
`resy_result` object. `scheme` selects the bundled expert system.

``` r

res_apennine <- resy_classify(
  obs    = data_species,
  header = header,
  scheme = "Apennine-test"
)
```

Each plot is assigned to one type.
[`resy_candidates()`](https://florian-jansen.github.io/resy/reference/resy_candidates.md)
with `wide = TRUE` gives one row per plot; counting its `classification`
column shows how many plots went to each type:

``` r

cand_wide <- resy_candidates(res_apennine, wide = TRUE)
table(cand_wide$classification)
#> 
#>  ?  F FB  N NG NS 
#> 92 33  8  6 20 41
```

A plot marked `?` meets no type’s rule and is not classified. Here, 92
of the 200 plots remain unclassified. In these plots, all four indicator
groups have at most 4% cover, below the lowest threshold in the rules
(5%).

## Inspect results

### Candidate types for all plots

A plot often meets the rules of several types, for example a lower-level
type and its parent. Each type has a priority in the expert system, and
the plot is assigned to the type with the highest priority.
[`resy_candidates()`](https://florian-jansen.github.io/resy/reference/resy_candidates.md)
lists every type whose rule a plot meets, highest priority first.
`priority_rank` is the priority level of the type: the higher the rank,
the higher the priority. Use `top_n` to limit the number of types
returned per plot.

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

resy_eval_plot(res_apennine, p = "AN57", type = "FB")
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
#> FB    Beech-fir montane forest: rule not met
#>       Rule: [1] and [2]
#>       [1] met      total cover of Beech-forest-trees is 62.7%, needs more than 15%
#>                    Fagus sylvatica 62.5, Abies alba 0.5
#>       [2] not met  total cover of Beech-forest-herbs is 0.6%, needs more than 10%
#>                    Oxalis acetosella 0.5, Prenanthes purpurea 0.1
```

## Next steps

The classification above used an expert system without site data and
species names that already match it. With your own plots, one of these
usually comes next:

- **Your plots have coordinates and you want EUNIS habitat types:**
  [`vignette("EUNIS")`](https://florian-jansen.github.io/resy/articles/EUNIS.md)
  adds the ecoregion, country and coastal position from the coordinates
  and classifies the plots.
- **Your species names follow another taxonomy**, such as GBIF or World
  Flora Online, and
  [`resy_check_taxonomy()`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md)
  reports many unmatched names:
  [`vignette("taxonomy")`](https://florian-jansen.github.io/resy/articles/taxonomy.md)
  matches them to the names of the expert system.
- **Your plots have no altitude:**
  [`vignette("altitude-vignette")`](https://florian-jansen.github.io/resy/articles/altitude-vignette.md)
  takes the altitude that some EUNIS rules use from a separately
  downloaded elevation map.
- **You have your own expert system:**
  [`resy_validate_esy()`](https://florian-jansen.github.io/resy/reference/resy_validate_esy.md)
  checks the file, and
  [`resy_add_classification()`](https://florian-jansen.github.io/resy/reference/resy_add_classification.md)
  makes it available to
  [`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md).

## References

Bruelheide H ([1997](https://doi.org/10.1007/BF02803883)) Using formal
logic to classify vegetation. – *Folia Geobotanica* 32, 41–46.
<https://doi.org/10.1007/BF02803883>

Bruelheide H, Tichý L, Chytrý M, Jansen F
([2021](https://doi.org/10.1111/avsc.12562)) Implementing the formal
language of the vegetation classification expert systems (ESy) in the
statistical computing environment R. – *Applied Vegetation Science* 24,
e12562. <https://doi.org/10.1111/avsc.12562>

Chytrý M, Tichý L, Hennekens SM, Knollová I et
al. ([2020](https://doi.org/10.1111/avsc.12519)) EUNIS Habitat
Classification: expert system, characteristic species combinations and
distribution maps of European habitats. – *Applied Vegetation Science*
23, 648–675. <https://doi.org/10.1111/avsc.12519>
