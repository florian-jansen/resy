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
\`\<root\>/\<scheme\>/\<version\>/\`, where the roots are searched in
the order given by \`location\`: classifications stored with
\[resy_add_classification()\] (\`"user"\`) and the classifications
shipped with the package (\`"package"\`).

## Usage

``` r
resy_load_expert(
  expertfile = NULL,
  scheme = "EUNIS",
  version = NULL,
  location = c("user", "package")
)
```

## Arguments

- expertfile:

  Optional path to a \`.json\` or \`.txt\` file.

- scheme:

  Classification scheme name (default \`"EUNIS"\`).

- version:

  Version identifier. If \`NULL\`, the newest available version is used.

- location:

  Where to look for \`scheme\`/\`version\`, in search order. One or both
  of \`"user"\` and \`"package"\`; the default searches both, user
  first, so a user-stored classification takes precedence over a shipped
  one with the same scheme and version.

## Value

A list of class \`resy_parsed_expert\`.

## See also

\[resy_available_classifications()\], \[resy_add_classification()\]
