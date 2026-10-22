# List possible assignments per plot

The result object returned by \[resy_classify()\] contains a long table
of all vegetation types that were evaluated as possible for each plot
(i.e. the corresponding vegtype formula evaluated to \`TRUE\`).

This helper lets you access, sort, and filter those candidates.

## Usage

``` r
resy_candidates(
  res,
  plot_id = NULL,
  priority = NULL,
  min_priority = NULL,
  top_n = NULL,
  wide = FALSE
)
```

## Arguments

- res:

  A \`resy_result\` returned by \[resy_classify()\].

- plot_id:

  Optional plot id (character or numeric). If \`NULL\`, returns
  candidates for all plots.

- priority:

  Optional priority \*rank\* (integer). If provided, only candidates
  with \`priority_rank == priority\` are returned.

- min_priority:

  Optional minimum priority \*rank\* (integer). Higher means higher
  priority. If provided, only candidates with \`priority_rank \>=
  min_priority\` are returned.

- top_n:

  Optional maximum number of candidates to return per plot, the highest
  priorities first.

- wide:

  Logical. If \`TRUE\`, returns one row per plot with its classification
  and its candidate types side by side, highest priority first.

## Value

A \`tibble\` with columns \`plot_id\`, \`type\`, \`priority\`,
\`priority_rank\`. With \`wide = TRUE\`, a \`data.table\` with one row
per plot and columns \`plot_id\`, \`classification\`, then \`type_1\`,
\`priority_1\`, \`type_2\`, \`priority_2\`, ...; a plot with fewer
candidates has \`NA\` in the remaining columns.
