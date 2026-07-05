# Build the resy_parsed_expert object from a raw parsing result list.
# Called by the text parser path (below) and resy_parse_json().
.resy_build_parsed <- function(parsing.result) {
  aggs                   <- parsing.result$aggs
  groups                 <- parsing.result$groups
  groups.names           <- substr(names(groups), 5, nchar(names(groups)))
  membership.expressions <- unique(parsing.result$membership.expressions)
  conditions             <- parsing.result$group.defs
  vegtype.formulas       <- parsing.result$formulas
  vegtype.priority       <- parsing.result$membership.priority

  vegtype.formula.names       <- trimws(substr(names(vegtype.formulas), 12, nchar(names(vegtype.formulas))))
  # Extract the code as the first whitespace-delimited token. This is robust to
  # any code length (the spec says 5 chars, but actual files may differ).
  vegtype.formula.names.short <- sub("^(\\S+).*$", "\\1", vegtype.formula.names)

  # Replace inner expressions with col1, col2, ... to make formulas parseable in R
  o <- order(nchar(membership.expressions), decreasing = TRUE)
  vegtype.formulas.p <- stringi::stri_replace_all_fixed(
    vegtype.formulas,
    pattern       = membership.expressions[o],
    replacement   = paste0("col", seq_along(membership.expressions))[o],
    vectorize_all = FALSE
  )

  vegtype.formulas.p <- gsub("<",   "",   vegtype.formulas.p)
  vegtype.formulas.p <- gsub(">",   "",   vegtype.formulas.p)
  vegtype.formulas.p <- gsub("AND", "&",  vegtype.formulas.p)
  vegtype.formulas.p <- gsub("OR",  "|",  vegtype.formulas.p)
  vegtype.formulas.p <- gsub("NOT", "&!", vegtype.formulas.p)
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

parse.classification.expert.file <- function(expertfile) {
  expert <- readLines(expertfile, warn = FALSE, encoding = "UTF-8")
  parse.classification.expert.vector(expert)
}

parse.classification.expert.vector <- function(expert) {
  # Drop everything after the first tab (TSV compatibility) and '---' lines
  expert <- sub("\t.*$", "", expert)
  expert <- expert[!grepl("---", expert)]

  # ---- Section 1: Species aggregation
  section1        <- grep("SECTION 1", expert)
  species.agg     <- expert[(section1[1] + 1):(section1[2] - 1)]
  index.agg.names <- which(
    substr(species.agg, 1, 1) != " " &
    nzchar(trimws(species.agg)) &
    !grepl("^SECTION\\s+\\d", trimws(species.agg))
  )
  number.agg   <- length(index.agg.names)
  ind.agg.names <- c(index.agg.names, length(species.agg) + 1)
  aggs <- lapply(seq_len(number.agg), function(x)
    trim.leading(species.agg[(ind.agg.names[x] + 1):(ind.agg.names[x + 1] - 1)])
  )
  names(aggs) <- trim.trailing(species.agg[index.agg.names])
  if (any(!nzchar(names(aggs)))) aggs <- aggs[nzchar(names(aggs))]
  for (i in seq_along(aggs))
    aggs[[i]] <- sapply(aggs[[i]], trim.trailing, USE.NAMES = FALSE)

  # ---- Section 2: Species groups
  section2          <- grep("SECTION 2", expert)
  species.groups    <- expert[(section2[1] + 1):(section2[2] - 1)]
  index.group.names <- which(substr(species.groups, 1, 1) != " " & nzchar(trimws(species.groups)))
  number.groups     <- length(index.group.names)
  gr                <- c(index.group.names, length(species.groups))
  groups <- lapply(seq_len(number.groups), function(x)
    trim.leading(species.groups[(gr[x] + 1):(gr[x + 1] - 1)])
  )
  names(groups) <- species.groups[index.group.names]

  if (!all(substr(names(groups), 1, 3) %in% c("###", "##D", "##Q", "##C", "$$C", "$$N")))
    stop(paste(
      'Only "###", "##D", "##Q", "##C", "$$N", and "$$C" are known group prefixes. Found:',
      paste(unique(substr(names(groups), 1, 3)), collapse = ", ")
    ))

  discr <- substr(names(groups)[startsWith(names(groups), "+")], 2, 3)
  if (any(table(discr) < 2))
    stop(paste("Discriminating set", names(table(discr)[table(discr) < 2]), "occurs only once!"))

  # ---- Section 3: Parse raw formulas
  section3          <- grep("SECTION 3", expert)
  group.definitions <- expert[(section3[1] + 1):(section3[2] - 1)]

  membership.formula.names <- NULL
  membership.expressions   <- NULL
  membership.formulas      <- NULL
  i <- 0
  while (i < length(group.definitions)) {
    i <- i + 1
    if (substr(group.definitions[i], 1, 3) != "---") {
      if (nzchar(trimws(group.definitions[i])) &&
          !grepl("[^0-9]", substr(group.definitions[i], 1, 1))) {
        membership.formula.names <- c(membership.formula.names, group.definitions[i])
      } else {
        c <- group.definitions[i]
        while (grepl("[^0-9]", substr(group.definitions[i + 1], 1, 1)) &&
               substr(group.definitions[i + 1], 1, 1) != "-" &&
               i < length(group.definitions)) {
          i <- i + 1
          c <- paste(c, group.definitions[i], sep = " ")
        }
        a <- gregexpr("<", c, fixed = TRUE)[[1]]
        b <- gregexpr(">", c, fixed = TRUE)[[1]]
        if (a[1] > 0) {
          membership.formulas <- c(membership.formulas, c)
          exprs2 <- character(length(a))
          for (j in seq_along(a)) exprs2[j] <- substr(c, a[j] + 1, b[j] - 1)
          membership.expressions <- c(membership.expressions, exprs2)
        }
      }
    }
  }

  .resy_transform_formulas(aggs, groups, membership.formulas, membership.formula.names)
}
