# Resolve Species Taxonomy via TNRS

This function takes a data frame of species names and validates them
against the Taxonomic Name Resolution Service (TNRS) using the World
Checklist of Vascular Plants (WCVP) as the primary source.

## Usage

``` r
check_taxonomy(species)
```

## Arguments

- species:

  A data frame containing a column named `species` with botanical names
  to be checked.

## Value

A data frame containing all columns of the original input with the TNRS
taxonomic match columns appended.

## Details

The function submits the species list to the TNRS API. It specifically
retrieves the submitted name and the matched taxonomic results, then
joins these back to the original data frame. Note that this function
relies on positional indexing for TNRS results (columns 2, 5, and 34),
which assumes the TNRS API output format remains consistent.

## Warning

This function uses hard-coded column indices (`c(2, 5, 34)`) to subset
TNRS results. If the TNRS API or the `TNRS` package updates its output
structure, this function may require manual adjustment.
