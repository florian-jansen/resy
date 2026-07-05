# Prepare vegetation plot data for EUNIS expert system classification

Prepares vegetation plot header data for input into the EUNIS expert
classification system. Automatically validates coordinates, converts CRS
to EPSG:25832, assigns WWF ecoregions and country identifiers, and
optionally adds dune/coast indicators and taxonomic harmonization.

## Usage

``` r
prepare_eunis(
  data,
  source_crs = NULL,
  run_taxonomy = FALSE,
  species_data = NULL,
  run_coast_dunes = FALSE,
  coast_buffer = 5000
)
```

## Arguments

- data:

  A data frame or \`sf\` object containing vegetation plot data. If not
  an \`sf\` object, columns named \`Longitude\` and \`Latitude\` must
  exist.

- source_crs:

  Integer EPSG code of the original coordinate reference system.
  Required if \`data\` is a plain data frame; ignored if \`data\` is
  \`sf\`.

- run_taxonomy:

  Logical; if \`TRUE\`, applies \`check_taxonomy()\` to species data.

- species_data:

  Optional data frame with a column \`species\`. Required if
  \`run_taxonomy = TRUE\`.

- run_coast_dunes:

  Logical; if \`TRUE\`, computes coastal and dune flags.

- coast_buffer:

  Numeric buffer (meters) for coastline proximity. Default 5000.

## Value

A list with:

- sites:

  Data frame of harmonised plot data, geometry dropped.

- species_checked:

  Output from \`check_taxonomy()\` if run; otherwise \`NULL\`.
