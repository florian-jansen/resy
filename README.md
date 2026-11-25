
<!-- README.md is generated from README.Rmd. Please edit that file -->

# RESY

<!-- badges: start -->

[![License:
MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**RESY assigns vegetation plots to vegetation or habitat types based on
their plant community.** A plot where beech, silver fir and beech-forest
herbs such as wood sorrel grow together is a beech-fir montane forest. A
plot where mat-grass (*Nardus stricta*) is abundant is an acidic
grassland. RESY uses the species composition and cover or abundance
recorded in each vegetation plot (relevé).

The **rules** for this assignment **form an expert system** (ESy; Chytrý
et al. ([2020](https://doi.org/10.1111/avsc.12519)), stored as a text or
JSON file. For each type, the rule specifies which groups of indicator
species a plot must contain and how much cover they must have. In the
example below, a plot is a beech-fir montane forest when beech and
silver fir together cover more than 15% of it and beech-forest herbs
more than 10%. You can also supply your own expert system.

RESY ships the expert system of Chytrý et
al. ([2020](https://doi.org/10.1111/avsc.12519)) for EUNIS (European
Nature Information System), the habitat classification of the European
Environment Agency for the land and sea of Europe ([EUNIS
habitats](https://www.eea.europa.eu/en/datahub/datahubitem-view/123d0c9a-a6fa-4f2d-b887-5d8e5468faed)).
EUNIS defines a habitat by its plant and animal communities together
with abiotic conditions. Some of its rules therefore also use site data,
such as the ecoregion, the country or the position on the coast. With
`resy_harmonize_eunis()` you can get such [additional
information](https://florian-jansen.github.io/resy/articles/EUNIS.html).
Afterwards you can [apply an expert
system](https://florian-jansen.github.io/resy/articles/RESY.html) with
`resy_classify()` to your vegetation relevés.

Each expert system declares the taxonomic backbone its species names
refer to. The EUNIS expert system uses
[EuroSL](https://eurosl.infinitenature.org), the European species list
built on [Euro+Med PlantBase](https://europlusmed.org/). RESY matches
the species names of your plots to the taxon concepts of the backbone
with the [vegdata](https://cran.r-project.org/package=vegdata) package,
accepting synonyms, author citations and spelling variants but keeping
taxa of different extent apart. A plot taxon counts for an expert taxon
when the backbone places it at or below that taxon, for example a
subspecies for its species. `resy_check_taxonomy()` lists the names that
cannot be used, split into potentially important and probably
unimportant ones; see [Match species
names](https://florian-jansen.github.io/resy/articles/taxonomy.html).

The [RESY App](https://florian-jansen.github.io/resy/articles/app.html)
runs RESY in your browser, without installing R. It classifies the
example plots or your own files with EUNIS-ESy or your own expert
system, and shows the rules behind each assignment.

## :arrow_double_down: Installation

The package is available on CRAN. Install and load it with:

``` r
install.packages("RESY")
library(RESY)
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

RESY matches the species names to the taxonomic backbone of the expert
system, EuroSL, with the vegdata package. Install EuroSL once with
`vegdata::taxref_download_eurosl()`; this example uses the part of
EuroSL that ships with RESY.

``` r
library(RESY)
options(resy.backbone = system.file("extdata", "eurosl_example.csv.xz",
                                    package = "RESY"))

file <- system.file("extdata", "data_example_species.csv", package = "RESY")
species <- read.csv(file)
header <- unique(species["PlotObservationID"])

res <- resy_classify(species, header, scheme = "Apennine-test")
cand <- resy_candidates(res, top_n = 3, wide = TRUE)
table(cand$classification)
#> 
#>  F FB FC FF FQ FR  N NA NB ND NG NH NS NT WA WM WS 
#>  1  8  5 33 16  3 20 11 19  4 20 13 24  9  4  8  2
```

`Apennine-test` has three broad types, forest (`F`), non-forest (`N`)
and wetland (`W`), with sixteen types below them, for example beech-fir
forest (`FB`), chestnut forest (`FC`), dry grassland (`NB`) or open
water (`WA`). A plot that meets the rule of no type would be marked `?`;
in the example data every plot gets a type.

Each type has a priority in the expert system. When a plot meets the
rules of several types, it is assigned to the one with the highest
priority. Each row of `cand` is one plot: the type it is assigned to,
then the types whose rules it meets, highest priority first. Plot `CX45`
meets the rules of `FB` (beech-fir montane forest, priority 5) and of
its parent type `F` (forest, priority 2), and is assigned to `FB`:

``` r
subset(cand, plot_id == "CX45")
#>    plot_id classification type_1 priority_1 type_2 priority_2 type_3 priority_3
#>     <char>         <char> <char>      <ord> <char>      <ord> <char>      <ord>
#> 1:    CX45             FB     FB          5     FF          4      F          2
```

`resy_eval_plot(res, p = "CX45")` shows the species and conditions
behind this assignment. For EUNIS, the header table also needs site data
such as the ecoregion and the country, which `resy_harmonize_eunis()`
adds from the plot coordinates.

RESY accepts these column names, or names standardized to [Darwin
Core](https://dwc.tdwg.org/), a standard set of field names for
biodiversity data. The example data stores species names in
`scientificName`.

| Column | Also accepted |
|----|----|
| `PlotObservationID` | `PlotID`, `eventID` |
| `TaxonName` | `scientificName`, or any column set with `species_col` |
| `Cover_Perc` | `organismQuantity`, with an `organismQuantityType` of `"% cover"` |
| `Longitude` | `decimalLongitude` |
| `Latitude` | `decimalLatitude` |
| `Country` | `country` |
| `Altitude (m)` | `Altitude`, or `minimumElevationInMeters` and `maximumElevationInMeters` (their midpoint) |

## :scroll: Vignettes

These vignettes show how to use RESY:

- [Classifying vegetation plots with
  RESY](https://florian-jansen.github.io/resy/articles/RESY.html): start
  here to get from a species table to classified plots
- [Get EUNIS habitat
  types](https://florian-jansen.github.io/resy/articles/EUNIS.html): get
  additional information to classify EUNIS habitat types to plots with
  coordinates
- [Get altitude
  data](https://florian-jansen.github.io/resy/articles/altitude-vignette.html):
  get the altitude column which some EUNIS rules use
- [Match species
  names](https://florian-jansen.github.io/resy/articles/taxonomy.html):
  matching the species names in your data to the taxonomic backbone of
  the expert system

## :desktop_computer: Functions

These are the main functions:

- `resy_classify()` assigns each plot to a vegetation or habitat type
- `resy_candidates()` lists the assigned and candidate types per plot
- `resy_harmonize_eunis()` adds the site data EUNIS needs (ecoregion,
  country, coast, dunes) from the plot coordinates
- `resy_check_taxonomy()` matches the species names to the taxonomic
  backbone of the expert system and reports those that cannot be used

An overview of all functions and data is given in the tab
[**Reference**](https://florian-jansen.github.io/resy/reference/).

## :books: Papers and Links

- Chytrý et al. ([2025](https://doi.org/10.5281/zenodo.16895007)): the
  released EUNIS expert system versions on Zenodo (first release 2020)
- Chytrý et al. ([2024](https://doi.org/10.1111/avsc.12798)): the
  platform [FloraVeg.EU](https://floraveg.eu/habitat/) has the
  descriptions of every EUNIS habitat type
- Bruelheide et al. ([2021](https://doi.org/10.1111/avsc.12562)):
  translates the expert system of Chytrý et al. (2020) into R
- Chytrý et al. ([2020](https://doi.org/10.1111/avsc.12519)): the expert
  system (ESy) uses vegetation surveys and site data to derive EUNIS
  habitat types.

## :memo: How to cite

To cite RESY in publications, please cite the package together with
Bruelheide et al. (2021), which describes the expert-system language
RESY implements, and, when you use the EUNIS expert system, Chytrý et
al. (2020).

- Jansen F, Bauer M, Calbi M, Colling G (2026). *RESY: Vegetation Type
  Expert Classification System*. R package version 0.3,
  <https://florian-jansen.github.io/resy/>.
- Bruelheide H, Tichý L, Chytrý M, Jansen F (2021). “Implementing the
  formal language of the vegetation classification expert systems (ESy)
  in the statistical computing environment R.” *Applied Vegetation
  Science*, **24**, e12562.
  [doi:10.1111/avsc.12562](https://doi.org/10.1111/avsc.12562).
- Chytrý M, Tichý L, Hennekens S, Knollová I, et al. (2020). “EUNIS
  Habitat Classification: expert system, characteristic species
  combinations and distribution maps of European habitats.” *Applied
  Vegetation Science*, **23**, 648-675.
  [doi:10.1111/avsc.12519](https://doi.org/10.1111/avsc.12519).

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
