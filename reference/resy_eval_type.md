# Evaluate and print details for a vegetation type

Prints the definition of one vegetation type of the expert system used
in a classification: its full name, its membership formula as written in
the expert file, the compiled formula over membership-condition columns,
and a table of the membership conditions it refers to.

## Usage

``` r
resy_eval_type(res, t)
```

## Arguments

- res:

  A \`resy_result\` returned by \[resy_classify()\].

- t:

  Vegetation-type short code (e.g. "R55") or numeric index.

## Value

\`NULL\`, invisibly. Called for the printed output; prints "Type not
defined." when \`t\` is not a type code of the expert system.

## See also

\[resy_eval_plot()\], \[resy_classify()\]

## Examples

``` r
# \donttest{
species <- utils::read.csv(
  system.file("extdata", "data_example_species.csv", package = "RESY")
)
names(species)[names(species) == "species"] <- "TaxonName"
names(species)[names(species) == "cover"]   <- "Cover_Perc"
header <- as.data.frame(unique(species["PlotObservationID"]))

res <- resy_classify(species, header, scheme = "Apennine-test", mc = 1L)
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
#> adapt conditions 2026-09-21 14:22:35.310073
#> classification from here on 2026-09-21 14:22:35.310706

# By short code or by position in the expert system
resy_eval_type(res, "FB")
#> FB    Beech-fir montane forest
#> 
#> (<#TC Beech-forest-trees GR 15> AND <#TC Beech-forest-herbs GR 10>)
#> 
#> (col2 & col3)
#> 
#>   expressions                 
#> 2 #TC Beech-forest-trees GR 15
#> 3 #TC Beech-forest-herbs GR 10
resy_eval_type(res, 1)
#> F     Forest
#> 
#> <#TC Beech-forest-trees GR 10>
#> 
#> col1
#> 
#>   expressions                 
#> 1 #TC Beech-forest-trees GR 10
# }
```
