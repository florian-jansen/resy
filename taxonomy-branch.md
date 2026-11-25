I want to get rid of the current name matching approach in the package and use a taxon
  concept aware approach using defined taxonomic backbones instead. For EUNIS and Appenine
  ESY systems the EuroSL backbone is used. Please make a plan of transition:
  1. Check part one of EUNIS and Appenine-test ESY systems for congruence with EuroSL. Every
  taxon group defined in part one should match a tree node in EuroSL and the respective
  member of the groups/aggs should match. Make a comparison and give me a list of mismatches
  with suggestions for manual adjustment of the expert system. After that this first part of
  every ESY system shall be omitted and replaced by a simple statement which taxonomic
  backbone will be used in this ESY system. For EUNIS and Appenine this will be
  https://eurosl.infinitenature.org as soon as it is updated. Use
  /home/jansen/aGitRepos/reflists/EuroSL/results/EuroSL.sqlite for the time being.
  In a second step we have to check all names in part two (group definitions) if they (the
  group names as well as their children) occur in the taxonomic backbone.
  As soon as both match, we can adapt the RESY code to match vegetation dataset to the
  taxonomic backbone instead of the ESY file. The idea is to use children along the taxonomic
  tree instead of handwritten species groups in the expert files.

# Transition plan: taxon-concept-aware matching on a taxonomic backbone

Backbone for EUNIS and Apennine: EuroSL (https://eurosl.infinitenature.org once
updated; until then the local `EuroSL.sqlite`, release "version 2026-11-24").

Check script: `data-raw/eurosl_congruence.R` (run with `Rscript --no-init-file`,
needs vegdata >= 2.0.0). Results go to `data-raw/eurosl-congruence/*.tsv` plus
`summary.txt`. Names are resolved with `vegdata::taxname.match()` using only
concept-safe steps (exact, aggr./s. l. -> agg., fuzzy spelling, accepted genus).
Not used: `simplify` (drops s. str./s. l./rank), "aggregate as species",
`infraspecific`, `genus`. `auct.` names are never matched automatically.
Names with cf./aff./? are never matched: what they represent is unknown, so
they are ignored (in the expert file and in plot data alike).
Broad names (agg., s. l., coll.) must land on an AGG/AG2/AG3/GRP/SER/SEC/SGE node.

## Step 1: Section 1 (species aggregation) vs. EuroSL tree

Each aggregation name must be one accepted EuroSL node; each member must be a
synonym of that node or a node below it.

Status values (`*_step1_groups.tsv`, `*_step1_members.tsv`):

| status | action in the expert file / EuroSL |
|---|---|
| group_is_synonym | rename aggregation to the accepted EuroSL name |
| group_name_needs_cleaning | spelling: rename to the matched name |
| duplicate_node | several aggregations are one EuroSL concept: merge |
| group_level_unclear | agg./s. l. name without an aggregate in EuroSL, or s. str.: decide level, or add the aggregate to EuroSL |
| group_not_found / group_misapplied_name | add the concept to EuroSL, or drop the aggregation |
| nested_in (column) | aggregation lies below another aggregation; with tree matching the lower one is absorbed unless kept as a separate node |
| member_elsewhere | EuroSL places the member in another concept: drop, or move to that aggregation (expert decision; lumping intended?) |
| member_broader_than_group | member is broader (e.g. `X aggr.` under `X`): move the aggregation up to the agg. node |
| eurosl_placement_missing | member hangs directly on the genus in EuroSL: fix placement in EuroSL (e.g. Rubus microspecies under sect. Rubus) |
| member_level_unclear | s. str./s. l. member: decide |
| member_uncertain_determination / group_uncertain_determination | cf./aff./? name: drop, it is ignored |
| ok_after_cleaning, member_not_found | field-name variants (cf., typos, var./f. not in EuroSL): delete from the expert file, the dataset side handles them |
| group_unresolved | member of an aggregation that is itself unresolved: revisit after fixing the group |

When step 1 is clean: drop Section 1 from every ESy file and replace it by one
backbone statement, e.g.

    SECTION 1: Taxonomic backbone
    EuroSL https://eurosl.infinitenature.org version <YYYY-MM-DD>
    SECTION 1: End

(JSON: `"backbone": {"name": "EuroSL", "url": ..., "version": ...}` instead of
`"synonyms"`.) The reader must accept both the old and the new Section 1 so
published releases (2020, 2021, 2025) keep working.

## Step 2: Section 2 (species groups) and species named in Section 3

Every group member must be an accepted EuroSL name (`*_step2_species_groups.tsv`:
synonym, needs_cleaning, level_unclear, not_found). Still to add to the script:
species referenced directly in Section 3 expressions (`$$C`, `$$N` etc.).

## Step 3: RESY code

1. Backbone handle: `resy_backbone()` reads the declared backbone (URL/version,
   local sqlite fallback) through vegdata; vegdata goes to DESCRIPTION Imports
   and renv.lock.
2. Plot data: resolve dataset names with `vegdata::taxname.match()` (same
   concept-safe steps; manual check file for unclear level / misapplied names)
   to TaxonUsageID -> TaxonConceptID. Only names that matter to the expert
   file need a match, i.e. names whose concept is a node referenced in
   Section 2/3 or lies below one. Everything else, including unmatched names,
   cf./aff./? records and odd hybrid notations, is ignored: it simply counts
   as no member of any species group. The report lists only unmatched names
   that could have mattered (same genus as a referenced node). Replaces `.resy_aggregate_taxa()`, `resy_resolve_taxa()`,
   the synonym layer (`esy_synonym_layer*.csv`) and `resy_check_taxonomy()`.
3. Expert file: resolve each Section 2 member and each Section 3 species to a
   concept ID at load time; a plot taxon counts for a member if the member's
   concept is the plot concept or an ancestor of it (children along the tree,
   cf. `vegdata::child()`). Cover of several plot taxa under one member is
   combined as before.
4. Taxa above the member (e.g. plot record `Festuca ovina agg.` vs. member
   `Festuca ovina`) do not count, but are reported (as `resy_check_data()` warning).
5. Cache resolved concept sets per (expert release, backbone version) in the
   existing expert cache.
6. Tests: regression on the example data, EUNIS-ESy classification results
   before/after, listed differences reviewed.


Step 1 results (Section 1 against the EuroSL tree)

┌─────────────────────────────────┬─────────────────────────┬────────────────────────────┐
│                                 │       EUNIS 2025        │       Apennine-test        │
├─────────────────────────────────┼─────────────────────────┼────────────────────────────┤
│ Aggregations matching an        │ 19,337 / 20,159         │ 786 / 950                  │
│ accepted node                   │                         │                            │
├─────────────────────────────────┼─────────────────────────┼────────────────────────────┤
│ Group name is a synonym         │ 318                     │ 120 (e.g. Agropyron repens │
│ (rename)                        │                         │  → Elytrigia repens)       │
├─────────────────────────────────┼─────────────────────────┼────────────────────────────┤
│ Several groups are one EuroSL   │                         │ 31 (e.g. Agrostis          │
│ concept (merge)                 │ 41                      │ capillaris = Agrostis      │
│                                 │                         │ tenuis)                    │
├─────────────────────────────────┼─────────────────────────┼────────────────────────────┤
│ Group level unclear (aggr. with │ 54 (e.g. Narcissus      │ 0                          │
│  no EuroSL aggregate)           │ pseudonarcissus aggr.)  │                            │
├─────────────────────────────────┼─────────────────────────┼────────────────────────────┤
│ Group name needs a spelling fix │ 36                      │ 7                          │
├─────────────────────────────────┼─────────────────────────┼────────────────────────────┤
│ Group not in EuroSL             │ 373                     │ 5                          │
├─────────────────────────────────┼─────────────────────────┼────────────────────────────┤
│ Misapplied (auct.) group        │ 0                       │ 1 (Valantia hispida auct.) │
├─────────────────────────────────┼─────────────────────────┼────────────────────────────┤
│ Member assigned to a different  │                         │ 11 (e.g. Festuca rubra     │
│ concept in EuroSL (needs expert │ 554                     │ subsp. commutata → F.      │
│  decision)                      │                         │ nigrescens)                │
├─────────────────────────────────┼─────────────────────────┼────────────────────────────┤
│ Member broader than its group   │ 486                     │ 0                          │
├─────────────────────────────────┼─────────────────────────┼────────────────────────────┤
│ Placement missing in EuroSL     │ 803                     │ 0                          │
├─────────────────────────────────┼─────────────────────────┼────────────────────────────┤
│ Field-name variants (cf.,       │ 3,571 matched + 9,777   │ 6 + 12                     │
│ typos, unlisted var./f.)        │ not found               │                            │
└─────────────────────────────────┴─────────────────────────┴────────────────────────────┘


## Status (2026-11-25)

Done:
- `R/resy_backbone.R`: backbone loading (vegdata; option `resy.backbone` =
  SQLite path or data frame), concept-aware matching, tree mapping, report of
  unusable plot names split into potentially important / probably unimportant.
- Readers: `.txt` Section 1 `Taxonomic backbone`, JSON `backbone` key;
  validator, diff, Shiny JSON import follow.
- Classification: plot taxa renamed to the nearest expert taxon above them in
  EuroSL; species groups and single-species conditions widened to the expert
  taxa below each member (so `X agg.` also counts a plot record of `X` when
  `X` is an expert taxon of its own).
- Expert files: `EUNIS/2025-10-03-EuroSL`, `Apennine-test/2026-06-27-EuroSL`
  (default versions), built by `data-raw/build_eurosl_experts.R`. Report of
  every used name: `data-raw/eurosl-congruence/*_names_used.tsv`
  (renamed / unchanged / kept, not in backbone; `review` flags fuzzy and
  rank-changing renames).
- Section 1 congruence lists carry `importance` (used in Sections 2/3 and a
  concept mismatch = important).

Open, needs expert decisions:
- 54 EUNIS `X aggr.` names without a EuroSL aggregate (e.g. Narcissus
  pseudonarcissus, Hedera helix, Satureja montana, Cyanus triumfettii): add the
  aggregate to EuroSL or use the species. Until then plot records of these
  species do not count (reported as "expert taxon not in backbone").
- 213 EUNIS names kept as written (not in EuroSL): see `*_names_used.tsv`.
- Genus-level members (171 in Section 2, formerly "X species" = records
  determined to genus only) now take all species of the genus that the expert
  file does not name itself.
- 787 EuroSL placements missing (e.g. Rubus microspecies directly under the
  genus instead of sect. Rubus): fix in EuroSL.
- 158 renames flagged for review (fuzzy spelling, rank changed, e.g.
  Betula alba -> Betula pubescens var. pubescens).
- renv.lock does not contain vegdata 2.0.0 yet.

## Package transition (2026-11-25)

- Deprecated (removal in 0.4): `resy_resolve_taxa()`, `resy_read_synonyms()`,
  `resy_canonical_species()`, `resy_clean_names()`, `resy_classify(resolve_taxa,
  synonyms)`, `resy_harmonize_eunis(run_taxonomy, species_data, parsed)`.
  With them go in 0.4: `inst/extdata/esy_synonym_layer*`, `example_crosswalk.csv`,
  `data-raw/build_synonyms.R` and its log/lock, the `synonym_layer_*` columns of
  `resy_provenance()`.
- Kept: Section 1 aggregation path for the published releases.
- `inst/extdata/eurosl_example.csv.xz` (556 KB, `data-raw/build_eurosl_example.R`)
  reproduces the full-EuroSL results of the example data; used by vignettes,
  README, tests.
- Backbone source order: `options(resy.backbone)` -> vegdata's installed list
  (read by vegdata). Cached as RDS in the RESY cache dir (installed builds only).
- eurosl.infinitenature.org still serves the zip of 2025-02-11, which
  `vegdata::taxref_download_eurosl()` installs; it lacks the version field.
- Next: web App and Maker (Section 1 backbone field, compact backbone file
  instead of the synonym layer in webR).

## Web App and Maker (2026-11-25)

- No vegdata in webR: RESY's light matching (exact, author removed, agg. only
  to aggregates; no fuzzy). Same types as vegdata matching for 198/200 example
  plots (EUNIS); the rest are misspellings.
- Bundle (pkgdown/build_webr_bundle.R, RESY_BACKBONE=<EuroSL.sqlite>):
  extdata/backbone/<scheme>/<version>.rds (EuroSL restricted to the system,
  with lookup keys and resolved expert names precomputed; EUNIS 1.1 MB),
  extdata/parsed/<scheme>/<version>.rds (pre-parsed systems), image `backbone`
  = whole EuroSL (2.4 MB) on demand. Synonym-layer image removed.
- Names outside a restricted backbone: status outside_expert_taxa (unimportant)
  unless genus+epithet equal an expert name.
- Not yet tested in a browser.
