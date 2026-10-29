#' Evaluate and print details for a single plot
#'
#' @description
#' Prints, in plain words, why one plot is classified as it is: the
#' vegetation types whose rules hold for it with their priorities, the type it
#' is classified as, and its species. Below that it lists the lower-level types of the
#' classified type that the plot did not reach. Each is shown with its rule and
#' with every condition the rule uses: whether the condition is met, the value
#' the plot has, the value the condition requires, and the plot's species that
#' count towards it. This shows, for example, why a plot is `R2` and not `R22`.
#' A plot that matches no type is shown against the top-level types.
#'
#' In a rule, `[1]`, `[2]`, ... stand for the numbered conditions listed under
#' it, combined with `and`, `or` and `not` as the expert system combines them.
#'
#' @param res A `resy_result` returned by [resy_classify()].
#' @param p Plot identifier (`PlotObservationID`) as character; if numeric, treated as
#'   row index in `header`.
#' @param type Optional vegetation-type short code(s) to show in the same way,
#'   whether or not their rules hold for the plot.
#' @param lower Logical; if `TRUE` (default), list the lower-level types the
#'   plot did not reach, with their conditions.
#' @return `NULL`, invisibly. Called for the printed output.
#' @export
resy_eval_plot <- function(res, p, type = character(), lower = TRUE) {
  .resy_print_plot_evidence(.resy_plot_evidence(res, p, type, lower))
  invisible(NULL)
}

# Everything resy_eval_plot() says about one plot, as data: the types whose
# rule holds, the classification in words, the species, the lower levels not
# reached and the types asked for with `type`. The printer below and the RESY
# App both read this list.
.resy_plot_evidence <- function(res, p, type = character(), lower = TRUE) {
  stopifnot(inherits(res, "resy_result"))
  parsed <- res$parsed
  codes <- parsed$vegtype.formula.names.short

  if (is.numeric(p)) {
    warning('Plot numbers ("PlotObservationID") should be characters (indices), not numeric row numbers.')
    p <- as.character(res$header$PlotObservationID[p])
  } else {
    p <- as.character(p)
  }
  # logi1 and logi2 are in the solver's plot order, which need not be the row
  # order of `header`.
  plot <- .resy_plot_context(res, p, match(p, names(res$types)))
  ev <- list(id = p, species = plot$species, holds = NULL, sentence = NULL,
             lower = list(), types = list())

  if (!is.null(res$logi2)) {
    held <- which(vapply(res$logi2, function(x) isTRUE(x[plot$n]), logical(1)))
    typ <- unique(codes[held])
    choice <- .resy_classify_choice(typ, parsed$vegtype.priority, codes)
    ev$holds <- data.frame(code = typ,
                           priority = parsed$vegtype.priority[held[match(typ, codes[held])]],
                           stringsAsFactors = FALSE)
    ev$choice <- choice
    ev$sentence <- .resy_choice_sentence(choice, typ, parsed)
    if (isTRUE(lower)) {
      anchor <- if (choice == "+") typ else choice
      ev$lower <- lapply(anchor, function(a) .resy_lower_levels(res, plot, a))
    }
  }

  ev$types <- lapply(type, function(code) {
    t <- if (is.character(code)) which(codes == code) else integer()
    if (!length(t)) return(list(code = as.character(code), defined = FALSE))
    list(code = code, defined = TRUE,
         rules = lapply(t, function(i) .resy_type_evidence(res, plot, i)))
  })
  ev
}

.resy_print_plot_evidence <- function(ev) {
  if (!is.null(ev$sentence)) {
    if (nrow(ev$holds)) {
      cat("Types whose rule holds: ",
          paste0(ev$holds$code, " (priority ", ev$holds$priority, ")", collapse = ", "),
          "\n", sep = "")
    }
    cat(ev$sentence, "\n\n", sep = "")
  }

  cat("Plot ", ev$id, ": ", nrow(ev$species), " species\n", sep = "")
  print(ev$species, row.names = FALSE, right = FALSE)

  for (lv in ev$lower) .resy_print_lower_levels(lv)

  for (ty in ev$types) {
    cat("\n")
    if (!ty$defined) {
      cat("Type ", ty$code, " is not defined.\n", sep = "")
    } else {
      for (rule in ty$rules) .resy_print_type_evidence(rule)
    }
  }
}

# What the evidence printers need to know about one plot: its position `n` in
# the solver results, its species with cover (largest first), and its header row.
.resy_plot_context <- function(res, p, n) {
  obs <- res$obs[res$obs$PlotObservationID == p]
  species <- data.frame(species = trimws(as.character(obs$TaxonName)),
                        cover = obs$Cover_Perc, stringsAsFactors = FALSE)
  species <- species[order(-species$cover, species$species), , drop = FALSE]
  header_row <- res$header[match(p, as.character(res$header$PlotObservationID)), ,
                           drop = FALSE]
  list(id = p, n = n, species = species, header = header_row)
}

.resy_type_description <- function(parsed, t) {
  sub("^\\S+\\s*", "", parsed$vegtype.formula.names[t])
}

.resy_choice_sentence <- function(choice, typ, parsed) {
  codes <- parsed$vegtype.formula.names.short
  if (identical(choice, "?")) return("No type's rule holds, so the plot is not classified.")
  if (identical(choice, "+")) {
    return(paste0("Not classified: several types share the highest priority (",
                  paste(typ, collapse = ", "), ")."))
  }
  desc <- .resy_type_description(parsed, fastmatch::fmatch(choice, codes))
  why <- if (length(typ) > 1L) ", the type with the highest priority" else ""
  paste0("Classified as ", choice, " (", desc, ")", why, ".")
}

# The types one level below `anchor` (a short code; "?" stands for the top of
# the hierarchy) whose rule does not hold for the plot. Levels follow the code
# prefixes of the expert system, as in resy_expert_tree(). A code can carry
# several rules (EUNIS-ESy defines T3M by twelve); the type holds when any of
# them holds, and a type not reached is judged by its closest rule. The types
# are ordered by the share of conditions the plot satisfies, closest first, and
# the closest is described in full.
.resy_lower_levels <- function(res, plot, anchor) {
  parsed <- res$parsed
  codes <- parsed$vegtype.formula.names.short
  tree <- resy_expert_tree(parsed)
  parent_code <- tree$code[tree$parent]
  below <- unique(if (identical(anchor, "?")) tree$code[is.na(tree$parent)] else
    tree$code[!is.na(parent_code) & parent_code == anchor])
  out <- list(anchor = anchor, below = length(below), types = NULL, closest = NULL)
  holds <- function(t) isTRUE(res$logi2[[t]][plot$n])
  missed <- below[!vapply(below, function(code) any(vapply(which(codes == code), holds, logical(1))),
                          logical(1))]
  if (!length(missed)) return(out)

  per_code <- lapply(missed, function(code) {
    t <- which(codes == code)
    st <- lapply(t, function(i) .resy_condition_status(res, plot, i))
    k <- vapply(st, function(s) sum(s$satisfied), integer(1))
    m <- vapply(st, nrow, integer(1))
    best <- order(-k / pmax(m, 1L))[1L]
    data.frame(code = code, name = .resy_type_description(parsed, t[best]),
               rule = best, rules = length(t), satisfied = k[best], conditions = m[best],
               t = t[best], stringsAsFactors = FALSE)
  })
  types <- do.call(rbind, per_code)
  types <- types[order(-types$satisfied / pmax(types$conditions, 1L), types$code), , drop = FALSE]
  rownames(types) <- NULL
  out$closest <- .resy_type_evidence(res, plot, types$t[1L])
  out$types <- types[setdiff(names(types), "t")]
  out
}

# Prints the lower levels of one anchor: a single missed type in full; several
# one per line with how many of their conditions the plot satisfies, then the
# closest in full.
.resy_print_lower_levels <- function(lv) {
  cat("\n")
  if (!lv$below) {
    cat(lv$anchor, " has no lower levels.\n", sep = "")
    return(invisible(NULL))
  }
  if (is.null(lv$types)) return(invisible(NULL))
  heading <- if (identical(lv$anchor, "?")) "Top-level types not reached" else
    paste("Why not a lower level of", lv$anchor)
  ty <- lv$types
  if (nrow(ty) > 1L) {
    desc <- ifelse(nchar(ty$name) > 50L, paste0(substr(ty$name, 1L, 47L), "..."), ty$name)
    of_rules <- ifelse(ty$rules > 1L, sprintf(", closest of %d rules", ty$rules), "")
    cat(heading, ": ", nrow(ty), " types, closest first\n", sep = "")
    cat(sprintf("  %-5s %-50s %d of %d conditions satisfied%s\n",
                ty$code, desc, ty$satisfied, ty$conditions, of_rules), sep = "")
    cat("\nClosest, in full (show any other with `type = \"", ty$code[2L], "\"`):\n\n", sep = "")
  } else {
    cat(heading, ":\n\n", sep = "")
  }
  .resy_print_type_evidence(lv$closest)
  invisible(NULL)
}

# For type `t` and one plot: each condition of its rule in the order of
# .resy_rule_words(), whether it is met, whether the rule negates it, and
# whether it is satisfied in the rule's sense (met, or not met under `not`).
.resy_condition_status <- function(res, plot, t, rule = NULL) {
  if (is.null(rule)) rule <- .resy_rule_words(res$parsed$vegtype.formulas.p[t])
  met <- vapply(rule$cols, function(j) isTRUE(res$logi1[[j]][plot$n]), logical(1))
  negated <- rule$cols %in% rule$negated
  data.frame(col = rule$cols, met = met, negated = negated,
             satisfied = met != negated)
}

# Rule `t` (an index into the parsed expert system) for one plot: whether it
# holds, the rule with its conditions numbered, and each condition in words with
# its result, the plot's value, the required value, and the plot's species that
# count towards it. `status` is "met", "not met", or "excludes" for a met
# condition under `not`; `satisfied` is whether the condition counts for the rule.
.resy_type_evidence <- function(res, plot, t) {
  parsed <- res$parsed
  rule <- .resy_rule_words(parsed$vegtype.formulas.p[t])
  st <- .resy_condition_status(res, plot, t, rule)
  d <- lapply(rule$cols, function(j)
    .resy_describe_expression(parsed$membership.expressions[j], parsed, res, plot))
  list(
    code = parsed$vegtype.formula.names.short[t],
    name = .resy_type_description(parsed, t),
    holds = isTRUE(res$logi2[[t]][plot$n]),
    rule = rule$text,
    conditions = data.frame(
      status = ifelse(!st$met, "not met", ifelse(st$negated, "excludes", "met")),
      satisfied = st$satisfied,
      text = vapply(d, `[[`, character(1), "text"),
      species = vapply(d, function(x) if (length(x$species)) x$species else "", character(1)),
      stringsAsFactors = FALSE
    )
  )
}

.resy_print_type_evidence <- function(ev) {
  cat(sprintf("%-5s %s: %s\n", ev$code, ev$name, if (ev$holds) "rule holds" else "rule not met"))
  cat("      Rule: ", ev$rule, "\n", sep = "")
  cond <- ev$conditions
  for (i in seq_len(nrow(cond))) {
    cat(sprintf("      [%d] %-8s %s\n", i, cond$status[i], cond$text[i]))
    if (nzchar(cond$species[i])) {
      cat(sprintf("          %-8s %s\n", "", cond$species[i]))
    }
  }
  invisible(NULL)
}

# The compiled rule of a type (an R expression over col1, col2, ...) in words.
# The expression is parsed and walked, so `and`, `or`, `not` and brackets read
# exactly as the solver evaluates them; each column becomes [k], numbered in the
# order of first appearance. Returns the text and the column numbers in that order.
.resy_rule_words <- function(formula) {
  cols <- integer()
  negated <- integer()
  walk <- function(e, neg = FALSE) {
    if (is.name(e)) {
      j <- as.integer(sub("^col", "", as.character(e)))
      if (!j %in% cols) cols <<- c(cols, j)
      if (neg) negated <<- union(negated, j)
      return(paste0("[", match(j, cols), "]"))
    }
    if (!is.call(e)) return(as.character(e))
    op <- as.character(e[[1]])
    switch(op,
      "(" = paste0("(", walk(e[[2]], neg), ")"),
      "!" = paste("not", walk(e[[2]], !neg)),
      "&" = paste(walk(e[[2]], neg), "and", walk(e[[3]], neg)),
      "|" = paste(walk(e[[2]], neg), "or", walk(e[[3]], neg)),
      paste(deparse(e), collapse = " ")
    )
  }
  e <- parse(text = formula, keep.source = FALSE)[[1]]
  while (is.call(e) && identical(as.character(e[[1]]), "(")) e <- e[[2]]
  text <- walk(e)
  list(text = text, cols = cols, negated = negated)
}

# Words for one membership condition (an element of `parsed$conditions`), and
# the unit its value is measured in. Follows the condition kinds the solver
# distinguishes in .resy_solve_membership().
.resy_condition_words <- function(condition) {
  x <- trimws(condition)
  groups <- function(s, code) {
    parts <- .resy_membership_parts(s, prefix = code)
    parts <- sub("^\\+[0-9]+\\s+", "", parts)
    paste(parts, collapse = " and ")
  }
  except <- function(s, code) {
    p <- trimws(strsplit(s, "EXCEPT", fixed = TRUE)[[1]])
    out <- groups(p[1], code)
    if (length(p) > 1L) out <- paste0(out, " not counting ", groups(p[2], code))
    out
  }
  if (startsWith(x, "NON ")) {
    return(list(words = "highest sum of square-root covers of any other group in its set",
                unit = ""))
  }
  if (startsWith(x, "$$N") || startsWith(x, "$$C")) {
    return(list(words = trimws(substring(x, 4L)), unit = ""))
  }
  if (grepl("^\\$[0-9]+$", x)) {
    return(list(words = paste0(substring(x, 2L), "% of the total cover"), unit = "%"))
  }
  if (!startsWith(x, "#")) return(list(words = paste("cover of", x), unit = "%"))
  code <- substr(x, 1L, 3L)
  rest <- trimws(substring(x, 4L))
  if (code == "#T$") {
    w <- if (nzchar(rest)) paste("total cover of all species outside", groups(rest, "#T$")) else
      "total cover of all species"
    return(list(words = w, unit = "%"))
  }
  if (code == "#$$") {
    w <- if (nzchar(rest)) paste("highest cover of any species outside",
                                 groups(trimws(sub("^EXCEPT", "", rest)), NULL)) else
      "highest cover of any species"
    return(list(words = w, unit = "%"))
  }
  if (grepl("^#[0-9]{2}$", code)) {
    return(list(words = paste("at least", as.integer(substr(code, 2L, 3L)),
                              "species of", groups(rest, code)), unit = ""))
  }
  switch(code,
    "###" = , "##D" = list(words = paste("number of species of", except(rest, code)), unit = ""),
    "##Q" = list(words = paste("sum of square-root covers of", except(rest, code)), unit = ""),
    "##C" = list(words = paste("summed cover of", except(rest, code)), unit = "%"),
    "#TC" = list(words = paste("total cover of", except(rest, code)), unit = "%"),
    "#SC" = list(words = paste("highest cover of a single species of", except(rest, code)), unit = "%"),
    list(words = x, unit = "")
  )
}

.resy_fmt <- function(v, unit = "") {
  if (is.na(v)) return("missing")
  paste0(format(round(v, 1), trim = TRUE, drop0trailing = TRUE), unit)
}

.resy_operator_words <- c(GR = "more than", GE = "at least", EQ = "equal to",
                          LT = "less than", LE = "at most")

# One membership expression (for example "#TC Trees GR 15") for one plot, in
# words: what is measured, the plot's value, and what the expression requires,
# plus the plot's species that count towards it. The conditions are those the
# solver found in the expression; what is left over is the operator and, for a
# comparison with a fixed number, that number.
.resy_describe_expression <- function(expression, parsed, res, plot) {
  conds <- .resy_expression_conditions(expression, parsed$conditions)
  conds <- conds[order(vapply(conds, function(cc) regexpr(cc, expression, fixed = TRUE)[1],
                              numeric(1)))]
  rest <- expression
  for (cc in conds) rest <- gsub(cc, " ", rest, fixed = TRUE)
  tokens <- strsplit(trimws(rest), "\\s+")[[1]]
  tokens <- tokens[nzchar(tokens)]
  op <- tokens[tokens %in% names(.resy_operator_words)][1]
  number <- suppressWarnings(as.numeric(tokens[!tokens %in% names(.resy_operator_words)]))[1]
  op_words <- if (is.na(op)) "" else .resy_operator_words[[op]]

  value <- function(cc) res$plot.cond[plot$n, match(cc, parsed$conditions)]
  # A header column the expert system uses but the header lacks is read as 0 by
  # the solver; say so instead of showing the 0 as if it were data.
  absent <- function(cc) {
    (startsWith(cc, "$$N") || startsWith(cc, "$$C")) &&
      !trimws(substring(cc, 4L)) %in% names(plot$header)
  }
  shown_value <- function(cc, unit) {
    if (absent(cc)) "not in the header (read as 0)" else .resy_fmt(value(cc), unit)
  }

  species_of <- function(cc) {
    if (startsWith(cc, "$")) return(character())
    .resy_condition_taxa(cc, parsed$groups, parsed$groups.names)
  }
  taxa <- unique(unlist(lapply(conds, species_of)))
  sp <- plot$species[plot$species$species %in% trimws(taxa), , drop = FALSE]
  species <- if (nrow(sp)) {
    shown <- utils::head(sp, 8L)
    more <- if (nrow(sp) > 8L) paste0(", and ", nrow(sp) - 8L, " more") else ""
    paste0(paste(shown$species, .resy_fmt_cover(shown$cover), collapse = ", "), more)
  } else character()

  if (length(conds) >= 1L && startsWith(conds[1], "$$C")) {
    column <- trimws(substring(conds[1], 4L))
    have <- if (absent(conds[1])) "not in the header" else {
      h <- as.character(plot$header[[column]])
      if (is.na(h) || !nzchar(h)) "empty for this plot" else h
    }
    need <- if (length(conds) > 1L) conds[2] else if (!is.na(number)) number else ""
    text <- paste0(column, " is ", have, ", needs ", need)
    return(list(text = text, species = character()))
  }

  if (length(conds) == 1L) {
    w <- .resy_condition_words(conds[1])
    if (is.na(op)) {
      return(list(text = w$words, species = species))
    }
    text <- paste0(w$words, " is ", shown_value(conds[1], w$unit), ", needs ",
                   op_words, " ", .resy_fmt(number, w$unit))
    return(list(text = text, species = species))
  }

  if (length(conds) == 2L && !is.na(op)) {
    w1 <- .resy_condition_words(conds[1])
    w2 <- .resy_condition_words(conds[2])
    text <- paste0(w1$words, " is ", shown_value(conds[1], w1$unit), ", needs ",
                   op_words, " the ", w2$words, " (", shown_value(conds[2], w2$unit), ")")
    return(list(text = text, species = species))
  }

  list(text = expression, species = species)
}

.resy_fmt_cover <- function(cover) {
  vapply(cover, .resy_fmt, character(1))
}
