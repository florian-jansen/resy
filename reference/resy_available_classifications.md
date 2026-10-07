# List available classifications

Lists the classification schemes and versions bundled with the package
(under \`inst/extdata/classifications/\`).

## Usage

``` r
resy_available_classifications()
```

## Value

A data frame with columns \`scheme\`, \`version\`, \`expert_json\`,
\`expert_txt\`. The \`expert\_\*\` columns contain the full file path
when the file exists, otherwise \`NA\`.

## Details

The function scans the package's classification store directory
structure:

- Top-level directories represent classification schemes (e.g.,
  "EUNIS").

- Second-level directories represent versions within each scheme.

- Within each version directory, the function looks for \`expert.json\`
  and \`expert.txt\` files.

## See also

\[resy_load_expert()\], \[resy_add_classification()\],
\[resy_classify()\]

## Examples

``` r
# List all available classifications and their paths
resy_available_classifications()
#>          scheme    version
#> 1 Apennine-test 2026-06-27
#> 2         EUNIS 2025-10-03
#>                                                                                                                                                       expert_json
#> 1 /home/runner/.cache/R/renv/library/resy-ae7cf081/linux-ubuntu-noble/R-4.6/x86_64-pc-linux-gnu/RESY/extdata/classifications/Apennine-test/2026-06-27/expert.json
#> 2         /home/runner/.cache/R/renv/library/resy-ae7cf081/linux-ubuntu-noble/R-4.6/x86_64-pc-linux-gnu/RESY/extdata/classifications/EUNIS/2025-10-03/expert.json
#>   expert_txt
#> 1       <NA>
#> 2       <NA>
```
