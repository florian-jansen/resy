# Aggregate taxa to expert-system aggregation level

Replaces \`obs\$TaxonName\` by aggregated names if they occur in the
aggregation mapping of the expert system. If you use GermanSl or EuroSL,
use \`taxval\` instead.

## Usage

``` r
resy_aggregate_taxa(obs, aggs)
```

## Arguments

- obs:

  A \`data.table\` with column \`TaxonName\`.

- aggs:

  Named list of aggregations as returned by \[resy_parse_expert()\].

## Value

Modified \`obs\` as \`data.table\`.
