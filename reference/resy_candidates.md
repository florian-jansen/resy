# List possible assignments per plot

**\[experimental\]** The result object returned by
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
contains a long table of all vegetation types that were evaluated as
possible for each plot (i.e. the corresponding vegtype formula evaluated
to `TRUE`).

This helper lets you access, sort, and filter those candidates.

## Usage

``` r
resy_candidates(
  res,
  plot_id = NULL,
  priority = NULL,
  min_priority = NULL,
  top_n = NULL,
  wide = FALSE
)
```

## Arguments

- res:

  A `resy_result` returned by
  [`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md).

- plot_id:

  Optional plot id (character or numeric). If `NULL`, returns candidates
  for all plots.

- priority:

  Optional priority *rank* (integer). If provided, only candidates with
  `priority_rank == priority` are returned.

- min_priority:

  Optional minimum priority *rank* (integer). Higher means higher
  priority. If provided, only candidates with
  `priority_rank >= min_priority` are returned.

- top_n:

  Optional maximum number of candidates to return per plot, the highest
  priorities first.

- wide:

  Logical. If `TRUE`, returns one row per plot with its classification
  and its candidate types side by side, highest priority first.

## Value

A `tibble` with columns `plot_id`, `type`, `priority`, `priority_rank`.
With `wide = TRUE`, a `data.table` with one row per plot and columns
`plot_id`, `classification`, then `type_1`, `priority_1`, `type_2`,
`priority_2`, ...; a plot with fewer candidates has `NA` in the
remaining columns.

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
#> adapt conditions 2026-11-13 11:53:30.661838
#> classification from here on 2026-11-13 11:53:30.662483

resy_candidates(res, top_n = 3)
#>      plot_id   type priority priority_rank
#>       <char> <char>    <ord>         <int>
#>   1:    AM30      F        2             1
#>   2:    AN57      F        2             1
#>   3:    BE71     FB        5             3
#>   4:    BE71      F        2             1
#>   5:    BK34     NS        3             2
#>  ---                                      
#> 173:    ZS46     NS        3             2
#> 174:    ZS46      N        2             1
#> 175:    ZX20      F        2             1
#> 176:    ZX92     FB        5             3
#> 177:    ZX92      F        2             1
```
