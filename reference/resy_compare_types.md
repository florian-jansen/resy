# Compare two vegetation types

**\[experimental\]** Sets two vegetation types side by side: type `a` of
expert system `x` and type `b` of expert system `y`. The two can be
types of one system, for example `R11` and `R22` of EUNIS-ESy, or the
same type in two releases, for example `R22` in EUNIS-ESy 2020-06-08 and
2025-10-03. Their rules are written with one numbering of conditions, so
a condition both rules use has the same number in both, and their
species groups are compared member by member.

With `plot`, the comparison is made for one classified plot: for each
condition whether the plot meets it in each type, the value the plot
has, and why the plot is or is not classified as each type (a rule that
does not hold, or a rule that holds but has a lower priority than the
type chosen).

## Usage

``` r
resy_compare_types(x, a, b, y = x, plot = NULL, scheme = "EUNIS")
```

## Arguments

- x:

  Expert system of type `a`: a `resy_result` from
  [`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md),
  a `resy_parsed_expert` from
  [`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md),
  the path of an expert file, or a version of `scheme` (see
  [`resy_available_classifications()`](https://florian-jansen.github.io/resy/reference/resy_available_classifications.md)).
  Must be a `resy_result` when `plot` is given.

- a, b:

  Short codes of the two types, for example `"R11"` and `"R22"`.

- y:

  Expert system of type `b`, given as `x`; by default `x`.

- plot:

  Optional plot identifier (`PlotObservationID`) present in the results
  `x` and `y`.

- scheme:

  Scheme of `x` and `y` when they are given as versions.

## Value

A list of class `resy_type_comparison` with

- `sides`:

  One row per type: `side` (`"a"`, `"b"`), `system`, `code`, `name`, and
  the number of `rules` that define it.

- `rules`:

  One row per rule: `side`, `code`, `rule` (its number among the type's
  rules), `priority` and `text`, the rule with conditions numbered as in
  `conditions`; with `plot`, `holds` and `judged` (the rule the plot is
  judged by).

- `conditions`:

  One row per condition used by either type: its number `n`, the
  `expression` as written in the expert system, and `in_a`, `in_b`. With
  `plot` also `met_a`, `met_b` (`NA` where the type does not use the
  condition) and `text`, the condition in words with the plot's value.

- `groups`:

  One row per species group named by either type: `group`, `in_a`,
  `in_b`, the number of members `n_a`, `n_b`, and for a group both name,
  the members `only_a` and `only_b` has.

- `plot`:

  `NULL`, or for the plot its `id` and per side (`a`, `b`) the type it
  is classified as (`choice`), whether a rule of the type holds, its
  priority and the reason in words (`text`).

## See also

[`resy_eval_plot()`](https://florian-jansen.github.io/resy/reference/resy_eval_plot.md),
which lists the siblings and lower levels of the type a plot is
classified as;
[`resy_diff_expert()`](https://florian-jansen.github.io/resy/reference/resy_diff_expert.md)
for all changes between two expert systems.

## Examples

``` r
species <- read.csv(
  system.file("extdata", "data_example_species.csv", package = "RESY")
)
header <- unique(species["PlotObservationID"])
res <- resy_classify(species, header, scheme = "Apennine-test")
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
#> adapt conditions 2026-11-24 17:29:11.82694
#> classification from here on 2026-11-24 17:29:11.827554

resy_compare_types(res, "NG", "NS")
#> A  NG Nardus acidic grassland
#>    Rule (priority 5): [1] and [2]
#> B  NS Sub-Mediterranean scrub and woodland
#>    Rule (priority 3): [3]
#> Expert system: Apennine-test 2026-06-27 (expert.json)
#> 
#> Conditions:
#>         NG       NS       
#>   [1]   used              Nardus stricta GR 10
#>   [2]   used              #TC Nardus-grassland GR 25
#>   [3]            used     #TC Sub-Mediterranean GR 15
#> 
#> Species groups:
#>   only NG: Nardus-grassland
#>   only NS: Sub-Mediterranean
resy_compare_types(res, "NG", "NS", plot = as.character(header$PlotObservationID[1]))
#> A  NG Nardus acidic grassland
#>    Rule (priority 5): [1] and [2]
#> B  NS Sub-Mediterranean scrub and woodland
#>    Rule (priority 3): [3]
#> Expert system: Apennine-test 2026-06-27 (expert.json)
#> 
#> Conditions for plot HU32:
#>         NG       NS       
#>   [1]   not met           cover of Nardus stricta is 0%, needs more than 10%
#>   [2]   not met           total cover of Nardus-grassland is 0%, needs more than 25%
#>   [3]            not met  total cover of Sub-Mediterranean is 0%, needs more than 15%
#> 
#> Species groups:
#>   only NG: Nardus-grassland
#>   only NS: Sub-Mediterranean
#> 
#> Plot HU32:
#>   NG: rule not met: 0 of 2 conditions satisfied
#>   NS: rule not met: 0 of 1 conditions satisfied
# \donttest{
resy_compare_types("2020-06-08", "R22", "R22", y = "2025-10-03")
#> A  R22 Low and medium altitude hay meadow (EUNIS 2020-06-08 (expert.txt.xz))
#>    Rule (priority 2): (([1] and [2]) and ([3] and [4])) and not ([5] or [6])
#> B  R22 Low and medium altitude hay meadow (EUNIS 2025-10-03 (expert.txt.xz))
#>    Rule (priority 2): (([1] and [2]) and ([3] and [4])) and not ([5] or [6])
#> 
#> Conditions:
#>         R22      R22      
#>   [1]   used     used     ##Q +04 R22-Low-and-medium-altitude-hay-meadow GR NON ##Q +04 R22-Low-and-medium-altitude-hay-meadow
#>   [2]   used     used     #TC +04 R22-Low-and-medium-altitude-hay-meadow GR $50
#>   [3]   used     used     #03 +04 R22-Low-and-medium-altitude-hay-meadow
#>   [4]   used     used     ### +04 R22-Low-and-medium-altitude-hay-meadow GR ### +04 R1A-Semi-dry-perennial-calcareous-grassland
#>   [5]   used     used     #TC +04 R1M-Lowland-to-submontane-dry-to-mesic-grassland-usually-Nardus GR 25
#>   [6]   used     used     #TC Trees|#TC Shrubs GR 15
#> 
#> Species groups:
#>   in both: +04 R22-Low-and-medium-altitude-hay-meadow, +04
#>     R1A-Semi-dry-perennial-calcareous-grassland, +04
#>     R1M-Lowland-to-submontane-dry-to-mesic-grassland-usually-Nardus,
#>     Trees, Shrubs
#>   +04 R22-Low-and-medium-altitude-hay-meadow differs: only in A:
#>     Centaurea jacea; only in B: Centaurea jacea aggr.
#>   +04 R1A-Semi-dry-perennial-calcareous-grassland differs: only in A:
#>     Euphrasia nemorosa, Ophrys holosericea, Scorzonera villosa; only in
#>     B: Euphrasia nemorosa aggr., Gelasia villosa, Ophrys holoserica
#>   Trees differs: only in A: Abies concolor, Abies grandis, Abies
#>     procera, Fraxinus pallisae, Populus nigra 'Italica', Quercus
#>     canariensis + petraea, Quercus coccinea, Quercus humilis +
#>     cerrioides, Salix blanda, Sorbus pannonica; only in B: Abies
#>     balsamea, Abies lasiocarpa, Abies lowiana, Abies marocana, Fraxinus
#>     pallisiae, Pinus ponderosa, Quercus afares, Quercus castaneifolia,
#>     Quercus elliptica, Quercus lancifolia, Quercus lusitanica, Quercus
#>     sicula, Quercus x benkoei, Quercus x cazanensis
#>   Shrubs differs: only in A: Colutea arborescens, Colutea hispanica,
#>     Cotoneaster melanocarpus, Crataegus mollis aggr., Crataegus mon. et
#>     ox., Crataegus x subsphaerica, Jasminum fruticans, Jasminum
#>     odoratissimum, Rhamnus pallasii, Rosa caesia aggr., Rosa foetida,
#>     Rosa vosagiaca aggr., Salix arbuscula aggr., Ulex airensis; only in
#>     B: Chrysojasminum fruticans, Chrysojasminum odoratissimum, Colutea
#>     arborescens aggr., Cotoneaster laxiflorus, Crataegus mollis,
#>     Crataegus x kyrtostyla, Rhamnus erythroxyloides, Ulex parviflorus
# }
```
