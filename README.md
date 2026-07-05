
<!-- README.md is generated from README.Rmd. Please edit that file -->

# RESY

<!-- badges: start -->

[![License:
MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CRAN
status](https://www.r-pkg.org/badges/version/RESY)](https://CRAN.R-project.org/package=RESY)
<!-- badges: end -->

The goal of RESY is to use so-called expert files to assign vegetation plots to types. 
The function `resy_classify()` is the core function to classify vegetation plots, which, 
depending on the rules need to include also site data.

**Insert figure here. Perhaps of Europe**

## :arrow_double_down: Installation

The package is available on CRAN, you can install and load it using the
following commands:

``` r
install.packages("RESY")
library("RESY")
```

RESY is still under active development. You can install the development
version from the GitHub repository using the following commands:

``` r
# install.packages("devtools")
remotes::install_github(
   "https://gitlab.uni-rostock.de/loe/publications/r-esy",
   dependencies = TRUE
   )
library(RESY)
```

## :scroll: Vignettes

We have written several vignettes to help you use the RESY R package:
<br>

- `vignette("EUNIS")`
- `vignette("Get altitude data")`

## :desktop_computer: Functions

An overview of all functions and data is given in the tab **Reference**.

## :bug: Find a bug?

Thank you for finding it. Head over to the GitHub Issues tab and let us
know about it. Alternatively, you can also send us an email. We will try
to get to it as soon as possible!

