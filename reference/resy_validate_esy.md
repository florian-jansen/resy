# Validate an expert classification file

Checks an ESy expert file (\`.txt\` or \`.json\`) for structural and
syntactic problems. Does not assess ecological correctness. The rules
are:

\*\*Errors\*\* (always fatal — the file cannot be imported):

1.  All required sections / top-level keys must be present and, for
    \`.txt\`, in the correct order (Section 1 \< 2 \< 3).

2.  Every vegetation type must have a non-empty code with no whitespace.

3.  Every vegetation type must have a formula / expression.

4.  Every formula must contain at least one membership condition
    `<...>`.

5.  Brackets inside formulas must be balanced (`()`, `[]`,
    [`{}`](https://rdrr.io/r/base/Paren.html)).

6.  Priority must be a single character in `0-9`, `A-Z` or `a-z`.

7.  Group keys in Section 2 / `"groups"` must start with a recognised
    prefix (`###`, `##D`, `#TC`, `#SC`, `$$C`, `$$N`).

\*\*Warnings\*\* (errors when `strict = TRUE`):

1.  Duplicate vegetation type codes.

2.  Group names referenced in formulas that are not defined.

3.  Dangling logical operators (`AND`/`OR`/`NOT` at the start or end of
    a formula).

4.  Legacy relational operator `UP` (deprecated in JUICE 7.0).

5.  For \`.txt\`: relational operators found outside `<...>` angle
    brackets.

6.  For \`.json\`: missing or empty `metadata.scheme` /
    `metadata.version`.

7.  Empty description for a vegetation type.

## Usage

``` r
resy_validate_esy(path, strict = FALSE, verbose = TRUE)
```

## Arguments

- path:

  Path to a \`.txt\` or \`.json\` expert file.

- strict:

  Logical; if \`TRUE\`, treat warnings as errors.

- verbose:

  Logical; if \`TRUE\` (default), print a one-line summary.

## Value

A list with:

- \`ok\`:

  \`TRUE\` when no errors were found.

- \`errors\`:

  Character vector of error messages.

- \`warnings\`:

  Character vector of warning messages.

- \`meta\`:

  Named list: \`path\`, and counts of groups and vegetation types
  defined.

## See also

\[resy_read_expert()\], \[resy_load_expert()\],
\[resy_add_classification()\]
