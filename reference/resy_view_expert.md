# Render an expert-system hierarchy and open it in a browser

Builds the self-contained HTML tree (see
[`resy_write_expert_html`](https://florian-jansen.github.io/resy/reference/resy_write_expert_html.md))
in a temporary file and opens it in the default browser. Use
[`resy_write_expert_html`](https://florian-jansen.github.io/resy/reference/resy_write_expert_html.md)
directly to keep the file.

## Usage

``` r
resy_view_expert(
  expert,
  section = 3L,
  fill = TRUE,
  open_level = 1L,
  title = NULL,
  names = NULL,
  name_tag = NULL,
  browse = interactive()
)
```

## Arguments

- expert:

  Either a `resy_expert` object (from
  [`resy_read_expert`](https://florian-jansen.github.io/resy/reference/resy_read_expert.md))
  or a `resy_expert_tree` (from
  [`resy_expert_tree`](https://florian-jansen.github.io/resy/reference/resy_expert_tree.md)).

- section:

  Integer; the definition section to use when `expert` is a
  `resy_expert`. Defaults to `3`. Ignored for a `resy_expert_tree`.

- fill:

  Logical; reconstruct the intermediate group levels (see
  [`resy_expert_tree`](https://florian-jansen.github.io/resy/reference/resy_expert_tree.md)).
  Defaults to `TRUE` for the view, so the page shows a single tree
  rooted in the formation groups. Ignored for a `resy_expert_tree`,
  which is already built.

- open_level:

  Integer; nodes at this level or shallower start expanded. Defaults to
  `1` (the top groups are open, their contents collapsed).

- title:

  Page title; defaults to the section name.

- names:

  Optional code-to-name lookup for nodes the expert leaves unnamed (see
  [`resy_expert_tree`](https://florian-jansen.github.io/resy/reference/resy_expert_tree.md));
  pass
  [`resy_eunis_names`](https://florian-jansen.github.io/resy/reference/resy_eunis_names.md)
  for EUNIS. Ignored for a `resy_expert_tree`, which is already built.

- name_tag:

  Optional short label shown beside names supplied through `names` (for
  example `"EUNIS"`), to mark them apart from the expert's own
  descriptions. Defaults to `NULL` (no tag).

- browse:

  Logical; open the file in a browser. Defaults to
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

## Value

The path to the written HTML file, invisibly.

## See also

[`resy_expert_tree`](https://florian-jansen.github.io/resy/reference/resy_expert_tree.md)
for the underlying data frame.

## Examples

``` r
if (FALSE) { # \dontrun{
f <- system.file("extdata/classifications/Meadow-ESy-2025-01-18-2025.txt",
                 package = "RESY")
resy_view_expert(resy_read_expert(f))
} # }
```
