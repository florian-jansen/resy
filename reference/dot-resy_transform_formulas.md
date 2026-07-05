# Apply solver-required formula transformations to a parsed expert system

Takes raw aggregations, groups, membership formulas and formula names
(as produced by either the text or JSON section parsers) and applies all
transformations needed by the solver: \#T\$ completion, GR NON insertion
for bare \##D/##C/##Q expressions, EXCEPT completion for \#SC
conditions, and OR-prefix expansion.

## Usage

``` r
.resy_transform_formulas(
  aggs,
  groups,
  membership.formulas,
  membership.formula.names
)
```

## Arguments

- aggs:

  Named list of species aggregations (Section 1).

- groups:

  Named list of species groups (Section 2). Names must carry the \`"###
  "\`, \`"##D "\`, \`"\$\$C "\` or \`"\$\$N "\` prefix.

- membership.formulas:

  Character vector of raw Section 3 formula strings.

- membership.formula.names:

  Character vector of formula name strings in the format
  \`"\<priority\>\<10 chars padding\>\<code\> \<description\>"\`.

## Value

A list with elements \`aggs\`, \`groups\`, \`membership.expressions\`,
\`group.defs\`, \`formulas\`, and \`membership.priority\`.
