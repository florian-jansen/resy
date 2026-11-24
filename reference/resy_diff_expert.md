# What changed between two expert systems

**\[experimental\]** Compares two expert systems, for example two
releases of EUNIS-ESy, and lists every aggregate, species group and type
that was added, removed or changed. Systems are compared after parsing,
so a `.txt` and a `.json` file can be compared with each other and
differences in layout or line endings do not count as changes.

## Usage

``` r
resy_diff_expert(from, to, scheme = "EUNIS")
```

## Arguments

- from, to:

  The two expert systems: a `resy_parsed_expert` from
  [`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md),
  the path of an expert file, or a version of `scheme` available to
  [`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md)
  (see
  [`resy_available_classifications()`](https://florian-jansen.github.io/resy/reference/resy_available_classifications.md)).

- scheme:

  Scheme of `from` and `to` when they are given as versions.

## Value

A data frame of class `resy_expert_diff`, one row per change, with
columns

- `section`:

  `"aggregate"` (Section 1 aggregation of taxa), `"group"` (Section 2
  species group) or `"type"` (Section 3 definition).

- `key`:

  Aggregate name, group name or type code.

- `change`:

  `"added"`, `"removed"` or `"changed"`.

- `what`:

  For a changed aggregate or group, the members that were added (`+`)
  and removed (`-`); for a changed type, which of `priority`, `name` and
  `formula` changed.

- `from`, `to`:

  For a type, the definition (priority, name and formula) in each
  system; `NA` where the type is absent. For an aggregate or group, the
  number of members.

[`print()`](https://rdrr.io/r/base/print.html) shows the number of
changes per section; [`summary()`](https://rdrr.io/r/base/summary.html)
lists the changed keys.

## See also

[`resy_load_expert()`](https://florian-jansen.github.io/resy/reference/resy_load_expert.md),
[`resy_available_classifications()`](https://florian-jansen.github.io/resy/reference/resy_available_classifications.md)

## Examples

``` r
# \donttest{
d <- resy_diff_expert("2020-06-08", "2021-06-01")
d
#> Changes from EUNIS 2020-06-08 (expert.txt.xz) to EUNIS 2021-06-01 (expert.txt.xz):
#>    section added removed changed
#>  aggregate   180      18     214
#>      group    34      31      47
#>       type    41      28      15
summary(d)
#> Changes from EUNIS 2020-06-08 (expert.txt.xz) to EUNIS 2021-06-01 (expert.txt.xz):
#>    section added removed changed
#>  aggregate   180      18     214
#>      group    34      31      47
#>       type    41      28      15
#> 
#> aggregate added (180):
#>   Acantholimon pulverulentum, Achillea atrata, Achillea pannonica,
#>   Achnatherum bromoides aggr., Aeonium davidbramwellii, Agrostis canina
#>   aggr., Alchemilla colorata, Alchemilla velebitica, Allium vineale,
#>   Ambrosia psilostachya, Androsace maxima, Aquilegia atrata, Aquilegia
#>   vulgaris, Arenaria norvegica, Argyranthemum pinnatifidum, Armeria
#>   multiceps, Asparagus trichophyllus, Asperula staliana, Asphodelus
#>   lusitanicus, Astragalus epiglottis, Astragalus gaeobotrys, Athyrium
#>   species, Atriplex glauca, Bassia tomentosa, Brachythecium collinum,
#>   Brachythecium trachypodium, Bryoerythrophyllum recurvirostrum,
#>   Bryonia cretica, Bryum archangelicum, Bryum bicolor aggr.
#>   ... and 150 more
#> 
#> group added (34):
#>   Coastal-saltmarsh-specialists, D +01 MA211-Arctic-coastal-saltmarsh,
#>   D +01 MA221-Atlantic-saltmarsh-driftline, D +01
#>   MA222-Atlantic-upper-saltmarsh, D +01
#>   MA223-Atlantic-upper-mid-saltmarsh-and-saline-and-brackish-reed-rush-and-sedge-bed,
#>   D +01 MA224-Atlantic-mid-low-saltmarsh, D +01
#>   MA225-Atlantic-pioneer-saltmarsh, D +01 MA232-Baltic-coastal-meadow,
#>   D +02 MA241-Black-Sea-littoral-saltmarsh, D +02
#>   MA251-Mediterranean-upper-saltmarsh, D +02
#>   MA252-Mediterranean-upper-mid-saltmarsh-and-saline-and-brackish-reed-rush-and-sedge-bed,
#>   D +02 MA253-Mediterranean-mid-low-saltmarsh, D +03
#>   U2a-Siliceous-high-mountain-scree, D +03 U2b-Siliceous-lowland-scree,
#>   D +03 U2c-Base-rich-high-mountain-scree, D +03
#>   U2d-Base-rich-lowland-scree, D +03 U3C-Macaronesian-inland-cliff, D
#>   +03 U3D-Wet-inland-cliff, D +03 U3a-Siliceous-high-mountain-cliff, D
#>   +03 U3b-Siliceous-lowland-cliff, D +03
#>   U3c-Base-rich-high-mountain-cliff, D +03 U3d-Base-rich-lowland-cliff,
#>   D +03 U52-Polar-desert, D +03 U61-Subarctic-volcanic-field, D +03
#>   U62-Mediterranean-and-temperate-volcanic-field, D
#>   +10Arcto-alpine-rich-fen-species, D
#>   +10Calcareous-non-quaking-fen-species, D +10Calcareous-quaking-mire,
#>   D +10Extremely-rich-moss-sedge-fen-species, D
#>   +10Intermediate-fen-and-soft-water-spring-mire
#>   ... and 4 more
#> 
#> type added (41):
#>   MA211, MA221, MA222, MA223, MA224, MA225, MA232, MA241, MA251, MA252,
#>   MA253, N31!, U21, U22, U23, U24, U25, U26, U27, U28, U29, U2A, U31,
#>   U32, U33, U34, U35, U36, U37, U38
#>   ... and 11 more
#> 
#> aggregate changed (214):
#>   Abietinella abietina, Acantholimon ulicinum, Aconitum degenii,
#>   Adenocarpus complicatus, Adenostyles alpina, Aegilops geniculata,
#>   Aethionema saxatile, Aira caryophyllea, Alchemilla vulgaris aggr.,
#>   Allium ampeloprasum, Allium callimischon, Allium oleraceum, Allium
#>   sphaerocephalon, Androsace villosa, Anemonastrum narcissiflorum,
#>   Anthemis secundiramea, Anthyllis hermanniae, Anthyllis vulneraria,
#>   Arenaria armerina, Argentina anserina, Arisarum vulgare, Armeria
#>   alliacea, Armeria alpina, Armeria arenaria, Armeria langei,
#>   Arrhenatherum elatius, Asperula aristata, Asplenium scolopendrium,
#>   Asplenium seelosii, Asplenium trichomanes
#>   ... and 184 more
#> 
#> group changed (47):
#>   Alpine-acidophilous-herbs, Canary-Island-xerophytic-scrub-species,
#>   Chamaephytes, Crops, D +01
#>   N21-Atlantic-Baltic-and-Arctic-coastal-shingle-beach, D +01
#>   N31-Atlantic-and-Baltic-rocky-sea-cliff-and-shore, D +02
#>   N12-Mediterranean-and-Black-Sea-sand-beach, D +02
#>   N16-Mediterranean-and-Macaronesian-coastal-dune-grassland-grey-dune,
#>   D +02 N22-Mediterranean-and-Black-Sea-coastal-shingle-beach, D +04
#>   C22b-Permanent-non-tidal-fast-turbulent-watercourse-of-plains-montane-regions-with-Ranunculus,
#>   D +04 C25a-Temperate-temporary-running-watercourse, D +04
#>   C35d-Unvegetated-or-sparsely-vegetated-shore-with-mobile-sediments-in-montane-alpine-regions,
#>   D +04
#>   N16-Mediterranean-and-Macaronesian-coastal-dune-grassland-grey-dune,
#>   D +04 Q54-Inland-saline-or-brackish-helophyte-bed, D +04
#>   R12-Cryptogam-and-annual-dominated-vegetation-on-siliceous-rock-outcrops,
#>   D +04 R17-Heavy-metal-dry-grassland-of-the-Balkans, D +04
#>   R1B-Continental-dry-grassland-true-steppe, D +04
#>   R1L-Madeiran-oromediterranean-siliceous-dry-grassland, D +04
#>   R1T-Azorean-open-dry-acid-to-neutral-grassland, D +04
#>   R42-Boreal-and-arctic-acidophilous-alpine-grassland, D +04
#>   R43-Temperate-acidophilous-alpine-grassland, D +04
#>   R62-Continental-inland-salt-steppe, D +04
#>   R63-Temperate-inland-salt-marsh, D +04 R64-Semi-desert-salt-pan, D
#>   +04 V32-Mediterranean-subnitrophilous-annual-grassland, D +04
#>   V33-Dry-mediterranean-lands-with-unpalatable-non-vernal-herbaceous-vegetation,
#>   D +04 V39a-Annual-anthropogenic-herb-stands, D +04
#>   V39c-Mesic-perennial-anthropogenic-herb-stands, D +05
#>   Alder-carr-species, D +05 Eutrophic-deciduous-forest-species
#>   ... and 17 more
#> 
#> type changed (15):
#>   N31, Q24, Q41, Q42, Q43, Q44, Q45, Q46, R1A, R1B, R1B!, R44, T3A,
#>   T3F, T3G
#> 
#> aggregate removed (18):
#>   Atocion armeria, Atocion rupestre, Brachytheciastrum velutinum,
#>   Cerastium alpinum, Cerastium nigrescens aggr., Cherleria baldaccii,
#>   Cherleria biflora, Cherleria capillacea, Cherleria circassica,
#>   Cherleria garckeana, Cherleria handelii, Descurainia preauxiana var.
#>   briquetii, Dryopteris carthusiana, Dryopteris expansa, Galium
#>   estebanii, Limonium binervosum, Pyankovia brachiata, Scleropodium
#>   tourretii
#> 
#> group removed (31):
#>   D +01 A25a-Arctic-coastal-salt-marsh, D +01
#>   A25b-Baltic-coastal-meadow, D +01 A25c-Atlantic-coastal-salt-marsh, D
#>   +02 A25d-Mediterranean-and-Black-Sea-coastal-salt-marsh, D +03
#>   H21-Boreal-and-arctic-siliceous-scree-and-block-field, D +03
#>   H22-Boreal-and-arctic-base-rich-scree-and-block-field, D +03
#>   H23-Temperate-high-mountain-siliceous-scree, D +03
#>   H24-Temperate-high-mountain-base-rich-scree-and-moraine, D +03
#>   H25-Temperate-lowland-to-montane-siliceous-scree, D +03
#>   H26a-Temperate-lowland-to-montane-base-rich-scree, D +03
#>   H26b-Western-Mediterranean-base-rich-scree, D +03
#>   H26c-Eastern-Mediterranean-base-rich-scree, D +03
#>   H31a-Boreal-and-arctic-siliceous-inland-cliff, D +03
#>   H31b-Temperate-high-mountain-siliceous-inland-cliff, D +03
#>   H31c-Temperate-lowland-to-montane-siliceous-inland-cliff, D +03
#>   H31d-Mediterranean-siliceous-inland-cliff, D +03
#>   H32a-Boreal-and-arctic-base-rich-inland-cliff, D +03
#>   H32b-Temperate-high-mountain-base-rich-inland-cliff, D +03
#>   H32c-Temperate-lowland-to-montane-base-rich-inland-cliff, D +03
#>   H32d-Mediterranean-base-rich-inland-cliff, D +03
#>   H32ef-Ultramafic-inland-cliff, D +03
#>   H32g-Mediterranean-ultramafic-inland-cliff, D +03
#>   H33-Macaronesian-inland-cliff, D +03 H34-Wet-inland-cliff, D +03
#>   H51b-Polar-desert, D +03
#>   H61-Mediterranean-and-temperate-volcanic-field, D +10
#>   Arcto-alpine-rich-fen-species, D +10
#>   Calcareous-non-quaking-fen-species, D +10 Calcareous-quaking-mire, D
#>   +10 Extremely-rich-moss-sedge-fen-species
#>   ... and 1 more
#> 
#> type removed (28):
#>   A25a, A25b, A25c, A25d, H21, H22, H23, H24, H25, H26a, H26b, H26c,
#>   H31a, H31b, H31c, H31d, H32a, H32b, H32c, H32d, H32e, H32f, H32g,
#>   H33, H34, H51b, H61, H
subset(d, section == "type" & change == "added")
#> Changes from EUNIS 2020-06-08 (expert.txt.xz) to EUNIS 2021-06-01 (expert.txt.xz):
#>    section added removed changed
#>  aggregate     0       0       0
#>      group     0       0       0
#>       type    41       0       0
# }
```
