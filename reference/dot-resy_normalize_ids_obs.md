# Normalize Plot IDs in Observation Data to Character PlotObservationID

Standardizes plot IDs in observation data to character format under the
\`PlotObservationID\` column.

## Usage

``` r
.resy_normalize_ids_obs(obs, id_col)
```

## Arguments

- obs:

  data frame or data.table of species observations.

- id_col:

  character scalar naming the source plot ID column.

## Value

data frame or data.table with \`PlotObservationID\` column added as
character representation of the source ID column.
