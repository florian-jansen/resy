# Write an expert-system hierarchy to a self-contained HTML page

Writes the classification hierarchy built by
[`resy_expert_tree`](https://florian-jansen.github.io/resy/reference/resy_expert_tree.md)
to a single, self-contained HTML file: a collapsible tree built from
native `<details>` elements, with an in-page filter and expand/collapse
controls. The page has no external dependencies – no JavaScript library,
no web fonts, no separate asset files – so it opens identically in any
browser and can be shared as one file.

## Usage

``` r
resy_write_expert_html(
  expert,
  file,
  section = 3L,
  fill = TRUE,
  open_level = 1L,
  title = NULL,
  names = NULL,
  name_tag = NULL
)
```

## Arguments

- expert:

  Either a `resy_expert` object (from
  [`resy_read_expert`](https://florian-jansen.github.io/resy/reference/resy_read_expert.md))
  or a `resy_expert_tree` (from
  [`resy_expert_tree`](https://florian-jansen.github.io/resy/reference/resy_expert_tree.md)).

- file:

  Path to the HTML file to write.

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

## Value

The `file` path, invisibly.

## See also

[`resy_view_expert`](https://florian-jansen.github.io/resy/reference/resy_view_expert.md)
to write and open in one call.

## Examples

``` r
f <- system.file("extdata/classifications/Meadow-ESy-2025-01-18-2025.txt",
                 package = "RESY")
if (nzchar(f)) {
  out <- file.path(tempdir(), "expert-tree.html")
  resy_write_expert_html(resy_read_expert(f), out)
}
```
