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
  # code followed by the description, separated by a space where the header
  # has none (a code filling the five-character field).
  vegtype.formula.names <- trimws(sub("^[0-9A-Za-z]\\s+", "", names(vegtype.formulas), perl = TRUE))
  vegtype.formula.names.short <- .resy_parse_definition_header(names(vegtype.formulas))$code
  n <- nchar(vegtype.formula.names.short)
  abut <- !is.na(n) & grepl("^\\S", substring(vegtype.formula.names, n + 1L))
  vegtype.formula.names[abut] <- paste(vegtype.formula.names.short[abut],
                                       substring(vegtype.formula.names[abut], n[abut] + 1L))

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

# Members of each header-led block of a section: the non-blank lines after a
# header, up to the next header or the end of the section. Blank lines separate
# blocks and are never members. `clean` tidies the member lines.
.resy_block_members <- function(lines, header_idx, clean = .resy_trim_leading) {
  owner <- findInterval(seq_along(lines), header_idx)
  keep <- owner > 0L & !seq_along(lines) %in% header_idx & .resy_has_text(lines)
  unname(split(clean(lines[keep]),
               factor(owner[keep], levels = seq_along(header_idx))))
}

# TRUE for lines holding more than blanks, tabs and line ends.
.resy_has_text <- function(x) grepl("[^ \t\r\n]", x, perl = TRUE)

# Body of section `n`: the lines between its opener and its "SECTION n: End".
# `marks` restricts the search to rows known to hold a section marker.
.resy_section_body <- function(lines, n, marks = seq_along(lines)) {
  at <- marks[.resy_section_rows(lines[marks], n)]
  lines[(at[1] + 1):(at[2] - 1)]
}

.resy_parse_expert_lines <- function(expert) {
  # Drop everything after the first tab (TSV compatibility) and '---' lines
  tab <- grep("\t", expert, fixed = TRUE)
  expert[tab] <- sub("\t.*$", "", expert[tab], perl = TRUE)
  expert <- expert[!grepl("---", expert, fixed = TRUE)]
  marks <- grep("^\\s*SECTION\\s+\\d", expert, ignore.case = TRUE, perl = TRUE)

  # ---- Section 1: Species aggregation
  species.agg     <- .resy_section_body(expert, 1, marks)
  index.agg.names <- which(substr(species.agg, 1, 1) != " " & .resy_has_text(species.agg))
  index.agg.names <- index.agg.names[
    !grepl("^[ \t\r\n]*SECTION\\s+\\d", species.agg[index.agg.names], perl = TRUE)
  ]
  aggs <- .resy_block_members(species.agg, index.agg.names,
                              clean = function(x) .resy_trim_trailing(.resy_trim_leading(x)))
  names(aggs) <- .resy_trim_trailing(species.agg[index.agg.names])
  if (any(!nzchar(names(aggs)))) aggs <- aggs[nzchar(names(aggs))]

  # ---- Section 2: Species groups
  species.groups    <- .resy_section_body(expert, 2, marks)
  index.group.names <- which(substr(species.groups, 1, 1) != " " & .resy_has_text(species.groups))
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
  # priority character (a digit or a letter) followed by the type code; the
  # lines after it, up to the next header or blank line, are its formula.
  group.definitions <- .resy_section_body(expert, 3, marks)
  is.header <- .resy_is_definition_header(group.definitions)

  membership.formula.names <- NULL
  membership.formulas      <- NULL
  i <- 0
  while (i < length(group.definitions)) {
    i <- i + 1
    if (substr(group.definitions[i], 1, 3) != "---") {
      if (is.header[i]) {
        membership.formula.names <- c(membership.formula.names, group.definitions[i])
      } else {
        formula <- group.definitions[i]
        while (i < length(group.definitions) &&
               nzchar(group.definitions[i + 1]) && !is.header[i + 1] &&
               substr(group.definitions[i + 1], 1, 1) != "-") {
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
