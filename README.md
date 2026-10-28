
<!-- README.md is generated from README.Rmd. Please edit that file -->

# RESY

<!-- badges: start -->

[![License:
MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CRAN
status](https://www.r-pkg.org/badges/version/RESY)](https://CRAN.R-project.org/package=RESY)
<!-- badges: end -->

RESY assigns vegetation plots to vegetation or habitat types based on
their plant community. A plot where beech, silver fir and beech-forest
herbs such as wood sorrel grow together is a beech-fir montane forest. A
plot where mat-grass (*Nardus stricta*) is abundant is an acidic
grassland. RESY uses the species composition and cover or abundance
recorded in each vegetation plot (relevé).

The rules for this assignment form an expert system (ESy; Chytrý et al.
[2020](https://doi.org/10.1111/avsc.12519); Bruelheide et al.
[2021](https://doi.org/10.1111/avsc.12562)), stored as a text or JSON
file. For each type, the rule specifies which groups of indicator
species a plot must contain and how much cover they must have. In the
example below, a plot is a beech-fir montane forest when beech and
silver fir together cover more than 15% of it and beech-forest herbs
more than 10%. You can also supply your own expert system.

RESY ships the expert system for EUNIS (European Nature Information
System), the habitat classification of the [European Environment
Agency](https://www.eea.europa.eu/en/datahub/datahubitem-view/123d0c9a-a6fa-4f2d-b887-5d8e5468faed)
for the land and sea of Europe. EUNIS defines a habitat by its plant and
animal communities together with abiotic conditions. Some of its rules
therefore also use site data, such as the ecoregion, the country or the
position on the coast.

The EUNIS expert system uses the species names of [Euro+Med
PlantBase](https://europlusmed.org/), the taxonomy used in data from the
[European Vegetation Archive (EVA)](https://euroveg.org/eva-database/).
Species names in plot data that follow another taxonomy, such as
[GBIF](https://www.gbif.org/) or [World Flora
Online](https://www.worldfloraonline.org/), must first be matched to
Euro+Med names. Use `resy_resolve_taxa()` to match them
(`vignette("taxonomy")`).

**Insert figure here. Perhaps of Europe**

## :arrow_double_down: Installation

The package is available on CRAN. Install and load it with:

``` r
install.packages("RESY")
library("RESY")
```

RESY is still under active development. You can install the development
version from the GitHub repository using the following commands:

``` r
# install.packages("remotes")
remotes::install_github(
   "https://github.com/florian-jansen/resy",
   dependencies = TRUE
   )
library(RESY)
```

## :rocket: Usage

To classify plots, `resy_classify()` needs two tables:

- A **species table**, with one row per species in each plot, giving the
  plot ID, species name and cover.
- A **header table**, with one row per plot, giving the plot ID and any
  site data used by the classification rules.

This example uses the bundled plots from Tuscany and `Apennine-test`, a
small expert system whose rules require no site data. The header table
therefore contains only plot IDs, but `resy_classify()` still requires
it.

``` r
library(RESY)

file <- system.file("extdata", "data_example_species.csv", package = "RESY")
species <- read.csv(file)
header <- unique(species["PlotObservationID"])

res <- resy_classify(species, header, scheme = "Apennine-test")
cand <- resy_candidates(res, top_n = 3, wide = TRUE)
table(cand$classification)
#> 
#>  ?  F FB  N NG NS 
#> 92 33  8  6 20 41
```

`F`, `FB`, `N`, `NG` and `NS` are the five vegetation types of
`Apennine-test`. A plot marked `?` meets no type’s rule and is not
classified. Here, 92 of the 200 plots remain unclassified. In these
plots, all four indicator groups have at most 4% cover, below the lowest
threshold in the rules (5%).

Each type has a priority in the expert system. When a plot meets the
rules of several types, it is assigned to the one with the highest
priority. Each row of `cand` is one plot: the type it is assigned to,
then the types whose rules it meets, highest priority first. Plot `CX45`
meets the rules of `FB` (beech-fir montane forest, priority 5) and of
its parent type `F` (forest, priority 2), and is assigned to `FB`:

``` r
cand[cand$plot_id == "CX45", ]
#>    plot_id classification type_1 priority_1 type_2 priority_2
#>     <char>         <char> <char>      <ord> <char>      <ord>
#> 1:    CX45             FB     FB          5      F          2
```

`resy_eval_plot(res, p = "CX45")` shows the species and conditions
behind this assignment. For EUNIS, the header table also needs site data
such as the ecoregion and the country, which `resy_harmonize_eunis()`
adds from the plot coordinates.

Column names can follow [Darwin Core](https://dwc.tdwg.org/), a standard
set of field names for biodiversity data. The example data stores
species names in `scientificName`. RESY looks for the species in
`TaxonName` or `scientificName` (any other column is set with
`species_col`), the plot ID in `eventID`, the cover in
`organismQuantity` with an `organismQuantityType` of `"% cover"`, and
the site data in `decimalLongitude`, `decimalLatitude`, `country`,
`minimumElevationInMeters` and `maximumElevationInMeters`.

## :scroll: Vignettes

We have written several vignettes to help you use the RESY R package:
<br>

- `vignette("RESY")`: start here, from a species table to classified
  plots
- `vignette("EUNIS")`: EUNIS habitat types for plots with coordinates
- `vignette("altitude-vignette")`: the altitude column some EUNIS rules
  use
- `vignette("taxonomy")`: matching the species names in your data to the
  names the expert system uses

## :desktop_computer: Functions

These are the main functions:

- `resy_harmonize_eunis()` adds the site data EUNIS needs (ecoregion,
  country, coast, dunes) from the plot coordinates.
- `resy_check_taxonomy()` checks which species names the expert system
  knows; `resy_resolve_taxa()` matches names from other taxonomies to
  them.
- `resy_classify()` assigns each plot to a vegetation or habitat type.
- `resy_candidates()` lists the assigned and candidate types per plot.
- `resy_eval_plot()` explains the assignment of one plot.
- `resy_validate_esy()` checks your own expert system, and
  `resy_add_classification()` makes it available to `resy_classify()`.

An overview of all functions and data is given in the tab
[**Reference**](https://florian-jansen.github.io/resy/reference/).

## :books: Papers and links

- Bruelheide et al. ([2021](https://doi.org/10.1111/avsc.12562)): the
  expert-system language that RESY implements.
- Chytrý et al. ([2020](https://doi.org/10.1111/avsc.12519)): the EUNIS
  expert system, its species groups and the habitat distribution maps.
- [EUNIS-ESy on Zenodo](https://zenodo.org/records/16895007): the
  released versions of the EUNIS expert system.
- [FloraVeg.EU](https://floraveg.eu/habitat/): descriptions of every
  EUNIS habitat type.

## :memo: How to cite

To cite RESY in publications, please cite the package together with
Bruelheide et al. (2021), which describes the expert-system language
RESY implements, and, when you use the EUNIS expert system, Chytrý et
al. (2020).

``` text
Jansen F, Bauer M, Calbi M, Colling G (2026). _RESY: Vegetation Type
Expert Classification System_. R package version 0.3,
<https://florian-jansen.github.io/resy/>.

Bruelheide H, Tichý L, Chytrý M, Jansen F (2021). "Implementing the
formal language of the vegetation classification expert systems (ESy)
in the statistical computing environment R." _Applied Vegetation
Science_, *24*, e12562. doi:10.1111/avsc.12562
<https://doi.org/10.1111/avsc.12562>.

Chytrý M, Tichý L, Hennekens S, Knollová I, others (2020). "EUNIS
Habitat Classification: expert system, characteristic species
combinations and distribution maps of European habitats." _Applied
Vegetation Science_, *23*, 648-675. doi:10.1111/avsc.12519
<https://doi.org/10.1111/avsc.12519>.
```

BibTeX:

``` bibtex
@Manual{jansen2026resy,
  title = {{RESY}: Vegetation Type Expert Classification System},
  author = {Florian Jansen and Markus Bauer and Mariasole Calbi and Gilles Colling},
  year = {2026},
  note = {R package version 0.3},
  url = {https://florian-jansen.github.io/resy/},
}

@Article{bruelheide2021esy,
  title = {Implementing the formal language of the vegetation classification expert systems ({ESy}) in the statistical computing environment {R}},
  author = {Helge Bruelheide and Lubomír Tichý and Milan Chytrý and Florian Jansen},
  journal = {Applied Vegetation Science},
  year = {2021},
  volume = {24},
  pages = {e12562},
  doi = {10.1111/avsc.12562},
}

@Article{chytry2020eunis,
  title = {{EUNIS} Habitat Classification: expert system, characteristic species combinations and distribution maps of {European} habitats},
  author = {Milan Chytrý and Lubomír Tichý and Stephan M. Hennekens and Ilona Knollová and others},
  journal = {Applied Vegetation Science},
  year = {2020},
  volume = {23},
  pages = {648--675},
  doi = {10.1111/avsc.12519},
}
```

## :bug: Find a bug?

Thank you for finding it. Head over to the [GitHub
Issues](https://github.com/florian-jansen/resy/issues) tab and let us
know about it. Alternatively, you can also [send us an
email](mailto:florian.jansen@uni-rostock.de). We will try to get to it
as soon as possible!
