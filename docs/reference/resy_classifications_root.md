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

  One of "user" or "package".

- create:

  Logical; create directory (only applies to location="user").

## Value

A path.
