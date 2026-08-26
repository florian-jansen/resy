# Get the path to a bundled classification file

Returns the full path to an expert-system file bundled with the package.

## Usage

``` r
resy_expert_path(scheme, version, format = c("json", "txt"), mustWork = TRUE)
```

## Arguments

- scheme:

  Classification scheme, e.g. \`"EUNIS"\`.

- version:

  Version identifier, e.g. \`"2025-10-03"\`.

- format:

  One of \`"json"\` (default) or \`"txt"\`.

- mustWork:

  Logical; if \`TRUE\` (default) an error is thrown when the file does
  not exist.

## Value

A file path string, or \`NA\` (invisibly) when \`mustWork = FALSE\` and
the file is absent.

## Examples

``` r
# Path to the bundled EUNIS expert system (JSON by default).
resy_expert_path("EUNIS", "2025-10-03")
#> [1] "/home/runner/.cache/R/renv/library/resy-ae7cf081/linux-ubuntu-noble/R-4.6/x86_64-pc-linux-gnu/RESY/extdata/classifications/EUNIS/2025-10-03/expert.json"

# Probe without erroring when a scheme/version is not installed.
resy_expert_path("EUNIS", "1900-01-01", mustWork = FALSE)
#> [1] NA
```
