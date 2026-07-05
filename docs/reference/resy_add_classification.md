# Add a new classification to the RESY store

Validates and copies an ESy expert file (\`.txt\` or \`.json\`) into the
RESY classification store so that it becomes available to
\[resy_load_expert()\] and \[resy_classify()\].

The file is validated with \[resy_validate_esy()\] before anything is
written. If validation fails the function stops with a message that
lists every error found, so you can fix the file and try again. Pass
\`validate = FALSE\` to skip validation (not recommended).

## Usage

``` r
resy_add_classification(
  file,
  scheme,
  version,
  location = c("user", "package"),
  overwrite = FALSE,
  validate = TRUE
)
```

## Arguments

- file:

  Path to an ESy expert file (\`.txt\` or \`.json\`).

- scheme:

  Scheme name to store under (e.g. \`"MyClassification"\`).

- version:

  Version string to store under (e.g. \`"2026-07-05"\`).

- location:

  Where to store: \`"user"\` (default, recommended) or \`"package"\`
  (requires a writable library).

- overwrite:

  Logical; overwrite an existing classification. Defaults to \`FALSE\`.

- validate:

  Logical; run \[resy_validate_esy()\] before storing. Defaults to
  \`TRUE\`. Set to \`FALSE\` only if you are certain the file is valid.

## Value

A named list with the paths of the files written:

- \`txt\`:

  Path to the stored \`.txt\` file, or \`NULL\` for JSON input.

- \`json\`:

  Path to the stored \`.json\` file.

## See also

\[resy_validate_esy()\], \[resy_load_expert()\],
\[resy_available_classifications()\]
