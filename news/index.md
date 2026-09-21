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

- `resy_parse_expert()`, `resy_parse_json()`, `resy_show_vegtypes()` are
  now internal (unexported). Use
  [`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md)
  as the single entry point for loading any expert system.
- `resy_eval_type()` is now internal. Use
  `resy_eval_plot(res, p, type = )` to evaluate one type on one plot.
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
- The GIS layers in `data/` are read on first use and kept for the
  session. Attaching the package reads none of them, and repeated
  [`resy_check_data()`](https://florian-jansen.github.io/resy/reference/resy_check_data.md)
  calls on the 200 example plots take 0.07 s instead of 0.17 s.
- The shiny app’s Classify button calls
  [`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md).
- `tibble` moved from Imports to Suggests; `methods` is no longer
  imported.

### New

- [`resy_check_eunis()`](https://florian-jansen.github.io/resy/reference/resy_check_eunis.md)
  — validates plot data against EUNIS structural requirements before
  harmonization, returning `list(ok, errors, warnings)`.
- New general vignette
  [`vignette("RESY")`](https://florian-jansen.github.io/resy/articles/RESY.md)
  covering classification with both EUNIS and Apennine-test expert
  systems without EUNIS-specific geographic steps.
- Package help page
  [`?RESY`](https://florian-jansen.github.io/resy/reference/RESY-package.md)
  with an overview of the workflow.
- Taxonomy crosswalk for plot data named under a general backbone:
  [`resy_read_synonyms()`](https://florian-jansen.github.io/resy/reference/resy_read_synonyms.md)
  reads the shipped synonym table or your own crosswalk,
  [`resy_canonical_species()`](https://florian-jansen.github.io/resy/reference/resy_canonical_species.md)
  returns the canonical ESy names, and
  [`resy_resolve_taxa()`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md)
  maps a name column to them. A name that resolves to nothing stays `NA`
  and is flagged, never replaced by a guess.
  `resy_classify(resolve_taxa = TRUE)` runs the resolution before
  classifying; the default `FALSE` classifies the names as given. See
  [`vignette("taxonomy")`](https://florian-jansen.github.io/resy/articles/taxonomy.md).
- [`resy_clean_names()`](https://florian-jansen.github.io/resy/reference/resy_clean_names.md)
  removes author citations from taxon names.
- [`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md)
  and
  [`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
  gain `location`. By default a classification is looked up first in the
  user store, where
  [`resy_add_classification()`](https://florian-jansen.github.io/resy/reference/resy_add_classification.md)
  puts it, then among the shipped classifications.
- [`resy_harmonize_eunis()`](https://florian-jansen.github.io/resy/reference/resy_harmonize_eunis.md)
  writes `DEG_LAT` and `DEG_LON`. `source_crs` can be left out for
  coordinates in degrees (read as EPSG:4326), and coordinates in any
  other CRS are converted. It warns when no site falls inside the
  country base map.
  [`resy_check_eunis()`](https://florian-jansen.github.io/resy/reference/resy_check_eunis.md)
  and
  [`resy_check_data()`](https://florian-jansen.github.io/resy/reference/resy_check_data.md)
  read degree coordinates the same way.
- [`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
  warns when the expert system has conditions on header columns that
  `header` lacks; those conditions are evaluated as if the value were 0.
- [`resy_validate_esy()`](https://florian-jansen.github.io/resy/reference/resy_validate_esy.md)
  resolves group references the way the classifier does. The EUNIS-ESy
  release of 2025-10-03 now gives 3 warnings instead of 234.
- The shipped synonym table is built by `data-raw/build_synonyms.R` from
  six taxify backbones. Its build date, the taxify release, and the
  version and content id of each backbone are shipped in
  `inst/extdata/esy_synonyms_build.csv` and
  `esy_synonyms_backbones.csv`, and the taxify lockfile is in
  `data-raw/`. The table has an `accepted_in` column naming the
  backbones that list the synonym as an accepted name under the same
  author as the supporting synonym rows.
- [`resy_resolve_taxa()`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md)
  matches a name a second time with its author citation removed
  ([`resy_clean_names()`](https://florian-jansen.github.io/resy/reference/resy_clean_names.md))
  when it does not match as given. These matches are labelled
  `"cleaned_exact"` and `"cleaned_synonym"` in `taxon_confidence`.
- [`resy_check_taxonomy()`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md)
  and
  [`resy_resolve_taxa()`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md)
  both return a `resy_taxa` data frame with a logical `matched` column.
  [`resy_check_taxonomy()`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md)
  names its columns `scientificName` (as submitted), `TaxonName`
  (canonical) and `matched`. Printing a `resy_taxa` table describes its
  columns and counts the matches;
  [`summary()`](https://rspatial.github.io/terra/reference/summary.html)
  gives the counts per name and per record, the records by match type,
  and the unmatched names grouped into genus only, below species level
  and species. `resy_summarize_taxa()` is removed; use
  [`summary()`](https://rspatial.github.io/terra/reference/summary.html)
  on the result of
  [`resy_resolve_taxa()`](https://florian-jansen.github.io/resy/reference/resy_resolve_taxa.md).
  With `resolve_taxa = TRUE`,
  [`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
  stores that summary as `taxon_resolution`.

### Fixes

- The `.txt` expert-file parser keeps the last member of the last group
  in section 2 when the section ends on it, and no longer stores blank
  lines as group or aggregation members. An aggregation without members
  is now an empty character vector. Classifications from the EUNIS-ESy
  releases of 2020, 2021 and 2025 are unchanged.
- Header conditions (`$$C`, `$$N`) are evaluated on each plot’s own
  header row. Before, the header rows were used in the order of
  `header`, so a plot read another plot’s header values unless `header`
  and `obs` listed the plots in the same order. On the 200-plot EUNIS
  example 13 plots change type.
- Total cover (`#T$`) and highest cover (`#$$`) conditions are filled by
  plot id. Before, their values landed on the wrong plots when `obs` was
  not sorted by plot id.
- Groups combined with `|` (e.g. `#TC Trees|#TC Shrubs GR 15`) are
  evaluated as one condition on the union of the groups, not as separate
  conditions joined by OR. On the 200-plot EUNIS example 11 plots change
  type.
- Before, EUNIS conditions on `DEG_LAT` and `DEG_LON` read 0 because
  [`resy_harmonize_eunis()`](https://florian-jansen.github.io/resy/reference/resy_harmonize_eunis.md)
  did not write these columns. On the 200-plot EUNIS example 15 plots
  change type.
- [`resy_eval_plot()`](https://florian-jansen.github.io/resy/reference/resy_eval_plot.md)
  looks up a plot in the classifier’s plot order, not in the row order
  of `header`, and reports the responsible taxa of `#TC ... GR n`
  conditions, which were `NA`.
- `resy_aggregate_taxa()` works with an expert system that has no
  aggregations.
- [`resy_add_classification()`](https://florian-jansen.github.io/resy/reference/resy_add_classification.md)
  stores the metadata of a `.txt` input as `metadata.json`; it was named
  `expert.json`, which
  [`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md)
  then tried to read as the expert system. `overwrite = TRUE` removes
  the previous files.

### Documentation

- [`vignette("taxonomy")`](https://florian-jansen.github.io/resy/articles/taxonomy.md)
  opens with the three steps (resolve, inspect, classify) and states the
  build date and backbone versions of the shipped synonym table, with a
  table and a figure of how many backbones support each pair. Its
  classify example resolves names against the vocabulary of the expert
  system it classifies with.
- [`vignette("RESY")`](https://florian-jansen.github.io/resy/articles/RESY.md)
  shows the printed result and the
  [`summary()`](https://rspatial.github.io/terra/reference/summary.html)
  of
  [`resy_check_taxonomy()`](https://florian-jansen.github.io/resy/reference/resy_check_taxonomy.md).
- The EUNIS vignette lists Markus Bauer, Mariasole Calbi and Gilles
  Colling as authors and links to the EUNIS page on the EEA Datahub.
- The Altitude vignette’s sections start at level 2, below the title.
- The help pages of the GIS datasets give their names, sources and
  titles.

### Licence and authors

- The licence is unchanged (MIT). `LICENSE` holds the CRAN template
  (year and copyright holder) and the full text is in `LICENSE.md`. Both
  name all four authors as copyright holders.

### Package size

- GIS reference layers reduced (`data-raw/simplify_gis.R` rebuilds all
  of them), cutting `data/` from 9.5 MB to 3.1 MB and the source tarball
  to 4.8 MB, below the CRAN 5 MB limit. `coastline_regions`,
  `ecoregions2017` and `dunes_bohn_*` are simplified with `rmapshaper`,
  each with the strongest simplification that leaves the coast,
  ecoregion and dune assignments of the bundled 200-plot example
  unchanged. `europe_resolution_1` (country lookup) keeps all vertices,
  rounded to a 1 m grid (3.0 MB to 1.1 MB); none of 858 test points
  within 2 km of a border or coast changes country.
  `europe_resolution_60` is unchanged.

## RESY 0.2

- Added
  [`resy_read_expert()`](https://florian-jansen.github.io/resy/reference/resy_read_expert.md),
  [`resy_write_expert()`](https://florian-jansen.github.io/resy/reference/resy_write_expert.md),
  [`resy_expert_tree()`](https://florian-jansen.github.io/resy/reference/resy_expert_tree.md),
  [`resy_write_expert_html()`](https://florian-jansen.github.io/resy/reference/resy_write_expert_html.md),
  [`resy_view_expert()`](https://florian-jansen.github.io/resy/reference/resy_view_expert.md),
  and
  [`resy_eunis_names()`](https://florian-jansen.github.io/resy/reference/resy_eunis_names.md)
  for lossless reading, writing, and hierarchical inspection of
  expert-system files.
- Added `resy_parse_json()` for direct parsing of structured JSON expert
  files.
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
