# Load a classification

Loads a parsed expert-system object ready for use with
\[resy_classify()\].

If \`expertfile\` is given it takes precedence over
\`scheme\`/\`version\`. The file format is detected from the extension:

- \`.json\`:

  Parsed directly via the internal JSON parser (preferred).

- \`.txt\`:

  Parsed via the legacy text parser.

When no \`expertfile\` is supplied, the function looks for
\`expert.json\`, then \`expert.txt\` (in that order) under
\`inst/extdata/classifications/\<scheme\>/\<version\>/\` in the
installed package.

## Usage

``` r
resy_load_expert(expertfile = NULL, scheme = "EUNIS", version = NULL)
```

## Arguments

- expertfile:

  Optional path to a \`.json\` or \`.txt\` file.

- scheme:

  Classification scheme name (default \`"EUNIS"\`).

- version:

  Version identifier. If \`NULL\`, the newest available version is used.

## Value

A list of class \`resy_parsed_expert\`.

## See also

\[resy_available_classifications()\]
