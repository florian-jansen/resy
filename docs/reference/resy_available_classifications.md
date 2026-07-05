# List available classifications

Lists available classifications and their versions. See
\[resy_add_classification()\] if you want to add a new expert text file.

## Usage

``` r
resy_available_classifications(locations = c("package", "user"))
```

## Arguments

- locations:

  Where to search (any of "user", "package").

## Value

Data frame with columns: scheme, version, location, expert_json,
expert_txt, expert_rds.
