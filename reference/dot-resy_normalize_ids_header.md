# Normalize Plot IDs in Header Data to Character PlotObservationID

Standardizes plot IDs in header data to character format under the
\`PlotObservationID\` column.

## Usage

``` r
.resy_normalize_ids_header(header, id_col)
```

## Arguments

- header:

  data frame with plot-level metadata.

- id_col:

  character scalar naming the source plot ID column.

## Value

data frame with \`PlotObservationID\` column added as character
representation of the source ID column.
