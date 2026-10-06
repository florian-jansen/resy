# Standardize Plot Identification Column to Internal Standard

Converts plot ID columns to the internal \`PlotObservationID\` standard,
validating that the ID column exists in both observation and header data
frames.

## Usage

``` r
.resy_standardize_plot_id(obs, header, id_col = NULL)
```

## Arguments

- obs:

  data frame or data.table of species observations with a plot ID
  column.

- header:

  data frame with plot-level metadata including a plot ID column.

- id_col:

  character scalar specifying the name of the plot ID column to use. If
  \`NULL\` (default), the function automatically detects a standard
  column name.

## Value

list with elements: - \`obs\`: observation data with
\`PlotObservationID\` added/overwritten - \`header\`: header data with
\`PlotObservationID\` added/overwritten - \`id_col_used\`: character
scalar indicating which original column was used
