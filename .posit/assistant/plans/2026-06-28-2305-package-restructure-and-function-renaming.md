# Plan: Package restructure and function renaming

## Objectives

1. Rename functions so names honestly reflect what they do (check + adapt + harmonize)
2. Make implementation-detail functions internal (`.fn` convention)
3. De-couple the package from EUNIS — it supports any ESy classification
4. Keep a coherent `resy_` prefix across all public functions
5. Write a general vignette covering EUNIS and Apennine-test

---

## Naming principles

| Principle | Decision |
|---|---|
| All public functions | `resy_` prefix |
| Pure validation (no side effects) | `resy_validate_*` |
| Check + adapt general data | `resy_check_*` |
| Harmonize classification-specific data | `resy_harmonize_*` |
| Internal helpers | `.resy_*` (no export, dot prefix) |
| Classification-specific public functions | `resy_*_<scheme>()` e.g. `resy_harmonize_eunis()` |

---

## Function mapping: old → new

### Public API (exported)

| Old name | New name | Change type |
|---|---|---|
| `resy_classify()` | `resy_classify()` | keep |
| `resy_validate_expert()` | `resy_validate_esy()` | rename (ESy is the concept) |
| `check_taxonomy()` | `resy_check_taxonomy()` | add prefix |
| `check_format()` | `resy_check_data()` | rename (general; not EUNIS-specific) |
| `prepare_eunis()` | split → `resy_check_eunis()` + `resy_harmonize_eunis()` | split + rename |
| `resy_candidates()` | `resy_candidates()` | keep |
| `resy_eval_plot()` | `resy_eval_plot()` | keep |
| `resy_eval_type()` | `resy_eval_type()` | keep |
| `resy_available_classifications()` | `resy_available_classifications()` | keep |
| `resy_expert_tree()` | `resy_expert_tree()` | keep |
| `resy_view_expert()` | `resy_view_expert()` | keep |
| `resy_write_expert_html()` | `resy_write_expert_html()` | keep |
| `resy_read_expert()` | `resy_read_expert()` | keep |
| `resy_write_expert()` | `resy_write_expert()` | keep |
| `resy_expert_path()` | `resy_expert_path()` | keep |
| `resy_eunis_names()` | `resy_eunis_names()` | keep (EUNIS-specific lookup) |

### Made internal (unexported, dot prefix added)

| Old name | New internal name | Reason |
|---|---|---|
| `resy_load_expert()` | `.resy_load_expert()` | implementation detail of `resy_classify` |
| `resy_parse_expert()` | `.resy_parse_expert()` | implementation detail |
| `resy_parse_json()` | `.resy_parse_json()` | implementation detail |
| `resy_add_classification()` | `.resy_add_classification()` | advanced/developer use only |
| `resy_aggregate_taxa()` | `.resy_aggregate_taxa()` | called internally by `resy_classify` |
| `resy_show_vegtypes()` | `.resy_show_vegtypes()` | superseded by `resy_expert_tree()` |
| `check_ecoregions()` | `.resy_assign_ecoregions()` | internal helper for `resy_harmonize_eunis` |
| `check_country()` | `.resy_assign_country()` | internal helper for `resy_harmonize_eunis` |
| `check_coast_dunes()` | `.resy_assign_coast_dunes()` | internal helper for `resy_harmonize_eunis` |
| `check_coordinates()` | `.resy_check_coordinates()` | internal helper for `resy_harmonize_eunis` |

---

## Split of `prepare_eunis()` → two functions

The current `prepare_eunis()` does too much. Split into:

**`resy_check_eunis(data)`**
- Validates that `data` has the columns and structure EUNIS requires
- Checks: `RELEVE_NR` present, coordinates valid, required columns present
- Returns a list of issues (like `resy_validate_esy()` but for input data)
- Pure check — no modification

**`resy_harmonize_eunis(data, source_crs, run_taxonomy, species_data, parsed, run_coast_dunes, coast_buffer)`**
- Enriches data: assigns ecoregions, country, coast/dune flags
- Converts CRS to EPSG:25832, re-exports WGS84 coords
- Optionally runs `resy_check_taxonomy()`
- Returns `list(sites, species_checked)` as before
- Calls `.resy_assign_ecoregions()`, `.resy_assign_country()`, `.resy_assign_coast_dunes()`

---

## Proposed `_pkgdown.yml` structure

```yaml
reference:
- title: "Classification"
  contents:
  - resy_classify
  - resy_candidates

- title: "Result evaluation"
  contents:
  - resy_eval_plot
  - resy_eval_type

- title: "Data preparation (general)"
  contents:
  - resy_check_taxonomy
  - resy_check_data

- title: "Data preparation (EUNIS)"
  contents:
  - resy_check_eunis
  - resy_harmonize_eunis
  - resy_eunis_names

- title: "Expert system files"
  contents:
  - resy_validate_esy
  - resy_available_classifications
  - resy_expert_path
  - resy_read_expert
  - resy_write_expert
  - resy_expert_tree
  - resy_view_expert
  - resy_write_expert_html

- title: "Data"
  contents:
  - bohn
  - bohn_25832
  - co
  - ecoregions2017_epsg25832
  - europe_resolution_1_epsg25832
  - europe_resolution_60_epsg25832
```

---

## Files to rename/create

| Old file | New file | Notes |
|---|---|---|
| `R/prepare_eunis.R` | `R/resy_check_eunis.R` + `R/resy_harmonize_eunis.R` | split |
| `R/check_data-format.R` | `R/resy_check_data.R` | rename |
| `R/check_expertfile-format.R` | `R/resy_validate_esy.R` | rename |
| `R/check_taxonomy.R` | `R/resy_check_taxonomy.R` | rename |
| `R/check_definitions.R` | `R/resy_show_vegtypes.R` → internal | becomes internal |
| `R/check_ecoregions.R` | `R/internal_eunis_geo.R` | merge geo helpers |
| `R/check_country.R` | (merged into `internal_eunis_geo.R`) | merge |
| `R/check_coast_dunes.R` | (merged into `internal_eunis_geo.R`) | merge |
| `R/check_coordinates.R` | (merged into `internal_eunis_geo.R`) | merge |
| `tests/testthat/test-prepare_eunis.R` | `tests/testthat/test-resy_harmonize_eunis.R` | rename |
| `man/prepare_eunis.Rd` | `man/resy_harmonize_eunis.Rd` + `man/resy_check_eunis.Rd` | split via roxygen |
| `vignettes/EUNIS.Rmd` | `vignettes/EUNIS.Rmd` (keep) + `vignettes/RESY.Rmd` (new) | add general vignette |

---

## New general vignette: `vignettes/RESY.Rmd`

Title: **"Classifying vegetation surveys with RESY"**

Structure:
1. Introduction — ESy as a general framework; EUNIS and Apennine-test as two examples
2. Load example species data (same dataset)
3. Taxonomy check with `resy_check_taxonomy()` against each expert system
4. Classify against EUNIS with `resy_classify()`
5. Classify against Apennine-test with `resy_classify()`
6. Compare/evaluate results with `resy_candidates()`, `resy_eval_plot()`, `resy_eval_type()`
7. Brief note on EUNIS-specific geographic preparation (`resy_harmonize_eunis()`) pointing to the EUNIS vignette

This vignette does *not* require geographic enrichment — it shows the general workflow that works for any classification scheme. EUNIS-specific steps (ecoregion, country, coast) remain in `vignettes/EUNIS.Rmd`.

---

## Implementation order

1. Update `_pkgdown.yml`
2. Rename R source files (keeping old content, updating names/exports)
3. Add `resy_` prefix to `check_taxonomy` and `check_format` → `resy_check_data`
4. Rename `resy_validate_expert` → `resy_validate_esy`
5. Split `prepare_eunis` → `resy_check_eunis` + `resy_harmonize_eunis`
6. Make functions internal: load, parse, add_classification, aggregate_taxa, show_vegtypes
7. Rename and make internal: geo helpers → `.resy_assign_*` in `internal_eunis_geo.R`
8. Update `NAMESPACE`
9. Update tests
10. Update `vignettes/EUNIS.Rmd` references
11. Write `vignettes/RESY.Rmd`
12. Update `NEWS.md`
13. Update `docs/` (or note that `pkgdown::build_site()` will regenerate)
