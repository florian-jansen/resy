# Parse an EUNIS expert-system file

Reads and parses an expert-system text file (SECTION 1/2/3 structure)
into species aggregations, species groups, membership
expressions/conditions and vegetation-type formulas.

This function wraps the original parser used by the accompanying scripts
and adds derived convenience fields (parsed formulas, short names, etc.)
needed by the classification workflow.

## Usage

``` r
resy_parse_expert(expertfile = NULL, scheme = "EUNIS", version = "2025-10-03")
```

## Arguments

- expertfile:

  Path to an expert-system file (in either .txt or .json format). If
  NULL, scheme and version of a bundled default is used.

- scheme:

  Name of expertfile Path to the expert-system file (either .txt or
  .json). If NULL, a bundled default is used.

- version:

  Version (date) of the expert-system file.

## Value

A list (class \`resy_parsed_expert\`) with parsed objects and derived
fields used by the solver.
