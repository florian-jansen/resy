# Load a classification

**\[experimental\]** Loads a parsed expert-system object ready for use
with
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md).

If `expertfile` is given it takes precedence over `scheme`/`version`.
The file format is detected from the extension:

- `.json`, `.json.xz`:

  Parsed directly via the internal JSON parser (preferred); `.json.xz`
  is xz-compressed JSON.

- `.txt`:

  Parsed via the legacy text parser.

When no `expertfile` is supplied, the function looks for `expert.json`
(or `expert.json.xz`), then `expert.txt` (or `expert.txt.xz`), in that
order, under `<root>/<scheme>/<version>/`, where the roots are searched
in the order given by `location`: classifications stored with
[`resy_add_classification()`](https://florian-jansen.github.io/resy/reference/resy_add_classification.md)
(`"user"`) and the classifications shipped with the package
(`"package"`).

A loaded system is kept in RESY's cache directory
(`tools::R_user_dir("RESY", "cache")`), so that loading the same file
again restores it instead of parsing it. The cached copy is used only
while the file keeps its size and modification time and the same
installed version of RESY loads it; storing a new copy removes the older
ones of that file. Set `options(RESY.cache = FALSE)` to parse every
time, or `options(RESY.cache_dir = <path>)` to keep the cache elsewhere.

## Usage

``` r
resy_load_expert(
  expertfile = NULL,
  scheme = "EUNIS",
  version = NULL,
  location = c("user", "package")
)
```

## Arguments

- expertfile:

  Optional path to a `.json` or `.txt` file.

- scheme:

  Classification scheme name (default `"EUNIS"`).

- version:

  Version identifier. If `NULL`, the newest available version is used.

- location:

  Where to look for `scheme`/`version`, in search order. One or both of
  `"user"` and `"package"`; the default searches both, user first, so a
  user-stored classification takes precedence over a shipped one with
  the same scheme and version.

## Value

A list of class `resy_parsed_expert`. Its scheme, version and file, and
whether the file is byte-identical to the published release, are
reported by
[`resy_provenance()`](https://florian-jansen.github.io/resy/reference/resy_provenance.md).

## See also

[`resy_available_classifications()`](https://florian-jansen.github.io/resy/reference/resy_available_classifications.md),
[`resy_add_classification()`](https://florian-jansen.github.io/resy/reference/resy_add_classification.md),
[`resy_provenance()`](https://florian-jansen.github.io/resy/reference/resy_provenance.md)

## Examples

``` r
expert <- resy_load_expert(scheme = "Apennine-test")
expert$vegtype.formula.names
#> [1] "F     Forest"                              
#> [2] "FB    Beech-fir montane forest"            
#> [3] "N     Non-forest"                          
#> [4] "NG    Nardus acidic grassland"             
#> [5] "NS    Sub-Mediterranean scrub and woodland"
```
