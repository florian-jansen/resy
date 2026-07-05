# Parse a structured JSON expert-system file

Reads a structured JSON expert-system definition file into the internal
\`resy_parsed_expert\` format consumed by \[resy_classify()\].

The JSON file must have the following top-level keys:

- \`metadata\`:

  Object with \`scheme\` and \`version\` (both strings). Optional:
  \`description\`, \`source_file\`.

- \`synonyms\`:

  Object mapping each canonical name (key) to an array of accepted
  spelling variants / author-cited synonyms (value). An empty array
  means the canonical name has no known aliases.

- \`groups\`:

  Object mapping each species-group name (key, including its solver
  prefix such as \`"### "\`, \`"##D "\`…) to an array of canonical
  member species.

- \`rules\`:

  Array of objects, each with \`priority\` (character 0–9 or letter),
  \`code\` (string), \`description\` (string), and \`expression\`
  (string using the formula syntax, e.g. \`"\<#TC Beech-forest-trees GR
  15\>"\`). Keys starting with \`\_\` (e.g. \`"\_comment"\`) are
  silently ignored.

## Usage

``` r
resy_parse_json(path)
```

## Arguments

- path:

  Path to a \`.json\` expert-system file.

## Value

A list of class \`resy_parsed_expert\`, identical in structure to the
output of \[resy_load_expert()\].

## See also

\[resy_load_expert()\]
