# RESY 0.3

## Groups of groups, backbones and the App

* A member of a Section 2 group may name another group with its prefix
  (`"### Wet-meadows"`); RESY reads such a group as the species of the groups it
  names, recursively. `resy_validate_esy()` reports references to undefined
  groups and groups that contain themselves. The RESY Maker shows the groups a
  group names apart from its species, adds them from a list and follows
  renamed, retyped and deleted groups.
* The webR bundle carries the whole of each backbone the shipped systems use,
  not only EuroSL.
* App and Maker take a file dropped onto a file field or its label; a file
  dropped beside it is no longer opened or saved by the browser.
* A backbone that vegdata names by name and version (`GermanSL 1.5`) is found
  from the declared name and version (`GermanSL`, `1.5`).
* Backbones with numeric taxon IDs (GermanSL) resolved names to wrong concepts
  and ranks, because IDs were looked up by position; IDs are now read as text.

## Taxonomic backbone instead of Section 1 name matching

* Section 1 of an expert system can now declare a taxonomic backbone instead
  of listing species aggregations (`.txt`: `SECTION 1: Taxonomic backbone`
  followed by `EuroSL https://eurosl.infinitenature.org <version>`; `.json`: a
  `backbone` object in place of `synonyms`). Plot taxa are then resolved to the
  backbone's taxon concepts with vegdata (concept-aware: s. l./agg./s. str.
  kept apart, `auct.` never matched, cf./aff./? ignored) and count for an
  expert taxon if the backbone places them at or below it.
* New `resy_backbone()` loads the backbone (option `resy.backbone` points to a
  local SQLite file or data frame). vegdata (>= 2.0.0), DBI and RSQLite are
  suggested.
* `resy_classify()` and `resy_check_taxonomy()` report the plot taxon names
  that cannot be used, split into potentially important and probably
  unimportant ones (`summary(res$taxon_resolution)`).
* New default versions `EUNIS 2025-10-03-EuroSL` and
  `Apennine-test 2026-06-27-EuroSL`: derived from the published releases, with
  Section 1 replaced by the EuroSL backbone and species names updated to
  accepted EuroSL names (`data-raw/build_eurosl_experts.R`). The published
  releases stay unchanged; pass `version = "2025-10-03"` for the old matching.
* The synonym layer (`resy_read_synonyms()`, `resy_resolve_taxa()`,
  `resy_canonical_species()`) is anchored on the newest published release and
  refuses expert systems with a backbone.
* `resy_diff_expert()` reports a changed backbone (`section = "backbone"`).
* New default `Apennine-test 2026-11-25` (`data-raw/build_apennine_test.R`):
  broad types forest, non-forest and the new wetland type are wider, and there
  are new forest (beech-fir, chestnut, thermophilous deciduous, holm oak,
  riparian), grassland and scrub (Ampelodesmos, dry and annual grassland, heath
  and maquis, coastal dunes) and wetland types (open water, marsh, saltmarsh).
  All 200 example plots now get a type (92 did not before). Groups may name a
  genus, which stands for all its species.
* `resy_provenance()` reports the declared backbone (`backbone`,
  `backbone_url`, `backbone_version`) and, for a result, the version used
  (`backbone_version_used`).
* A backbone read from a file is cached in RESY's cache directory. Name matches
  and the resolved names of an expert system are kept for the session, so
  classifying data in parts matches each name once.
* Without vegdata (or with `options(resy.backbone_match = "light")`), RESY
  matches names itself: as written, without author citation, aggregates only
  to aggregates; no correction of spelling.
* RESY App and Maker: the shipped systems with a backbone bring the part of
  EuroSL they name (with children, synonyms and ancestors); systems the user
  brings and the Maker load the whole of EuroSL (2.4 MB) on demand, in place
  of the synonym layer. The App lists the potentially important names that
  count for no taxon. The shipped systems are parsed when the bundle is built.
  In the Maker, new systems use EuroSL; the species tab of a system with a
  backbone shows how EuroSL reads its names and renames synonyms in the groups
  to accepted names; a system with a species list can switch to EuroSL, and
  its name suggestions come from EuroSL.
* `inst/extdata/eurosl_example.csv.xz`: the part of EuroSL the example data and
  the bundled expert systems need, for examples, vignettes and tests
  (`data-raw/build_eurosl_example.R`).
* Vignettes: `vignette("taxonomy")` is rewritten for the backbone;
  `vignette("RESY")` and `vignette("EUNIS")` check names with
  `resy_check_taxonomy()` and classify the names as given.

## Deprecated

* `resy_resolve_taxa()`, `resy_read_synonyms()`, `resy_canonical_species()`
  (name matching through the synonym layer) and `resy_clean_names()`
  (backbone matching removes author citations); to be removed in RESY 0.4.
* `resy_classify(resolve_taxa, synonyms)` and
  `resy_harmonize_eunis(run_taxonomy, species_data, parsed)`; check names with
  `resy_check_taxonomy()` or read `taxon_resolution` of the result.

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
* `resy_eval_type()` is now internal. Use `resy_eval_plot(res, p, type = )` to
  evaluate one type on one plot.
* Geographic helpers (`check_ecoregions`, `check_country`, `check_coast_dunes`,
  `check_coordinates`) consolidated into internal functions in
  `internal_eunis_geo.R` under the `.resy_assign_*` / `.resy_check_*` naming
  convention.
* RDS format support removed. Expert systems are imported from `.txt` and stored
  as `.json`. `resy_available_classifications()` no longer returns an
  `expert_rds` column.
* `resy_expert_path()` `format` argument is now `c("json", "txt")` only.
* The GIS layers in `data/` are read on first use and kept for the session.
  Attaching the package reads none of them, and repeated `resy_check_data()`
  calls on the 200 example plots take 0.07 s instead of 0.17 s.
* The shiny app's Classify button calls `resy_classify()`.
* `tibble` moved from Imports to Suggests; `methods` is no longer imported.

## New

* `resy_check_eunis()` — validates plot data against EUNIS structural
  requirements before harmonization, returning `list(ok, errors, warnings)`.
* New general vignette `vignette("RESY")` covering classification with both
  EUNIS and Apennine-test expert systems without EUNIS-specific geographic steps.
* Package help page `?RESY` with an overview of the workflow.
* Taxonomy crosswalk for plot data named under a general backbone:
  `resy_read_synonyms()` returns the synonym table of an expert system or reads
  your own crosswalk, `resy_canonical_species()` returns the canonical ESy names, and
  `resy_resolve_taxa()` maps a name column to them. A name that resolves to
  nothing stays `NA` and is flagged, never replaced by a guess.
  `resy_classify(resolve_taxa = TRUE)` runs the resolution before classifying;
  the default `FALSE` classifies the names as given. See `vignette("taxonomy")`.
* `resy_clean_names()` removes author citations from taxon names.
* All three published EUNIS-ESy releases ship with the package as their
  original `.txt` files, xz-compressed (`expert.txt.xz`: 160, 168 and 640 KB
  for 2020-06-08, 2021-06-01 and 2025-10-03; the content has the MD5 of the
  Zenodo file). The 2025-10-03 release replaces the `expert.json.xz` shipped
  before, which kept only the last declaration of an aggregate declared twice
  in the release (*Mentha longifolia*, *Dactylorhiza majalis*) and left out
  two aggregates. The synonym table anchored on 2025-10-03 has 67,005 pairs
  instead of 67,018: the restored members make 13 synonyms either names of
  the expert system or ambiguous. `resy_load_expert(scheme = "EUNIS", version = )` and
  `resy_classify(version = )` choose the release; the default remains the
  newest. Expert files of either format may be xz-compressed in a
  classification store.
* `resy_add_classification(scheme = "EUNIS", version = )` without `file`
  downloads a published release from Zenodo, checks it against its SHA-256
  checksum and stores it in the user store. The releases are declared in
  `inst/extdata/classifications/releases.csv`, from which
  `data-raw/build_registry.R` builds the [getaca](https://CRAN.R-project.org/package=getaca)
  registry `inst/getaca/registry.rds`. The registry is also read from the
  repository on GitHub, so a release published later becomes available
  without a new version of RESY. Downloading requires getaca (Suggests).
* `resy_provenance()` reports which release a parsed expert system or a
  classification result rests on: scheme, version, file, MD5 checksum, DOI of
  the release, whether the file is byte-identical to the published `.txt`,
  and, for `resy_classify(resolve_taxa = TRUE)`, the build of the synonym
  layer. A file passed as `expertfile` is recognised as a release by its
  content. The `version` element of a `resy_classify()` result now holds the
  version used rather than the argument given.
* `resy_diff_expert()` lists the aggregates, species groups and types that
  were added, removed or changed between two expert systems, for example two
  EUNIS-ESy releases given by version. A `.txt` and a `.json` file can be
  compared with each other.
* `resy_eval_plot()` also lists the other types at the level of the classified
  type (`siblings = TRUE`): for a plot classified as R22, the types R21, R23
  and R24 under R2. Each type in this list, in the list of lower levels and in
  `type =` says what kept the plot from it: a rule that does not hold, with
  the number of its conditions the plot satisfies, or a rule that holds but
  has a lower priority than the type chosen. Lower levels whose rule holds are
  now listed too. Siblings follow the group levels the codes imply
  (`resy_expert_tree(fill = TRUE)`), so the siblings of Q51 are Q52, Q53 and
  Q54 under Q5, which EUNIS-ESy does not define as a type.
* `resy_compare_types()` sets two types side by side, each from its own
  expert system: two types of one system (R11 and R22) or one type in two
  releases (R22 in 2020-06-08 and 2025-10-03). Conditions both rules use have
  the same number in both rules, and species groups are compared member by
  member. With `plot`, it shows for one classified plot which conditions it
  meets in each type and why it is or is not classified as each.
* RESY App: the plot panel lists the sibling types, and "Compare two types"
  sets the plot's type against any other type of the system or, for
  EUNIS-ESy, of another shipped release.
* NON conditions on `##C` and `##D` groups are evaluated. The right-hand side
  is the highest total cover among the other groups of the same set, the
  statistic the left-hand side takes for these groups; `##Q` is unchanged.
  The EUNIS-ESy release of 2021-06-01 uses one such condition (type N), which
  stopped classification with that release before.
* The RESY App offers the EUNIS-ESy releases in a menu, names the release and
  its DOI in the description and under the results, and adds
  `expert_system` and `expert_version` columns to the downloaded table.
* The RESY Maker (`articles/maker.html`, linked from the RESY App) builds an
  expert system in the browser on one screen: the types, the rule of the type
  shown put together from conditions as blocks, and beside it the species
  groups, the species list and the test plots. A group is made, named and
  filled from the condition that needs it, or dragged into a rule. After
  every change RESY classifies a set of test plots (the example plots or your
  own files) and the page shows the number of plots in which each condition
  and each rule holds; selecting a plot marks the conditions it meets and
  misses. The page opens on the draft kept in the browser or on the Apennine
  example; an empty system, a shipped system or a `.json` or `.txt` file is
  opened from the top bar. A system is exported as `.json` or `.txt` or
  handed to the RESY App. The `.txt` file is read back and compared with the
  `.json` file before it is offered. Types and groups are deleted from their
  lists, species are ticked (Shift for a range) and removed together and can
  be put back, **Save** downloads the system as a file and **Clear** empties
  it after a confirmation.
* The RESY App and the RESY Maker are both in the navigation bar and share
  one window: the page that was opened loads the other tool in the
  background, so going from one to the other, with or without an expert
  system, does not start R again.
* The RESY App keeps each expert system it has read, so choosing a system
  again shows its description at once instead of reading the file again
  (EUNIS-ESy 2025-10-03: 1.6 s to under 0.1 s).
* The explanation of a plot in the RESY App and the RESY Maker lists a
  species that is not in the expert system under the name written in the
  plot data.
* `resy_load_expert()` reads a `.txt` file whose types have a letter as
  priority (`0`-`9`, `A`-`Z`, `a`-`z`, as in a `.json` file). Such a file
  passed `resy_validate_esy()` but could not be loaded.
* `resy_read_expert()` reads the species aggregation section of a large
  `.txt` file about 2.5 times faster (EUNIS-ESy 2025-10-03: 2.5 s to 1.0 s),
  with the same result.
* A type code that fills the five-character code field of a `.txt` header is
  read without the description that follows it directly: `N15!!`, not
  `N15!!Atlantic`. Trailing `!` marks number further rules of a type; the
  three EUNIS-ESy releases each have five such headers (N15!!, N16!!, N17!!,
  T1C!!, T1D!!).
* Reading a `.txt` expert system is about 19 times faster (9.7 s to 0.5 s for
  the three EUNIS-ESy releases), with an identical result. Loading EUNIS-ESy
  2025-10-03 takes 0.3 s from the `.txt` and 0.14 s from the former `.json`.
  The file is read once for both the parser and the checksum that
  `resy_provenance()` reports.
* `resy_load_expert()` keeps each loaded system in RESY's cache directory
  (`tools::R_user_dir("RESY", "cache")`) and restores it on later loads of the
  same file: EUNIS-ESy 2025-10-03 then loads in 0.08 s, the three EUNIS-ESy
  releases in 0.14 s. A cached copy is used only while the file keeps its size
  and modification time and the same installed RESY loads it; a new copy
  replaces the older ones of that file. `options(RESY.cache = FALSE)` turns
  the cache off and `options(RESY.cache_dir =)` moves it.
* An `#SC` comparison receives its `EXCEPT` clause by the literal text of its
  condition. A condition holding `+` (a discriminating group such as
  `#SC +12 Conifers`) was left without the clause, and one holding `|` also
  added it to other expressions that share part of its text. No shipped expert
  system has such a condition, so their results are unchanged.
* Formulas and membership expressions are turned into R code by matching each
  bracketed condition and each side of a comparison as a whole, instead of
  replacing every condition text in turn. The result is identical for all
  shipped expert systems, and RESY no longer depends on stringi.
* `resy_expert_path()` returns by default the file a classification is stored
  in, whichever its format; `format = "json"` or `"txt"` still asks for one.
* `resy_check_taxonomy()` also counts as known the species that a species
  group or a membership condition names without Section 1 listing them. The
  2020 and 2021 EUNIS-ESy releases list only aggregates in Section 1, so a
  species such as *Fagus sylvatica* was reported unmatched and the RESY App,
  which drops unmatched names, left 1,609 of the 3,580 example records out
  (1,573 for 2021). The App now classifies 196 of the 200 example plots with
  either release, as `resy_classify()` does.
* `resy_load_expert()` and `resy_classify()` gain `location`. By default a
  classification is looked up first in the user store, where
  `resy_add_classification()` puts it, then among the shipped classifications.
* `resy_harmonize_eunis()` writes `DEG_LAT` and `DEG_LON`. `source_crs` can be
  left out for coordinates in degrees (read as EPSG:4326), and coordinates in any
  other CRS are converted. It warns when no site falls inside the country base
  map. `resy_check_eunis()` and `resy_check_data()` read degree coordinates the
  same way.
* `resy_classify()` warns when the expert system has conditions on header
  columns that `header` lacks; those conditions are evaluated as if the value
  were 0.
* `resy_validate_esy()` resolves group references the way the classifier does.
  The EUNIS-ESy release of 2025-10-03 now gives 3 warnings instead of 234.
* The synonyms come from six taxonomic backbones (Euro+Med, WFO, GBIF, COL,
  ITIS, NCBI), collected once by `data-raw/build_synonyms.R` into a layer that
  serves every expert system and release. `resy_read_synonyms()`,
  `resy_canonical_species()` and `resy_resolve_taxa()` take an `expert` (by
  default the newest EUNIS release) and fit the layer to its species names, so
  each release gets its own synonym table; `resy_classify(resolve_taxa = TRUE)`
  uses the expert system it classifies with. A synonym that points to two names
  the expert system evaluates differently, counting the members of its
  aggregates, is resolved by Euro+Med or stays unresolved. For EUNIS 2025-10-03
  the table has 67,018 synonym pairs. The build date and the release of each
  backbone are in `inst/extdata/esy_synonym_layer_build.csv` and
  `esy_synonym_layer_backbones.csv`. An `accepted_in` column names the
  backbones that list the synonym as an accepted name under the same author as
  the supporting synonym rows.
* The canonical names of an expert system are the names its classifier
  evaluates: the aggregates of Section 1, and the species that a species group
  or a membership condition names and that no aggregate includes.
  `resy_resolve_taxa()` leaves every species name the expert system uses
  untouched, including the names of species groups and conditions.
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
* `resy_candidates(wide = TRUE)` returns one row per plot: `plot_id`, its
  `classification`, then `type_1`, `priority_1`, `type_2`, `priority_2`, ...,
  highest priority first. Plots without candidates are kept with `NA`.
* `resy_eval_plot()` explains a plot's classification in plain words: the types
  whose rules hold with their priorities, the type chosen, and the plot's species
  with cover. It then lists the lower-level types the plot did not reach, closest
  first, and shows the closest in full: its rule with numbered conditions, and
  for each condition whether it is met, the plot's value, the required value and
  the species behind it. `type =` shows any type the same way; `lower = FALSE`
  turns the list off. The `group_names` column is no longer added to the species
  output.
* Plot data can use Darwin Core column names: `eventID` for the plot ID,
  `scientificName` for the species, `organismQuantity` with a percent-cover
  `organismQuantityType` for the cover, `decimalLongitude`, `decimalLatitude`
  and `country` for the site, and `minimumElevationInMeters` /
  `maximumElevationInMeters` for `Altitude (m)`, which is also read from a
  column `Altitude`. `species_col` in
  `resy_classify()` and `resy_resolve_taxa()` and `col` in
  `resy_check_taxonomy()` default to `NULL`, which uses `TaxonName`, then
  `scientificName`.

## Fixes

* The `.txt` expert-file parser keeps the last member of the last group in
  section 2 when the section ends on it, and no longer stores blank lines as
  group or aggregation members. An aggregation without members is now an empty
  character vector. Classifications from the EUNIS-ESy releases of 2020, 2021
  and 2025 are unchanged.
* Header conditions (`$$C`, `$$N`) are evaluated on each plot's own header row.
* Classifying a single plot with an expert system that has exactly one numeric
  header condition (`$$N`) no longer overwrites the value of the system's first
  membership condition with the header value. `resy_eval_plot()` output in the
  RESY App, which classifies the selected plot alone, showed that value, for
  example a total cover of 10.7% (the plot's longitude) in place of 87.9%.
* `resy_validate_esy()` reads a `.txt` and a `.json` file into the same parts
  (group keys and type definitions) and checks them with one set of rules, so
  a system gets the same report in either format. Three files that defined
  the validator a second time, and whose older definitions were the ones in
  use, are removed. With them go the false warnings they gave: header columns
  (`$$C`, `$$N`), set tags (`+01`), groups joined by `|` and group names with
  spaces were reported as undefined groups, 277 times for the EUNIS-ESy
  release of 2025-10-03, which now gets three warnings (tab characters, the
  condition `#TC Cliff-ferns GR05` of type P2N, the duplicate code T3M).
* `resy_validate_esy()` reports a type without a formula as an error in a
  `.txt` file too (RESY cannot read such a file; it was a warning), a
  Section 3 header without a code, a file without any type, and an empty type
  description in a `.txt` file.
* `inst/extdata/example_mini_expert_file.txt` holds two type definitions in
  Section 3; it held two lines that are no definitions, and RESY could not
  load it.
* A membership condition is replaced in a formula together with its angle
  brackets, so text outside a condition that equals a condition is left as it
  is. The compiled formulas of the shipped systems are unchanged.
  Before, the header rows were used in the order of `header`, so a plot read
  another plot's header values unless `header` and `obs` listed the plots in
  the same order. On the 200-plot EUNIS example 13 plots change type.
* Total cover (`#T$`) and highest cover (`#$$`) conditions are filled by plot id.
  Before, their values landed on the wrong plots when `obs` was not sorted by
  plot id.
* Groups combined with `|` (e.g. `#TC Trees|#TC Shrubs GR 15`) are evaluated as
  one condition on the union of the groups, not as separate conditions joined
  by OR. On the 200-plot EUNIS example 11 plots change type.
* Before, EUNIS conditions on `DEG_LAT` and `DEG_LON` read 0 because
  `resy_harmonize_eunis()` did not write these columns. On the 200-plot EUNIS
  example 15 plots change type.
* `resy_eval_plot()` looks up a plot in the classifier's plot order, not in the
  row order of `header`, and reports the responsible taxa of `#TC ... GR n`
  conditions, which were `NA`.
* `resy_aggregate_taxa()` works with an expert system that has no aggregations.
* `resy_candidates(top_n = )` keeps the candidates with the highest priority.
  Before, it kept those with the lowest, so `top_n = 1` returned for example
  `F` (priority 2) for a plot classified as `FB` (priority 5).
* `resy_classify()` stops when `obs` has no `species_col` column. Before, it
  classified every plot as unclassified (`?`). A `species_col` other than
  `TaxonName` is used even when `obs` also has a `TaxonName` column.
* `resy_add_classification()` stores the metadata of a `.txt` input as
  `metadata.json`; it was named `expert.json`, which `resy_load_expert()` then
  tried to read as the expert system. `overwrite = TRUE` removes the previous
  files.

## Documentation

* `vignette("taxonomy")` opens with the three steps (resolve, inspect,
  classify) and states the build date and backbone versions of the shipped
  synonym table, with a table and a figure of how many backbones support each
  pair. Its classify example resolves names against the vocabulary of the expert
  system it classifies with.
* `vignette("RESY")` shows the printed result and the `summary()` of
  `resy_check_taxonomy()`.
* The EUNIS vignette lists Markus Bauer, Mariasole Calbi and Gilles Colling as
  authors and links to the EUNIS page on the EEA Datahub.
* The Altitude vignette's sections start at level 2, below the title.
* The help pages of the GIS datasets give their names, sources and titles.

## Licence and authors

* The licence is unchanged (MIT). `LICENSE` holds the CRAN template (year and
  copyright holder) and the full text is in `LICENSE.md`. Both name all four
  authors as copyright holders.

## Package size

* GIS reference layers reduced (`data-raw/simplify_gis.R` rebuilds all of
  them), cutting `data/` from 9.5 MB to 1.9 MB and the source tarball to
  4.2 MB, below the CRAN 5 MB limit.
  `coastline_regions`, `ecoregions2017` and `dunes_bohn_*` are simplified with
  `rmapshaper` and rounded to a 10 m grid. The coast, ecoregion and dune
  assignments of the bundled 200-plot example are the same as with the
  full-resolution layers. Of 16,521 random points 4 to 6 km from the
  full-resolution coastline, 99 get a different coast; of 20,000 random points
  within 2 km of an ecoregion or dune polygon border, 349 get a different
  ecoregion and 69 a different dune assignment.
  `europe_resolution_1` (country lookup) keeps all vertices, rounded to a 1 m
  grid (3.0 MB to 1.1 MB); none of 858 test points within 2 km of a border or
  coast changes country. `europe_resolution_60` is unchanged.

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
