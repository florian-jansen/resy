# Harmonize plot data for EUNIS classification

Prepares vegetation plot header data for EUNIS habitat classification.
Converts coordinates to EPSG:25832, assigns WWF ecoregions and country
identifiers, optionally computes coast/dune flags, and optionally checks
and harmonizes species taxonomy.

Use \[resy_check_eunis()\] first to verify that the input data meets all
requirements before running this function.

## Usage

``` r
resy_harmonize_eunis(
  data,
  source_crs = NULL,
  run_taxonomy = FALSE,
  species_data = NULL,
  parsed = NULL,
  run_coast_dunes = FALSE,
  coast_buffer = 5000
)
```

## Arguments

- data:

  A data frame or \`sf\` object containing plot data. If not an \`sf\`
  object, columns \`Longitude\` and \`Latitude\` must be present.

- source_crs:

  Integer EPSG code of the input CRS. Required when \`data\` is a plain
  data frame; ignored when \`data\` is already an \`sf\` object.

- run_taxonomy:

  Logical; if \`TRUE\`, runs \[resy_check_taxonomy()\] on
  \`species_data\`.

- species_data:

  A data frame with a column \`species\`. Required when \`run_taxonomy =
  TRUE\`.

- parsed:

  A \`resy_parsed_expert\` object from \[resy_load_expert()\]. Required
  when \`run_taxonomy = TRUE\`.

- run_coast_dunes:

  Logical; if \`TRUE\`, assigns \`Coast_EEA\` and \`Dunes_Bohn\` flags
  via spatial intersection.

- coast_buffer:

  Numeric buffer in metres for coastline proximity (default 5000).

## Value

A named list:

- \`sites\`:

  Data frame of harmonised plot data, geometry dropped, WGS84
  \`Longitude\` and \`Latitude\` added.

- \`species_checked\`:

  Output from \[resy_check_taxonomy()\] when \`run_taxonomy = TRUE\`,
  otherwise \`NULL\`.

## See also

\[resy_check_eunis()\], \[resy_check_taxonomy()\], \[resy_classify()\]
