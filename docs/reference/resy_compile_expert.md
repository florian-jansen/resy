# Compile a classification to RDS

Creates (or updates) \`expert.rds\` for a given classification version.
The compiled RDS is stored in the selected location (default: user
storage).

## Usage

``` r
resy_compile_expert(
  scheme,
  version,
  location = c("user", "package"),
  overwrite = FALSE
)
```

## Arguments

- scheme:

  Scheme name.

- version:

  Version identifier.

- location:

  Where to write the compiled RDS ("user" recommended).

- overwrite:

  Logical; overwrite existing expert.rds.

## Value

The compiled object (invisibly).
