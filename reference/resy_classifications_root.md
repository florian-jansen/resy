# Classification storage roots

Returns the root directory where classifications are stored. Built-in
classifications ship inside the package (read-only after install).
User-added classifications are stored in a user-writable data directory.

## Usage

``` r
resy_classifications_root(location = c("user", "package"), create = FALSE)
```

## Arguments

- location:

  One of \`"user"\` or \`"package"\`.

- create:

  Logical; if \`TRUE\` and \`location = "user"\`, create the directory
  if it does not yet exist. Ignored for \`"package"\`.

## Value

A path string.
