# Check plot data for EUNIS classification requirements

Validates that the input data frame or sf object meets the structural
requirements for EUNIS habitat classification. This is a pure check — it
reports issues without modifying data. Use \[resy_harmonize_eunis()\] to
actually enrich and prepare the data.

Checks performed:

- \`PlotObservationID\` column is present.

- Coordinates are present and can be transformed to EPSG:25832.

- \`Altitude (m)\` column is present and free of \`NA\`.

- \`Ecoreg\` and \`Country\` columns are present (or will need to be
  assigned).

- \`Coast_EEA\` and \`Dunes_Bohn\` columns are present when coastal/dune
  classification is relevant.

## Usage

``` r
resy_check_eunis(data, source_crs = NULL, verbose = TRUE)
```

## Arguments

- data:

  A data frame, tibble, or point \`sf\` object.

- source_crs:

  Integer EPSG code of the input CRS. Required when \`data\` is not an
  \`sf\` object.

- verbose:

  Logical; if \`TRUE\` (default), print a summary of issues.

## Value

A list with:

- \`ok\`:

  \`TRUE\` when no blocking issues were found.

- \`errors\`:

  Character vector of errors that will prevent classification.

- \`warnings\`:

  Character vector of warnings about missing or incomplete columns that
  \[resy_harmonize_eunis()\] can fill automatically.

## See also

\[resy_harmonize_eunis()\]
