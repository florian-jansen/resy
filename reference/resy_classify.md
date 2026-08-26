# Classify vegetation plots with the expert system

Loads an expert system (by file or by scheme/version), aggregates taxa,
evaluates the membership conditions, and returns plot classifications.

The classifier is taxonomy-agnostic: it classifies the species names in
\`obs\` as they are given. Names should already match the expert
system's vocabulary. If your plot data uses names from a general
backbone (GBIF, WFO, POWO, Euro+Med, a national checklist), harmonise
them first as an explicit step with \[resy_resolve_taxa\] and inspect
the result with \[resy_summarize_taxa\] before classifying, so the
taxonomic choices stay visible (see the taxonomy vignette). Setting
\`resolve_taxa = TRUE\` runs that resolution inside \`resy_classify()\`
as a convenience: names the expert already knows pass through untouched,
unknown names are looked up in the synonym table, and names that resolve
to nothing keep their original value (never a best guess). What was
resolved is then reported in the result's \`taxon_resolution\`.

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
  species_col = "TaxonName",
  resolve_taxa = FALSE,
  synonyms = NULL,
  mc = max(1L, floor(parallel::detectCores() * 0.75))
)
```

## Arguments

- obs:

  Observations as \`data.table\` with at least columns describing plot
  id, the species name (see \`species_col\`), and \`Cover_Perc\`.

- header:

  Plot header data.frame; required for evaluating \$\$C/\$\$N.

- expertfile:

  Optional path to expert-system file (.json/.txt). If set, takes
  precedence.

- scheme:

  Scheme name (default: "EUNIS").

- version:

  Version identifier. If NULL, uses latest available version for the
  scheme.

- location:

  Where to look for scheme/version "user" or "package".

- id_col:

  Optional name of the plot id column. If NULL, tries PlotObservationID,
  then PlotID.

- species_col:

  Name of the column in \`obs\` holding the species name (default
  \`"TaxonName"\`). Resolved names are written back to \`TaxonName\`.

- resolve_taxa:

  Logical; if \`FALSE\` (default) the classifier is taxonomy-agnostic
  and uses the names in \`obs\` as given. If \`TRUE\`, species names are
  resolved to the expert's vocabulary via \[resy_resolve_taxa\] before
  classification (see Description).

- synonyms:

  Synonym-table override passed to \[resy_resolve_taxa\] when
  \`resolve_taxa = TRUE\`; \`NULL\` uses the shipped table.

- mc:

  Number of CPU cores to use.

## Value

An object of class \`resy_result\`. When \`resolve_taxa = TRUE\` it also
carries a \`taxon_resolution\` summary from \[resy_summarize_taxa\];
otherwise \`taxon_resolution\` is \`NULL\`.

## See also

\[resy_resolve_taxa\], \[resy_summarize_taxa\]

## Examples

``` r
# \donttest{
# Classify the bundled example plots with the minimal Apennine-test scheme.
species <- utils::read.csv(
  system.file("extdata", "data_example_species.csv", package = "RESY")
)
names(species)[names(species) == "species"] <- "TaxonName"
names(species)[names(species) == "cover"]   <- "Cover_Perc"

# A one-row-per-plot header is required even without geographic conditions.
header <- as.data.frame(unique(species["PlotObservationID"]))

res <- resy_classify(species, header, scheme = "Apennine-test")
#> Step 5.1  Number of conditions with number of species of a group: 0
#> Step 5.2  Number of conditions with minimum number of species: 0
#> Step 5.3  Number of conditions with sum of square rooted Cover_Perc of species: 0
#> Step 5.4  Number of conditions with total Cover_Perc of the group: 0
#> Step 5.5  Number of conditions with total Cover_Perc of all other species: 0
#>           Number of conditions with total Cover_Perc of all other species except those on the left-hand side: 0
#>           Number of conditions with $05, $25 etc.: 0
#> Step 5.6  Number of conditions with maximum cover of the group: 0
#> Step 5.7  Number of conditions with single species, header levels (e.g. country names): 1
#> Step 5.8  Number of conditions with maximum Cover_Perc in plot: 0
#>           Number of conditions with maximum Cover_Perc in plot EXCEPT species of target group: 0
#> Step 5.9  Number of T$ NON conditions: 0
#> Step 5.10  Header conditions with numeric values: 0
#>   Header conditions with character values: 0
#> adapt conditions 2026-08-26 12:35:31.177765
#> classification from here on 2026-08-26 12:35:31.178523
head(res$result.classification)
#> HU32 KW76 YB18 NX70 OL48 YL40 
#>  "F"  "F"  "F"  "F"  "F"  "F" 
# }
```
