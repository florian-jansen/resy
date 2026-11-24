# Validate an expert classification file

Checks an ESy expert file (`.txt` or `.json`) for structural and
syntactic problems. Does not assess ecological correctness. Both formats
are read into the same parts (species groups and type definitions) and
checked by the same rules; only the checks of the file layout differ
between them.

**Errors** (always fatal: the file cannot be imported):

1.  All required sections / top-level keys must be present and, for
    `.txt`, in the correct order (Section 1 \< 2 \< 3).

2.  At least one vegetation type must be defined.

3.  Every vegetation type must have a non-empty code with no whitespace.

4.  Every vegetation type must have a formula / expression.

5.  Every formula must contain at least one membership condition
    `<...>`.

6.  Brackets inside formulas must be balanced (`()`, `[]`,
    [`{}`](https://rdrr.io/r/base/Paren.html)).

7.  A formula must not start or end with a logical operator
    (`AND`/`OR`/`NOT`).

8.  Priority must be a single character in `0-9`, `A-Z` or `a-z`.

9.  Group keys in Section 2 / `"groups"` must start with a recognised
    prefix (`###`, `##D`, `##Q`, `##C`, `$$C`, `$$N`) followed by a
    name.

10. For `.txt`: no relational operator outside `<...>` angle brackets.

11. For `.json`: every rule has the keys `priority`, `code`,
    `description` and `expression`.

**Warnings** (errors when `strict = TRUE`):

1.  Duplicate vegetation type codes.

2.  Species groups referenced in formulas that are not defined. Groups
    are resolved the way the classifier resolves them; header columns
    (`$$C`, `$$N`) and the names after `EXCEPT`, which may be single
    species, are not checked.

3.  Legacy relational operator `UP` (deprecated in JUICE 7.0).

4.  Empty description for a vegetation type.

**Notes** (warnings also when `strict = TRUE`):

1.  For `.txt`: tab characters (only the text before the first tab of a
    line is used).

2.  For `.json`: missing or empty `metadata.scheme` /
    `metadata.version`.

## Usage

``` r
resy_validate_esy(path, strict = FALSE, verbose = TRUE)
```

## Arguments

- path:

  Path to a `.txt` or `.json` expert file.

- strict:

  Logical; if `TRUE`, treat warnings as errors.

- verbose:

  Logical; if `TRUE` (default), print a one-line summary.

## Value

A list with:

- `ok`:

  `TRUE` when no errors were found.

- `errors`:

  Character vector of error messages.

- `warnings`:

  Character vector of warning messages.

- `meta`:

  Named list: `path`, and counts of groups and vegetation types defined.

## See also

[`resy_read_expert()`](https://florian-jansen.github.io/resy/reference/resy_read_expert.md),
[`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md),
[`resy_add_classification()`](https://florian-jansen.github.io/resy/reference/resy_add_classification.md)

## Examples

``` r
# Validate a .txt file
result <- resy_validate_esy(
system.file("extdata", "example_mini_expert_file.txt", package = "RESY"
), strict = FALSE)
#> ESy validation: OK
if (!result$ok) print(result$errors)
```
