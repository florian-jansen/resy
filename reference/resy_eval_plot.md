# Evaluate and print details for a single plot

**\[experimental\]** Prints, in plain words, why one plot is classified
as it is: the vegetation types whose rules hold for it with their
priorities, the type it is classified as, and its species. Below that it
lists the lower-level types of the classified type that the plot did not
reach. Each is shown with its rule and with every condition the rule
uses: whether the condition is met, the value the plot has, the value
the condition requires, and the plot's species that count towards it.
This shows, for example, why a plot is `R2` and not `R22`. A plot that
matches no type is shown against the top-level types.

In a rule, `[1]`, `[2]`, ... stand for the numbered conditions listed
under it, combined with `and`, `or` and `not` as the expert system
combines them.

## Usage

``` r
resy_eval_plot(res, p, type = character(), lower = TRUE)
```

## Arguments

- res:

  A `resy_result` returned by
  [`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md).

- p:

  Plot identifier (`PlotObservationID`) as character; if numeric,
  treated as row index in `header`.

- type:

  Optional vegetation-type short code(s) to show in the same way,
  whether or not their rules hold for the plot.

- lower:

  Logical; if `TRUE` (default), list the lower-level types the plot did
  not reach, with their conditions.

## Value

`NULL`, invisibly. Called for the printed output.

## Examples

``` r
species <- read.csv(
  system.file("extdata", "data_example_species.csv", package = "RESY")
)
header <- unique(species["PlotObservationID"])

res <- resy_classify(
  species,
  header,
  scheme = "Apennine-test"
)
#> Step 5.1  Number of conditions with number of species of a group: 0
#> Step 5.2  Number of conditions with minimum number of species: 0
#> Step 5.3  Number of conditions with sum of square rooted Cover_Perc of species: 0
#> Step 5.4  Number of conditions with total Cover_Perc of the group: 0
#> Step 5.5  Number of conditions with total Cover_Perc of all other species: 0
#>           Number of conditions with total Cover_Perc of all other species except those on the left-hand side: 0
#>           Number of conditions with $05, $25 etc.: 0
#> Step 5.6  Number of conditions with maximum cover of the group: 0
#> Step 5.7  Number of conditions with single species, header levels (e.g. country names): 1
#> Step 5.8  Number of conditions with maximum Cover_Perc in plot: 0
#>           Number of conditions with maximum Cover_Perc in plot EXCEPT species of target group: 0
#> Step 5.9  Number of T$ NON conditions: 0
#> Step 5.10  Header conditions with numeric values: 0
#>   Header conditions with character values: 0
#> adapt conditions 2026-11-10 16:45:02.476618
#> classification from here on 2026-11-10 16:45:02.477363

resy_eval_plot(res, p = as.character(header$PlotObservationID[1]))
#> Types whose rule holds: F (priority 2)
#> Classified as F (Forest).
#> 
#> Plot HU32: 10 species
#>  species                  cover
#>  Fagus sylvatica          87.5 
#>  Abies alba                3.0 
#>  Oxalis acetosella         3.0 
#>  Rubus hirtus              3.0 
#>  Anemone nemorosa          0.5 
#>  Epipactis helleborine     0.5 
#>  Prenanthes purpurea       0.5 
#>  Sorbus aucuparia          0.5 
#>  Cephalanthera longifolia  0.1 
#>  Dryopteris filix-mas      0.1 
#> 
#> Why not a lower level of F:
#> 
#> FB    Beech-fir montane forest: rule not met
#>       Rule: [1] and [2]
#>       [1] met      total cover of Beech-forest-trees is 87.9%, needs more than 15%
#>                    Fagus sylvatica 87.5, Abies alba 3
#>       [2] not met  total cover of Beech-forest-herbs is 4.2%, needs more than 10%
#>                    Oxalis acetosella 3, Anemone nemorosa 0.5, Prenanthes purpurea 0.5, Cephalanthera longifolia 0.1, Dryopteris filix-mas 0.1
```
