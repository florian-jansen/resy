# Validate an expert classification text file (format checks)

This function checks common formatting issues in expert text files:
section markers, empty/duplicate formula names, unknown group
classifiers, inconsistent indentation, and tab characters. It does not
validate ecological correctness, only basic syntax/structure expected by
RESY's parser.

## Usage

``` r
resy_validate_expert(path, strict = FALSE, verbose = TRUE)
```

## Arguments

- path:

  Path to a \`.txt\` expert definition.

- strict:

  If \`TRUE\`, treat warnings as errors.

- verbose:

  If \`TRUE\`, prints a short summary.

## Value

A list with \`ok\` (logical), \`errors\` and \`warnings\` (character).
