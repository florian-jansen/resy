# Build the resy_parsed_expert object from a raw parsing result list.
# Called by the text parser path (below) and .resy_parse_json().
.resy_build_parsed <- function(parsing.result) {
  aggs                   <- parsing.result$aggs
  groups                 <- parsing.result$groups
  groups.names           <- .resy_group_name(names(groups))
  membership.expressions <- unique(parsing.result$membership.expressions)
  conditions             <- parsing.result$group.defs
  vegtype.formulas       <- parsing.result$formulas
  vegtype.priority       <- parsing.result$membership.priority

  # Name of a type: its header line without the priority character, i.e. the
  # code followed by the description.
  vegtype.formula.names <- trimws(sub("^[0-9A-Za-z]\\s+", "", names(vegtype.formulas), perl = TRUE))
  vegtype.formula.names.short <- sub("^(\\S+).*$", "\\1", vegtype.formula.names)

  # Replace inner expressions with col1, col2, ... to make formulas parseable in R
  vegtype.formulas.p <- .resy_formula_to_r(vegtype.formulas, membership.expressions)
  logexpr.formula <- lapply(vegtype.formulas.p, function(x) parse(text = x)[[1]])

  structure(
    list(
      parsing.result              = parsing.result,
      aggs                        = aggs,
      groups                      = groups,
      groups.names                = groups.names,
      membership.expressions      = membership.expressions,
      conditions                  = conditions,
      vegtype.formulas            = vegtype.formulas,
      vegtype.formulas.p          = vegtype.formulas.p,
      vegtype.priority            = vegtype.priority,
      vegtype.formula.names       = vegtype.formula.names,
      vegtype.formula.names.short = vegtype.formula.names.short,
      logexpr.formula             = logexpr.formula
    ),
    class = "resy_parsed_expert"
  )
}

# ---- Low-level text parser ---------------------------------------------------

.resy_parse_expert_file <- function(expertfile) {
  expert <- readLines(expertfile, warn = FALSE, encoding = "UTF-8")
  .resy_parse_expert_lines(expert)
}

# Members of each header-led block of a section: the non-blank lines after a
# header, up to the next header or the end of the section. Blank lines separate
# blocks and are never members.
.resy_block_members <- function(lines, header_idx) {
  ends <- c(header_idx[-1L] - 1L, length(lines))
  lapply(seq_along(header_idx), function(i) {
    n <- max(0L, ends[i] - header_idx[i])
    block <- lines[seq.int(header_idx[i] + 1L, length.out = n)]
    .resy_trim_leading(block[nzchar(trimws(block))])
  })
}

# Body of section `n`: the lines between its opener and its "SECTION n: End".
.resy_section_body <- function(lines, n) {
  at <- .resy_section_rows(lines, n)
  lines[(at[1] + 1):(at[2] - 1)]
}

.resy_parse_expert_lines <- function(expert) {
  # Drop everything after the first tab (TSV compatibility) and '---' lines
  expert <- sub("\t.*$", "", expert)
  expert <- expert[!grepl("---", expert)]

  # ---- Section 1: Species aggregation
  species.agg     <- .resy_section_body(expert, 1)
  index.agg.names <- which(
    substr(species.agg, 1, 1) != " " &
    nzchar(trimws(species.agg)) &
    !grepl("^SECTION\\s+\\d", trimws(species.agg))
  )
  aggs <- .resy_block_members(species.agg, index.agg.names)
  names(aggs) <- .resy_trim_trailing(species.agg[index.agg.names])
  if (any(!nzchar(names(aggs)))) aggs <- aggs[nzchar(names(aggs))]
  for (i in seq_along(aggs))
    aggs[[i]] <- vapply(aggs[[i]], .resy_trim_trailing, character(1), USE.NAMES = FALSE)

  # ---- Section 2: Species groups
  species.groups    <- .resy_section_body(expert, 2)
  index.group.names <- which(substr(species.groups, 1, 1) != " " & nzchar(trimws(species.groups)))
  groups            <- .resy_block_members(species.groups, index.group.names)
  names(groups) <- species.groups[index.group.names]

  if (!all(substr(names(groups), 1, 3) %in% .resy_group_prefixes))
    stop(paste(
      "Only", paste0('"', .resy_group_prefixes, '"', collapse = ", "),
      "are known group prefixes. Found:",
      paste(unique(substr(names(groups), 1, 3)), collapse = ", ")
    ))

  discr <- substr(names(groups)[startsWith(names(groups), "+")], 2, 3)
  if (any(table(discr) < 2))
    stop(paste("Discriminating set", names(table(discr)[table(discr) < 2]), "occurs only once!"))

  # ---- Section 3: Formula headers and formulas. A header starts with its
  # priority digit; the lines after it, up to the next header, are its formula.
  group.definitions <- .resy_section_body(expert, 3)

  membership.formula.names <- NULL
  membership.formulas      <- NULL
  i <- 0
  while (i < length(group.definitions)) {
    i <- i + 1
    if (substr(group.definitions[i], 1, 3) != "---") {
      if (nzchar(trimws(group.definitions[i])) &&
          !grepl("[^0-9]", substr(group.definitions[i], 1, 1))) {
        membership.formula.names <- c(membership.formula.names, group.definitions[i])
      } else {
        formula <- group.definitions[i]
        while (grepl("[^0-9]", substr(group.definitions[i + 1], 1, 1)) &&
               substr(group.definitions[i + 1], 1, 1) != "-" &&
               i < length(group.definitions)) {
          i <- i + 1
          formula <- paste(formula, group.definitions[i], sep = " ")
        }
        if (grepl("<", formula, fixed = TRUE))
          membership.formulas <- c(membership.formulas, formula)
      }
    }
  }

  .resy_transform_formulas(aggs, groups, membership.formulas, membership.formula.names)
}
