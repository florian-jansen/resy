# Package index

## Main functions

- [`resy_classify()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_classify.md)
  : Classify vegetation plots with the expert system
- [`prepare_eunis()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/prepare_eunis.md)
  : Prepare vegetation plot data for EUNIS expert system classification

## Helping functions

- [`check_coast_dunes()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/check_coast_dunes.md)
  : Check if Points Intersect Coastline or Dune Areas (EPSG:25832)
- [`check_coordinates()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/check_coordinates.md)
  : Transform the coordinates into UTM32N
- [`check_country()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/check_country.md)
  : Identify the country in which your vegetation surveys were conducted
- [`check_ecoregions()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/check_ecoregions.md)
  : Identify the ecoregion in which your vegetation surveys were
  conducted
- [`check_taxonomy()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/check_taxonomy.md)
  : Resolve Species Taxonomy via TNRS

## Data for prepare_eunis()

- [`dunes_bohn_500mbuffer_epsg25832`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/bohn.md)
  : Bohn dune layer with 500 m buffer (EPSG:25832)
- [`dunes_bohn_500mbuffer_25832`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/bohn_25832.md)
  : Bohn dune layer (unprojected)
- [`coastline_regions_epsg25832`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/co.md)
  : EEA coastline regions of Europe (EPSG:25832)
- [`ecoregions2017_epsg25832`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/ecoregions2017_epsg25832.md)
  : European ecoregions in EPSG:25832
- [`europe_resolution_1_epsg25832`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/europe_resolution_1_epsg25832.md)
  : European countries in high resolution
- [`europe_resolution_60_epsg25832`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/europe_resolution_60_epsg25832.md)
  : European countries in EPSG:25832

## Other helping functions

- [`check_format()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/check_format.md)
  : Check for the completeness of the data frame for running the EUNIS
  expert system
- [`resy_add_classification()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_add_classification.md)
  : Add a new classification from a TXT expert file
- [`resy_aggregate_taxa()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_aggregate_taxa.md)
  : Aggregate taxa to expert-system aggregation level
- [`resy_available_classifications()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_available_classifications.md)
  : List available classifications
- [`resy_candidates()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_candidates.md)
  : List possible assignments per plot
- [`resy_classifications_root()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_classifications_root.md)
  : Classification storage roots
- [`resy_compile_expert()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_compile_expert.md)
  : Compile a classification to RDS
- [`resy_eval_plot()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_eval_plot.md)
  : Evaluate and print details for a single plot
- [`resy_eval_type()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_eval_type.md)
  : Evaluate and print details for a vegetation type
- [`resy_expert_path()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_expert_path.md)
  : Get path to a bundled or user classification file
- [`resy_load_expert()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_load_expert.md)
  : Load a classification
- [`resy_parse_expert()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_parse_expert.md)
  : Parse an EUNIS expert-system file
- [`resy_show_vegtypes()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_show_vegtypes.md)
  : Show expert classification priority, abbreviation and name
- [`resy_validate_expert()`](https://loe.gitlab.uni-rostock.de/publications/r-esy/reference/resy_validate_expert.md)
  : Validate an expert classification text file (format checks)
