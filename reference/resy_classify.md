# Classify vegetation plots with the expert system

## Usage

``` r
resy_classify(
  obs,
  header,
  expertfile = NULL,
  scheme = "EUNIS",
  version = NULL,
  location = c("user", "package"),
  id_col = NULL,
  species_col = NULL,
  resolve_taxa = FALSE,
  synonyms = NULL,
  mc = max(1L, floor(parallel::detectCores() * 0.75))
)
```

## Arguments

- obs:

  Observations as a data frame or \`data.table\` with at least columns
  describing plot id, the species name (see \`species_col\`), and the
  cover \`Cover_Perc\`. Darwin Core names are accepted: \`eventID\` for
  the plot id, \`scientificName\` for the species, and
  \`organismQuantity\` for the cover when \`organismQuantityType\` is a
  percent cover such as \`"

  headerPlot header data frame with one row per plot; required for
  evaluating \$\$C/\$\$N. Darwin Core \`country\` is accepted for
  \`Country\`, and \`Altitude\` or Darwin Core
  \`minimumElevationInMeters\`/\`maximumElevationInMeters\` for
  \`Altitude (m)\`.

  expertfileOptional path to expert-system file (.json/.txt). If set,
  takes precedence.

  schemeScheme name (default: "EUNIS").

  versionVersion identifier. If NULL, uses latest available version for
  the scheme.

  locationWhere to look for \`scheme\`/\`version\`, in search order; see
  \[resy_load_expert()\]. Defaults to both \`"user"\` and \`"package"\`.

  id_colOptional name of the plot id column. If NULL, tries
  PlotObservationID, then PlotID, then Darwin Core eventID.

  species_colName of the column in \`obs\` holding the species name. If
  \`NULL\` (default), uses \`TaxonName\`, then Darwin Core
  \`scientificName\`. Resolved names are written back to \`TaxonName\`.

  resolve_taxaLogical; if \`FALSE\` (default) the classifier is
  taxonomy-agnostic and uses the names in \`obs\` as given. If \`TRUE\`,
  species names are resolved to the expert's vocabulary via
  \[resy_resolve_taxa\] before classification (see Description).

  synonymsSynonym-table override passed to \[resy_resolve_taxa\] when
  \`resolve_taxa = TRUE\`; \`NULL\` uses the shipped table.

  mcNumber of CPU cores to use.

An object of class \`resy_result\`. When \`resolve_taxa = TRUE\` it also
carries the \`summary()\` of the \[resy_resolve_taxa\] result as
\`taxon_resolution\`; otherwise \`taxon_resolution\` is \`NULL\`. Loads
an expert system (by file or by scheme/version), aggregates taxa,
evaluates the membership conditions, and returns plot
classifications.The classifier is taxonomy-agnostic: it classifies the
species names in \`obs\` as they are given. Names should already match
the expert system's vocabulary. If your plot data uses names from a
general backbone (GBIF, WFO, POWO, Euro+Med, a national checklist),
harmonise them first as an explicit step with \[resy_resolve_taxa\] and
inspect the result with its \`summary()\` before classifying, so the
taxonomic choices stay visible (see the taxonomy vignette). Setting
\`resolve_taxa = TRUE\` runs that resolution inside \`resy_classify()\`
as a convenience: names the expert already knows pass through untouched,
unknown names are looked up in the synonym table, and names that resolve
to nothing keep their original value (never a best guess). What was
resolved is then reported in the result's \`taxon_resolution\`.
\[resy_resolve_taxa\], \[resy_check_taxonomy\]
