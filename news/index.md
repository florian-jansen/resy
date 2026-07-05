# Changelog

## RESY 0.3

### Breaking changes — function renames

- `prepare_eunis()` split into
  [`resy_check_eunis()`](https://florian-jansen.github.io/resy/reference/resy_check_eunis.md)
  (pure validation) and
  [`resy_harmonize_eunis()`](https://florian-jansen.github.io/resy/reference/resy_harmonize_eunis.md)
  (geographic enrichment + taxonomy).
- `check_taxonomy()` →
  [`resy_check_taxonomy()`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md)
- `check_format()` →
  [`resy_check_data()`](https://florian-jansen.github.io/resy/reference/resy_check_data.md)
- `resy_validate_expert()` →
  [`resy_validate_esy()`](https://florian-jansen.github.io/resy/reference/resy_validate_esy.md)

### Internal changes

- `resy_parse_expert()`,
  [`resy_parse_json()`](https://florian-jansen.github.io/resy/reference/resy_parse_json.md),
  `resy_show_vegtypes()` are now internal (unexported). Use
  [`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md)
  as the single entry point for loading any expert system.
- Geographic helpers (`check_ecoregions`, `check_country`,
  `check_coast_dunes`, `check_coordinates`) consolidated into internal
  functions in `internal_eunis_geo.R` under the `.resy_assign_*` /
  `.resy_check_*` naming convention.
- RDS format support removed. Expert systems are imported from `.txt`
  and stored as `.json`.
  [`resy_available_classifications()`](https://florian-jansen.github.io/resy/reference/resy_available_classifications.md)
  no longer returns an `expert_rds` column.
- [`resy_expert_path()`](https://florian-jansen.github.io/resy/reference/resy_expert_path.md)
  `format` argument is now `c("json", "txt")` only.

### New

- [`resy_check_eunis()`](https://florian-jansen.github.io/resy/reference/resy_check_eunis.md)
  — validates plot data against EUNIS structural requirements before
  harmonization, returning `list(ok, errors, warnings)`.
- New general vignette
  [`vignette("RESY")`](https://florian-jansen.github.io/resy/articles/RESY.md)
  covering classification with both EUNIS and Apennine-test expert
  systems without EUNIS-specific geographic steps.

## RESY 0.2

- Added
  [`resy_read_expert()`](https://florian-jansen.github.io/resy/reference/resy_read_expert.md),
  `resy_write_expert()`,
  [`resy_expert_tree()`](https://florian-jansen.github.io/resy/reference/resy_expert_tree.md),
  [`resy_write_expert_html()`](https://florian-jansen.github.io/resy/reference/resy_write_expert_html.md),
  [`resy_view_expert()`](https://florian-jansen.github.io/resy/reference/resy_view_expert.md),
  and
  [`resy_eunis_names()`](https://florian-jansen.github.io/resy/reference/resy_eunis_names.md)
  for lossless reading, writing, and hierarchical inspection of
  expert-system files.
- Added
  [`resy_parse_json()`](https://florian-jansen.github.io/resy/reference/resy_parse_json.md)
  for direct parsing of structured JSON expert files.
- `prepare_eunis()` now returns a named list with `sites` and
  `species_checked`. A new `parsed` argument is required when
  `run_taxonomy = TRUE`.
- `check_taxonomy()` signature updated: `obs`, `parsed`, `col` replace
  the former `species` argument.
- [`resy_available_classifications()`](https://florian-jansen.github.io/resy/reference/resy_available_classifications.md)
  now discovers both package-bundled and user-added classification
  files.
- [`resy_expert_path()`](https://florian-jansen.github.io/resy/reference/resy_expert_path.md)
  gains `"json"` as a supported format.
- Bug fixes and documentation updates throughout.
