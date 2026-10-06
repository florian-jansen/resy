# Retrieve Plot Identification Column with Priority Ordering

Retrieves a plot ID column name from both observation and header data
frames, using explicit priority ordering including user-specified
columns.

## Usage

``` r
.resy_get_id_col(obs, header, id_col = NULL)
```

## Arguments

- obs:

  data frame or data.table of species observations.

- header:

  data frame with plot-level metadata.

- id_col:

  character scalar specifying a preferred plot ID column name. If
  provided, this column is checked first before falling back to standard
  names.

## Value

character scalar naming the detected plot ID column.
