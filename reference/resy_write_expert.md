# Write an expert-system file

Serialises a `resy_expert` tree (as returned by
[`resy_read_expert`](https://florian-jansen.github.io/resy/reference/resy_read_expert.md))
back to a `.txt` file. The round-trip is byte-identical: for any file
`f`, `resy_write_expert(resy_read_expert(f), out)` reproduces `f`
exactly, including line endings and trailing newline.

The output reproduces the source the tree was read from. This is the
inverse of
[`resy_read_expert`](https://florian-jansen.github.io/resy/reference/resy_read_expert.md)
and keeps the `.txt` format the canonical, editable representation an
expert system can be shared in.

## Usage

``` r
resy_write_expert(x, file)
```

## Arguments

- x:

  An object of class `resy_expert`.

- file:

  Path to write to.

## Value

Invisibly returns `file`.

## See also

[`resy_read_expert`](https://florian-jansen.github.io/resy/reference/resy_read_expert.md)
for the inverse operation.

## Examples

``` r
if (FALSE) { # \dontrun{
f <- "/path/to/EUNIS-ESy-2025-10-03.txt"
x <- resy_read_expert(f)
out <- tempfile(fileext = ".txt")
resy_write_expert(x, out)
identical(readBin(f, "raw", file.info(f)$size),
          readBin(out, "raw", file.info(out)$size))
} # }
```
