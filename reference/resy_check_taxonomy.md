# Check species names against an expert system's species list

Validates taxon names in a plot observation table against the canonical
names and synonyms declared in Section 1 of the loaded expert system.
Returns a per-taxon table of matches and canonical name mappings.

This is a purely offline check; no external name-resolution service is
called.

The result is a \`resy_taxa\` data frame. Printing it shows what each
column holds and how many names matched; \[summary()\] returns the match
counts and the unmatched names.

## Usage

``` r
resy_check_taxonomy(obs, parsed, col = "TaxonName")
```

## Arguments

- obs:

  A data frame or \`data.table\` with a column holding taxon names.

- parsed:

  A \`resy_parsed_expert\` object from \[resy_load_expert()\].

- col:

  Name of the column in \`obs\` that holds taxon names (default
  \`"TaxonName"\`).

## Value

A \`resy_taxa\` data frame with one row per unique taxon name in
\`obs\`:

- \`scientificName\`:

  The name as submitted in \`obs\`.

- \`TaxonName\`:

  The canonical name used by \[resy_classify()\], or \`NA\` when
  unmatched.

- \`matched\`:

  \`TRUE\` if the name was found as a canonical name or synonym in
  Section 1 of the expert system.

## See also

\[resy_load_expert()\], \[resy_harmonize_eunis()\]

## Examples

``` r
parsed <- resy_load_expert(scheme = "Apennine-test")

obs <- data.frame(
  PlotObservationID = c("p1", "p1", "p2"),
  TaxonName = c("Fagus sylvatica",     # canonical name
                "Abies alba Mill.",    # listed synonym of "Abies alba"
                "Planta inventa")      # unknown to the expert system
)
checked <- resy_check_taxonomy(obs, parsed)
checked
#> <resy_taxa> 3 name(s) from column `TaxonName` checked against 950 Section 1 species
#>   scientificName  name as submitted
#>   TaxonName       canonical name used by resy_classify(); NA when unmatched
#>   matched         TRUE if found as a canonical name or Section 1 synonym
#> 2 matched (66.7%), 1 unmatched; summary() lists them
#> 
#>     scientificName       TaxonName matched
#> 1  Fagus sylvatica Fagus sylvatica    TRUE
#> 2 Abies alba Mill.      Abies alba    TRUE
#> 3   Planta inventa            <NA>   FALSE
summary(checked)
#> 3 name(s): 2 matched (66.7%), 1 unmatched (33.3%)
#> Unmatched names:
#>   Planta inventa

# Names held in a differently named column
names(obs)[2] <- "species"
resy_check_taxonomy(obs, parsed, col = "species")
#> <resy_taxa> 3 name(s) from column `species` checked against 950 Section 1 species
#>   scientificName  name as submitted
#>   TaxonName       canonical name used by resy_classify(); NA when unmatched
#>   matched         TRUE if found as a canonical name or Section 1 synonym
#> 2 matched (66.7%), 1 unmatched; summary() lists them
#> 
#>     scientificName       TaxonName matched
#> 1  Fagus sylvatica Fagus sylvatica    TRUE
#> 2 Abies alba Mill.      Abies alba    TRUE
#> 3   Planta inventa            <NA>   FALSE
```
