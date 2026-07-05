# Load a classification

RESY always uses a compiled RDS for classification runs. If the RDS does
not exist yet, it is compiled automatically (by default into user
storage).

## Usage

``` r
resy_load_expert(
  expertfile = NULL,
  scheme = "EUNIS",
  version = NULL,
  location = c("user", "package"),
  rebuild = FALSE
)
```

## Arguments

- expertfile:

  Optional expert definition file. Can be \`.rds\`, or \`.txt\`.

- scheme:

  Scheme name.

- version:

  Version identifier. If NULL, the latest available version for the
  scheme is used.

- location:

  Where to look first (c("user","package") or c("package","user")).

- rebuild:

  Logical; if TRUE, rebuild RDS from source even if it exists.

## Value

Parsed expert object.
