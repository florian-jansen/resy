# Remove taxonomic authorities from scientific names

Strips author citations from scientific plant names while keeping the
taxonomic structure that expert-system names depend on, so that names
from different taxonomic backbones resolve against the canonical names
and synonyms of an expert system. The genus and species epithet are
always kept. Infraspecific rank markers (`subsp.`, `var.`, `f.`, ...)
are kept together with their epithet. Aggregate and collective markers
(`agg.`, `aggr.`, `coll.`, `s.l.`, `s.str.`, `s.lat.`) stand alone and
are kept in place, including when they trail a name with no following
epithet (`"Taraxacum officinale agg."`) or follow an infraspecific
epithet (`"Aconitum napellus subsp. firmum s.l."`). A `sensu ...`
concept qualifier and everything after it is dropped, to match the bare
aggregate form the expert system uses as its canonical name. The hybrid
sign (ASCII `x` or the multiplication sign) is kept, both for a
nothospecies (`"Salix x rubens"`) and for a hybrid formula joining two
taxa (`"Betula pendula x pubescens"`,
`"Elytrigia repens x Leymus arenarius"`), so a hybrid is never collapsed
onto one of its parents. Names with fewer than two words are returned
unchanged.

## Usage

``` r
resy_clean_names(x)
```

## Arguments

- x:

  A character vector of scientific names, optionally carrying author
  citations (for example `"Fagus sylvatica L."`).

## Value

A character vector the same length as `x` with author citations removed
and taxonomic structure preserved. `NA` values are preserved.

## Examples

``` r
resy_clean_names(c(
  "Fagus sylvatica L.",
  "Epipactis helleborine (L.) Crantz subsp. helleborine",
  "Senecio ovatus (G.Gaertn., B.Mey. & Scherb.) Willd.",
  "Taraxacum officinale agg.",
  "Festuca ovina s. l.",
  "Alchemilla vulgaris aggr. sensu Buser",
  "Mentha x verticillata aggr."
))
#> [1] "Fagus sylvatica"                         
#> [2] "Epipactis helleborine subsp. helleborine"
#> [3] "Senecio ovatus"                          
#> [4] "Taraxacum officinale agg."               
#> [5] "Festuca ovina s.l."                      
#> [6] "Alchemilla vulgaris aggr."               
#> [7] "Mentha x verticillata aggr."             
```
