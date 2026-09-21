# RESY 0.3

## Breaking changes — function renames

* `prepare_eunis()` split into `resy_check_eunis()` (pure validation) and
  `resy_harmonize_eunis()` (geographic enrichment + taxonomy).
* `check_taxonomy()` → `resy_check_taxonomy()`
* `check_format()` → `resy_check_data()`
* `resy_validate_expert()` → `resy_validate_esy()`

## Internal changes

* `resy_parse_expert()`, `resy_parse_json()`, `resy_show_vegtypes()` are now
  internal (unexported). Use `resy_load_expert()` as the single entry point for
  loading any expert system.
* Geographic helpers (`check_ecoregions`, `check_country`, `check_coast_dunes`,
  `check_coordinates`) consolidated into internal functions in
  `internal_eunis_geo.R` under the `.resy_assign_*` / `.resy_check_*` naming
  convention.
* RDS format support removed. Expert systems are imported from `.txt` and stored
  as `.json`. `resy_available_classifications()` no longer returns an
  `expert_rds` column.
* `resy_expert_path()` `format` argument is now `c("json", "txt")` only.

## New

* `resy_check_eunis()` — validates plot data against EUNIS structural
  requirements before harmonization, returning `list(ok, errors, warnings)`.
* New general vignette `vignette("RESY")` covering classification with both
  EUNIS and Apennine-test expert systems without EUNIS-specific geographic steps.
* The shipped synonym table is built by `data-raw/build_synonyms.R` from six
  taxify backbones. Its build date, the taxify release, and the version and
  content id of each backbone are shipped in `inst/extdata/esy_synonyms_build.csv`
  and `esy_synonyms_backbones.csv`, and the taxify lockfile is in `data-raw/`.
  The table has an `accepted_in` column naming the backbones that list the
  synonym as an accepted name under the same author as the supporting synonym
  rows.
* `resy_resolve_taxa()` matches a name a second time with its author citation
  removed (`resy_clean_names()`) when it does not match as given. These matches
  are labelled `"cleaned_exact"` and `"cleaned_synonym"` in `taxon_confidence`.
* `resy_check_taxonomy()` and `resy_resolve_taxa()` both return a `resy_taxa`
  data frame with a logical `matched` column. `resy_check_taxonomy()` names its
  columns `scientificName` (as submitted), `TaxonName` (canonical) and
  `matched`. Printing a `resy_taxa` table describes its columns and counts the
  matches; `summary()` gives the counts per name and per record, the records by
  match type, and the unmatched names grouped into genus only, below species
  level and species. `resy_summarize_taxa()` is removed; use `summary()` on the
  result of `resy_resolve_taxa()`. With `resolve_taxa = TRUE`,
  `resy_classify()` stores that summary as `taxon_resolution`.

## Fixes

* The `.txt` expert-file parser keeps the last member of the last group in
  section 2 when the section ends on it, and no longer stores blank lines as
  group or aggregation members. An aggregation without members is now an empty
  character vector. Classifications from the EUNIS-ESy releases of 2020, 2021
  and 2025 are unchanged.

## Package size

* GIS reference layers (`coastline_regions`, `ecoregions2017`,
  `europe_resolution_1`, `dunes_bohn_*`) simplified with `rmapshaper`
  (`data-raw/simplify_gis.R`), cutting `data/` from 9.5 MB to 2.1 MB and the
  source tarball below the CRAN 5 MB limit. Per-layer simplification was chosen
  so coast, ecoregion, country and dune assignments on the bundled 200-plot
  example are unchanged.

# RESY 0.2

* Added `resy_read_expert()`, `resy_write_expert()`, `resy_expert_tree()`,
  `resy_write_expert_html()`, `resy_view_expert()`, and `resy_eunis_names()`
  for lossless reading, writing, and hierarchical inspection of expert-system
  files.
* Added `resy_parse_json()` for direct parsing of structured JSON expert files.
* `prepare_eunis()` now returns a named list with `sites` and `species_checked`.
  A new `parsed` argument is required when `run_taxonomy = TRUE`.
* `check_taxonomy()` signature updated: `obs`, `parsed`, `col` replace the
  former `species` argument.
* `resy_available_classifications()` now discovers both package-bundled and
  user-added classification files.
* `resy_expert_path()` gains `"json"` as a supported format.
* Bug fixes and documentation updates throughout.
