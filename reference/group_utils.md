# Internal Group Parsing Utilities

Provides helper constants and functions for identifying section-2 group
markers used in RESY expert-system definitions. This file centralizes
the prefixes and parsing rules for species groups, differential groups,
and header variables.

## Details

RESY expert-system definitions use structured Section 2 group labels
with prefixes such as \`###\`, \`##D\`, \`##Q\`, \`##C\`, \`\$\$C\`, and
\`\$\$N\`. These helpers make it easier to:

\- recognize valid group markers, - extract the group name from a
prefixed key, - locate the line numbers of \`SECTION \<n\>\` markers in
parsed text.
