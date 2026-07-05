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
