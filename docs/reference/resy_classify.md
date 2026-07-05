# Classify vegetation plots with the expert system

Convenience wrapper that loads an expert system (by file or by
scheme/version), aggregates taxa, evaluates membership
conditions/expressions, and returns plot classifications.

## Usage

``` r
resy_classify(
  obs,
  header,
  expertfile = NULL,
  scheme = "EUNIS",
  version = NULL,
  location = c("user", "package"),
  id_col = NULL,
  mc = max(1L, floor(parallel::detectCores() * 0.75))
)
```

## Arguments

- obs:

  Observations as \`data.table\` with at least columns describing plot
  id, \`TaxonName\`, and \`Cover_Perc\`.

- header:

  Plot header data.frame; required for evaluating \$\$C/\$\$N.

- expertfile:

  Optional path to expert-system file (.rds/.json/.txt). If set, takes
  precedence.

- scheme:

  Scheme name (default: "EUNIS").

- version:

  Version identifier. If NULL, uses latest available version for the
  scheme.

- location:

  Where to look for scheme/version "user" or"package".

- id_col:

  Optional name of the plot id column. If NULL, tries PlotObservationID,
  RELEVE_NR, then PlotID.

- mc:

  Number of CPU cores to use.

## Value

An object of class \`resy_result\`.
