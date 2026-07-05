# Add a new classification from a TXT expert file

Copies the TXT into the RESY classification store and generates the
corresponding JSON and RDS. By default, this writes into user storage
(recommended). Writing into the installed package directory typically
requires a writable library and is often not possible.

## Usage

``` r
resy_add_classification(
  txtfile,
  scheme,
  version,
  location = c("user", "package"),
  overwrite = FALSE
)
```

## Arguments

- txtfile:

  Path to expert TXT file.

- scheme:

  Scheme name to store under.

- version:

  Version identifier to store under.

- location:

  Where to store ("user" recommended).

- overwrite:

  Logical; overwrite existing files.

## Value

A named list with created file paths.
