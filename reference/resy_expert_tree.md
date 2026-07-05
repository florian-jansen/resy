# Build the classification hierarchy of an expert system

Turns the type definitions of a `resy_expert` object (Section 3, the
"Group definitions") into a hierarchy.

With `fill = FALSE` (the default) the tree uses only the codes the
expert defines: a definition nests under another when its code has that
other code as its longest prefix among all codes present, so an EUNIS
file with codes `R`, `R1` and `R12` nests `R12` under `R1` under `R`,
while codes with no present prefix stay top-level. No levels are
invented, which keeps the hierarchy faithful to files that define only a
flat code list.

With `fill = TRUE` the intermediate group levels implied by the code
grammar are reconstructed: each code is split into its ancestor path by
`code_path`, and any ancestor the expert does not define is added as a
structural group node (marked in the `synthetic` column). For EUNIS this
yields a single tree rooted in the formation groups (`M`, `N`, `Q`, `R`,
...) with every type at its proper depth.

## Usage

``` r
resy_expert_tree(
  expert,
  section = 3L,
  fill = FALSE,
  code_path = .resy_code_path,
  names = NULL
)
```

## Arguments

- expert:

  A `resy_expert` object from
  [`resy_read_expert`](https://florian-jansen.github.io/resy/reference/resy_read_expert.md),
  read with `entries = TRUE` (the default).

- section:

  Integer; the section number holding the type definitions. Defaults to
  `3`, the EUNIS-ESy convention.

- fill:

  Logical; if `TRUE`, reconstruct the intermediate group levels implied
  by the codes. Defaults to `FALSE`.

- code_path:

  Function mapping one code to the character vector of its ancestor
  codes from the root down to and including the code itself. Used only
  when `fill = TRUE`. The default splits a code into one level per
  character (`"Q11"` becomes `c("Q", "Q1", "Q11")`, `"MA1"` becomes
  `c("M", "MA", "MA1")`), which matches the EUNIS code grammar.

- names:

  Optional code-to-name lookup used to label nodes that the expert
  leaves unnamed (typically the synthesised group levels). Either a
  named character vector (names are codes) or a data frame whose first
  two columns are code and name.
  [`resy_eunis_names`](https://florian-jansen.github.io/resy/reference/resy_eunis_names.md)
  returns the official EUNIS habitat names in this form. Defaults to
  `NULL` (no external names).

## Value

An object of class `resy_expert_tree`: a data frame with one row per
node and columns `id`, `parent` (`NA` for top-level nodes), `code`,
`description`, `priority`, `expression`, `level` (1 for top-level
nodes), `leaf`, `synthetic` (`TRUE` for a reconstructed group node the
expert does not define) and `name_source` (`"expert"`, `"lookup"` or
`""`). A `print` method renders it as an indented text tree.

## See also

[`resy_write_expert_html`](https://florian-jansen.github.io/resy/reference/resy_write_expert_html.md)
and
[`resy_view_expert`](https://florian-jansen.github.io/resy/reference/resy_view_expert.md)
to render the hierarchy as a self-contained interactive HTML page.

## Examples

``` r
f <- system.file("extdata/classifications/Meadow-ESy-2025-01-18-2025.txt",
                 package = "RESY")
if (nzchar(f)) {
  expert <- resy_read_expert(f)
  print(resy_expert_tree(expert))            # codes as defined
  print(resy_expert_tree(expert, fill = TRUE)) # with group levels filled in
}
```
