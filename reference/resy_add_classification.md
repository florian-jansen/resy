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

Invisibly, a named list with the paths of the files written:

- \`txt\`:

  Path to the stored \`.txt\` file, or \`NULL\` for JSON input.

- \`json\`:

  Path to the stored \`.json\` file, or \`NULL\` for \`.txt\` input.

## Details

The file is stored as \`\<root\>/\<scheme\>/\<version\>/expert.txt\` or
\`expert.json\`, where \`\<root\>\` is \`tools::R_user_dir("RESY",
"data")\` for \`location = "user"\`. A \`.txt\` file is stored
unchanged, together with a \`metadata.json\` sidecar recording the
scheme, version, source path and time of storage. Replacing a
classification with \`overwrite = TRUE\` removes the files of the
previous one, so a \`.txt\` never sits beside a stale \`.json\` that
\[resy_load_expert()\] would read first.

## See also

\[resy_validate_esy()\], \[resy_load_expert()\],
\[resy_available_classifications()\]

## Examples

``` r
# Store the bundled Apennine-test system under a new name. The store is
# redirected to a temporary directory here; by default it lives in
# tools::R_user_dir("RESY", "data").
old <- Sys.getenv("R_USER_DATA_DIR")
Sys.setenv(R_USER_DATA_DIR = tempfile("resy_store"))

src   <- resy_expert_path("Apennine-test", "2026-06-27")
paths <- resy_add_classification(src, scheme = "MyApennine",
                                 version = "2026-09-21")
basename(paths$json)
#> [1] "expert.json"

# The stored system is now found by scheme and version.
parsed <- resy_load_expert(scheme = "MyApennine", version = "2026-09-21")
parsed$vegtype.formula.names.short
#> [1] "F"  "FB" "N"  "NG" "NS"

Sys.setenv(R_USER_DATA_DIR = old)
```
