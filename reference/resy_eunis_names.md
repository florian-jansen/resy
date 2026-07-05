# Official EUNIS habitat names

Returns the EUNIS habitat code-to-name lookup bundled with the package,
for use as the `names` argument of
[`resy_expert_tree`](https://florian-jansen.github.io/resy/reference/resy_expert_tree.md),
[`resy_write_expert_html`](https://florian-jansen.github.io/resy/reference/resy_write_expert_html.md)
and
[`resy_view_expert`](https://florian-jansen.github.io/resy/reference/resy_view_expert.md).
It lets the synthesised group levels of a reconstructed EUNIS-ESy tree
(which the expert system itself does not define) carry their official
habitat names.

The names are the official EUNIS 2021 habitat names (European
Environment Agency, EUNIS habitat classification), distributed here for
reference; they are not part of the expert system and are marked
separately when rendered.

## Usage

``` r
resy_eunis_names()
```

## Value

A data frame with columns `code` and `name`.

## Examples

``` r
head(resy_eunis_names())
#>    code                                name
#> 1     M    Littoral biogenic (salt marshes)
#> 2    MA                     Marine habitats
#> 3   MA2                     Marine habitats
#> 4  MA21   Arctic littoral biogenic habitats
#> 5 MA211            Arctic coastal saltmarsh
#> 6  MA22 Atlantic littoral biogenic habitats
```
