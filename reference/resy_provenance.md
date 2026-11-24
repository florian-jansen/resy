# Which expert system and synonym layer produced a result

**\[experimental\]** Reports the expert-system release a parsed expert
system or a classification result rests on, so it can be stored next to
the result or cited: the scheme and version, the file that was read, the
MD5 checksum of its content, the DOI of the published release, and
whether the file is byte-identical to the published `.txt`. For a result
of
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)
with `resolve_taxa = TRUE` and the bundled synonym layer, the build date
of that layer and the [taxify](https://github.com/gcol33/taxify) version
it was built with are added.

## Usage

``` r
resy_provenance(x)
```

## Arguments

- x:

  A `resy_parsed_expert` from
  [`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md)
  or a `resy_result` from
  [`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md).

## Value

A one-row data frame with columns `scheme`, `version`, `expert_file`,
`expert_md5`, `release_doi`, `identical_to_release`,
`synonym_layer_built`, `synonym_layer_taxify` and `resy_version`.
`identical_to_release` is `NA` when no published release of that scheme
and version is known (for example a user's own system); the
`synonym_layer_*` columns are `NA` when no synonym layer was used.

## See also

[`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md),
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md)

## Examples

``` r
resy_provenance(resy_load_expert(scheme = "EUNIS", version = "2021-06-01"))
#>   scheme    version   expert_file                       expert_md5
#> 1  EUNIS 2021-06-01 expert.txt.xz 775ea4542b1ef7a7ea23e9f1dac01bc6
#>              release_doi identical_to_release synonym_layer_built
#> 1 10.5281/zenodo.4812736                 TRUE                <NA>
#>   synonym_layer_taxify resy_version
#> 1                 <NA>          0.3
```
