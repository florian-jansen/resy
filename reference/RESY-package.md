# RESY: rule-based expert classification of vegetation plots

RESY assigns vegetation plots to vegetation or habitat types with
formalised expert systems: rule sets that combine indicator species
groups, species covers and plot header data (for example ecoregion,
country or coast) into membership formulas. The EUNIS-ESy expert system
for European EUNIS habitat types (Chytrý et al. 2020) ships with the
package, and any other system in the ESy \`.txt\` or \`.json\` format
can be added.

## Workflow

1.  Pick an expert system: \[resy_available_classifications()\] lists
    the shipped ones, \[resy_add_classification()\] stores your own, and
    \[resy_load_expert()\] loads one.

2.  Prepare the plot data: \[resy_check_taxonomy()\] checks species
    names against the expert system, \[resy_resolve_taxa()\] harmonises
    names from other taxonomic backbones, and \[resy_harmonize_eunis()\]
    adds the header columns EUNIS-ESy needs.

3.  Classify with \[resy_classify()\].

4.  Inspect the result: \[resy_candidates()\] lists the candidate types
    per plot, \[resy_eval_plot()\] and \[resy_eval_type()\] show why a
    plot or type matched, and \[resy_expert_tree()\] shows the type
    hierarchy.

## References

Chytrý M, Tichý L, Hennekens SM et al. (2020) EUNIS Habitat
Classification: expert system, characteristic species combinations and
distribution maps of European habitats. \*Applied Vegetation Science\*
23, 648-675.
[doi:10.1111/avsc.12519](https://doi.org/10.1111/avsc.12519)

## See also

Useful links:

- <https://florian-jansen.github.io/resy/>

## Author

**Maintainer**: Florian Jansen <florian.jansen@uni-rostock.de>
([ORCID](https://orcid.org/0000-0002-0331-5185))

Authors:

- Florian Jansen <florian.jansen@uni-rostock.de>
  ([ORCID](https://orcid.org/0000-0002-0331-5185))

- Markus Bauer <markus1.bauer@tum.de>
  ([ORCID](https://orcid.org/0000-0001-5372-4174))

- Mariasole Calbi <mariasolecalby@gmail.com>
  ([ORCID](https://orcid.org/0000-0001-6018-4022))

- Gilles Colling <gilles.colling051@gmail.com>
  ([ORCID](https://orcid.org/0000-0003-3070-6066))

## Examples

``` r
resy_available_classifications()[, c("scheme", "version")]
#>          scheme    version
#> 1 Apennine-test 2026-06-27
#> 2         EUNIS 2025-10-03

parsed <- resy_load_expert(scheme = "Apennine-test")
parsed$vegtype.formula.names
#> [1] "F     Forest"                              
#> [2] "FB    Beech-fir montane forest"            
#> [3] "N     Non-forest"                          
#> [4] "NG    Nardus acidic grassland"             
#> [5] "NS    Sub-Mediterranean scrub and woodland"
```
