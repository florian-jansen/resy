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
