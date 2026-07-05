# Read an expert-system file losslessly

Parses an expert-system definition file (the EUNIS-ESy `.txt` format and
compatible expert systems) into a structured tree that preserves the
source byte-for-byte.

This is the lossless counterpart to `resy_parse_expert`. Where
`resy_parse_expert` rewrites the formulas into the solver's internal
form (and is therefore one-way), `resy_read_expert` retains the file's
structure verbatim for inspection or conversion to other formats.

## Usage

``` r
resy_read_expert(file, entries = TRUE)
```

## Arguments

- file:

  Path to an expert-system `.txt` file (for example an official release
  such as `EUNIS-ESy-2025-10-03.txt`).

- entries:

  Logical, default `TRUE`. If `TRUE`, each known section also carries a
  structured `entries` view of its content (aggregations, groups,
  definitions). If `FALSE` only the raw lines are kept, which is faster
  when the goal is a pure round-trip and the semantic view is not
  needed.

## Value

An object of class `resy_expert`: a list with components

- `meta`:

  File-level metadata: `line_terminator` (CRLF or LF) and
  `trailing_newline` (whether the file ends with a terminator).

- `preamble`:

  Character vector of any lines before the first `SECTION` header.

- `sections`:

  A list, in source order, of section objects. Each has `number`,
  `name`, `header_line`, `body_lines`, `end_line` (`NA` when the section
  has no matching `SECTION N: End`), `trailing` (lines between this
  section's end and the next section or end of file), and, when
  `entries = TRUE` and the section type is known, `entries`: a
  structured view of the section content.

## See also

`resy_parse_expert` for the solver-form parser.

## Examples

``` r
if (FALSE) { # \dontrun{
f <- "/path/to/EUNIS-ESy-2025-10-03.txt"
x <- resy_read_expert(f)
length(x$sections)
} # }
```
