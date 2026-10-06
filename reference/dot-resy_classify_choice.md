# Resolve Multiple Classification Results to a Single Choice

Selects a single vegetation type classification when multiple expert
system rules have been triggered. Uses a priority-based resolution
strategy to determine the most appropriate classification outcome.

## Usage

``` r
.resy_classify_choice(
  type_short_names,
  vegtype.priority,
  vegtype.formula.names.short
)
```

## Arguments

- type_short_names:

  character vector of matched classification short names (e.g.,
  vegetation type abbreviations) from triggered expert system rules.

- vegtype.priority:

  factor with ordered priority levels defining the hierarchy for
  resolving classification conflicts. Lower priority levels (earlier in
  the factor levels) take precedence.

- vegtype.formula.names.short:

  character vector of all known vegetation type short names in the
  expert system, in the same order as the priority values in
  \`vegtype.priority\`.

## Value

character scalar representing the chosen classification: - A vegetation
type short name if a single highest-priority match is found - \`"?"\` if
no classifications are provided - \`"+"\` if multiple classifications
share the highest priority level

## Details

This function implements a conflict resolution mechanism for cases where
a vegetation plot satisfies the criteria of multiple classification
rules simultaneously. The resolution strategy prioritizes
classifications according to a predefined priority hierarchy:

\- If no classifications match: returns \`"?"\` - If exactly one
classification matches: returns that classification - If multiple match:
selects the one with the highest priority (lowest priority level in the
hierarchy) - If multiple classifications share the highest priority:
returns \`"+"\` to indicate ambiguity

The priority hierarchy is examined from highest to lowest level,
selecting the first (highest-priority) classification that appears
uniquely at its level. This ensures deterministic, consistent
classification outcomes.

## Examples

``` r
# No matches
.resy_classify_choice(character(), c(1, 2, 3), c("T1", "T2", "T3"))
#> Error in .resy_classify_choice(character(), c(1, 2, 3), c("T1", "T2",     "T3")): could not find function ".resy_classify_choice"

# Single match
.resy_classify_choice("T1", c(1, 2, 3), c("T1", "T2", "T3"))
#> Error in .resy_classify_choice("T1", c(1, 2, 3), c("T1", "T2", "T3")): could not find function ".resy_classify_choice"

# Multiple matches with clear priority
.resy_classify_choice(
  c("T2", "T3"),
  factor(c(1, 2, 3), levels = c(1, 2, 3)),
  c("T1", "T2", "T3")
)
#> Error in .resy_classify_choice(c("T2", "T3"), factor(c(1, 2, 3), levels = c(1,     2, 3)), c("T1", "T2", "T3")): could not find function ".resy_classify_choice"

# Multiple matches with conflicting priorities
.resy_classify_choice(
  c("T1", "T2"),
  factor(c(1, 1, 3), levels = c(1, 3)),
  c("T1", "T2", "T3")
)
#> Error in .resy_classify_choice(c("T1", "T2"), factor(c(1, 1, 3), levels = c(1,     3)), c("T1", "T2", "T3")): could not find function ".resy_classify_choice"
```
