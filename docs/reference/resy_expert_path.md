# Get path to a bundled or user classification file

Get path to a bundled or user classification file

## Usage

``` r
resy_expert_path(
  scheme,
  version,
  format = c("rds", "txt"),
  location = c("user", "package"),
  mustWork = TRUE
)
```

## Arguments

- scheme:

  Classification scheme, e.g. "EUNIS".

- version:

  Version identifier, e.g. "2025-10-03".

- format:

  One of "rds", "txt".

- location:

  One of "user" or "package".

- mustWork:

  Logical; if TRUE, error when the requested file does not exist.

## Value

A file path.
