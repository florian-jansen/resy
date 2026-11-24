# Add a new classification to the RESY store

Validates and copies an ESy expert file (`.txt`, `.json`, or either
xz-compressed) into the RESY classification store so that it becomes
available to
[`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md)
and
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md).

Without `file`, the published release `scheme`/`version` is downloaded
from the source listed in the RESY release registry (Zenodo for
EUNIS-ESy), checked against its SHA-256 checksum and stored. The
registry is read from the RESY repository on GitHub, so a release
published after this version of RESY can be added without updating the
package. Downloading requires the
[getaca](https://CRAN.R-project.org/package=getaca) package.

A file you supply is validated with
[`resy_validate_esy()`](https://florian-jansen.github.io/resy/reference/resy_validate_esy.md)
before anything is written; a downloaded release is checked against its
published checksum instead. If validation fails the function stops with
a message that lists every error found, so you can fix the file and try
again. Pass `validate = FALSE` to skip validation (not recommended).

## Usage

``` r
resy_add_classification(
  file = NULL,
  scheme,
  version = NULL,
  location = c("user", "package"),
  overwrite = FALSE,
  validate = TRUE
)
```

## Arguments

- file:

  Path to an ESy expert file (`.txt`, `.json`, `.txt.xz` or `.json.xz`),
  or `NULL` to download the published release `scheme`/`version`.

- scheme:

  Scheme name to store under (e.g. `"MyClassification"`). With
  `file = NULL`, the scheme of the published release (e.g. `"EUNIS"`).

- version:

  Version string to store under (e.g. `"2026-07-05"`). With
  `file = NULL`, the version of the published release; `NULL` takes the
  newest one.

- location:

  Where to store: `"user"` (default, recommended) or `"package"`
  (requires a writable library).

- overwrite:

  Logical; overwrite an existing classification. Defaults to `FALSE`.

- validate:

  Logical; run
  [`resy_validate_esy()`](https://florian-jansen.github.io/resy/reference/resy_validate_esy.md)
  on `file` before storing. Defaults to `TRUE`. Set to `FALSE` only if
  you are certain the file is valid. Not used for a downloaded release.

## Value

Invisibly, a named list with the paths of the files written:

- `txt`:

  Path to the stored text file, or `NULL` for JSON input.

- `json`:

  Path to the stored JSON file, or `NULL` for text input.

## Details

The file is stored as `<root>/<scheme>/<version>/expert.txt`,
`expert.txt.xz`, `expert.json` or `expert.json.xz`, where `<root>` is
`tools::R_user_dir("RESY", "data")` for `location = "user"`. A text file
is stored unchanged, together with a `metadata.json` sidecar recording
the scheme, version, source path and time of storage. Replacing a
classification with `overwrite = TRUE` removes the files of the previous
one, so a `.txt` never sits beside a stale `.json` that
[`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md)
would read first.

## See also

[`resy_validate_esy()`](https://florian-jansen.github.io/resy/reference/resy_validate_esy.md),
[`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md),
[`resy_available_classifications()`](https://florian-jansen.github.io/resy/reference/resy_available_classifications.md)

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

if (FALSE) { # \dontrun{
# Download a published EUNIS-ESy release from Zenodo into the user store.
resy_add_classification(scheme = "EUNIS", version = "2025-10-03")
} # }
```
