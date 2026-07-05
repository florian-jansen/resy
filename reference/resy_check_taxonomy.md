# Check species names against an expert system's species list

Validates taxon names in a plot observation table against the canonical
names and synonyms declared in Section 1 of the loaded expert system.
Returns a per-taxon summary of matches and canonical name mappings.

This is a purely offline check; no external name-resolution service is
called.

## Usage

``` r
resy_check_taxonomy(obs, parsed, col = "TaxonName")
```

## Arguments

- obs:

  A data frame or \`data.table\` with a column holding taxon names.

- parsed:

  A \`resy_parsed_expert\` object from \[resy_load_expert()\].

- col:

  Name of the column in \`obs\` that holds taxon names (default
  \`"TaxonName"\`).

## Value

A data frame with one row per unique taxon name in \`obs\`:

- \`TaxonName\`:

  The name as it appears in \`obs\`.

- \`matched\`:

  \`TRUE\` if the name was found as a canonical name or synonym in
  Section 1 of the expert system.

- \`canonical\`:

  The canonical name, or \`NA\` when unmatched.

## See also

\[resy_load_expert()\], \[resy_harmonize_eunis()\]
