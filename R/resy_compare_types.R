#' Compare two vegetation types
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' Sets two vegetation types side by side: type `a` of expert system `x` and
#' type `b` of expert system `y`. The two can be types of one system, for
#' example `R11` and `R22` of EUNIS-ESy, or the same type in two releases, for
#' example `R22` in EUNIS-ESy 2020-06-08 and 2025-10-03. Their rules are written
#' with one numbering of conditions, so a condition both rules use has the same
#' number in both, and their species groups are compared member by member.
#'
#' With `plot`, the comparison is made for one classified plot: for each
#' condition whether the plot meets it in each type, the value the plot has,
#' and why the plot is or is not classified as each type (a rule that does not
#' hold, or a rule that holds but has a lower priority than the type chosen).
#'
#' @param x Expert system of type `a`: a `resy_result` from [resy_classify()],
#'   a `resy_parsed_expert` from [resy_load_expert()], the path of an expert
#'   file, or a version of `scheme` (see [resy_available_classifications()]).
#'   Must be a `resy_result` when `plot` is given.
#' @param a,b Short codes of the two types, for example `"R11"` and `"R22"`.
#' @param y Expert system of type `b`, given as `x`; by default `x`.
#' @param plot Optional plot identifier (`PlotObservationID`) present in the
#'   results `x` and `y`.
#' @param scheme Scheme of `x` and `y` when they are given as versions.
#'
#' @return A list of class `resy_type_comparison` with
#'   \describe{
#'     \item{`sides`}{One row per type: `side` (`"a"`, `"b"`), `system`,
#'       `code`, `name`, and the number of `rules` that define it.}
#'     \item{`rules`}{One row per rule: `side`, `code`, `rule` (its number
#'       among the type's rules), `priority` and `text`, the rule with
#'       conditions numbered as in `conditions`; with `plot`, `holds` and
#'       `judged` (the rule the plot is judged by).}
#'     \item{`conditions`}{One row per condition used by either type: its
#'       number `n`, the `expression` as written in the expert system, and
#'       `in_a`, `in_b`. With `plot` also `met_a`, `met_b` (`NA` where the type
#'       does not use the condition) and `text`, the condition in words with
#'       the plot's value.}
#'     \item{`groups`}{One row per species group named by either type:
#'       `group`, `in_a`, `in_b`, the number of members `n_a`, `n_b`, and for a
#'       group both name, the members `only_a` and `only_b` has.}
#'     \item{`plot`}{`NULL`, or for the plot its `id` and per side (`a`, `b`)
#'       the type it is classified as (`choice`), whether a rule of the type
#'       holds, its priority and the reason in words (`text`).}
#'   }
#' @seealso [resy_eval_plot()], which lists the siblings and lower levels of
#'   the type a plot is classified as; [resy_diff_expert()] for all changes
#'   between two expert systems.
#' @examples
#' species <- read.csv(
#'   system.file("extdata", "data_example_species.csv", package = "RESY")
#' )
#' header <- unique(species["PlotObservationID"])
#' res <- resy_classify(species, header, scheme = "Apennine-test")
#'
#' resy_compare_types(res, "NG", "NS")
#' resy_compare_types(res, "NG", "NS", plot = as.character(header$PlotObservationID[1]))
#' \donttest{
#' resy_compare_types("2020-06-08", "R22", "R22", y = "2025-10-03")
#' }
#' @export
resy_compare_types <- function(x, a, b, y = x, plot = NULL, scheme = "EUNIS") {
  stopifnot(is.character(a), length(a) == 1L, is.character(b), length(b) == 1L)
  if (!is.null(plot) && !(inherits(x, "resy_result") && inherits(y, "resy_result"))) {
    stop("`plot` needs `x` and `y` to be classification results from resy_classify().",
         call. = FALSE)
  }
  side <- list(a = .resy_compare_side(x, a, scheme), b = .resy_compare_side(y, b, scheme))
  keys <- unique(c(side$a$keys, side$b$keys))

  rules <- do.call(rbind, lapply(names(side), function(s) {
    d <- side[[s]]
    number <- function(j) match(.resy_expression_key(d$parsed$membership.expressions[j]), keys)
    data.frame(side = s, code = d$code, rule = seq_along(d$t),
               priority = as.integer(as.character(d$parsed$vegtype.priority[d$t])),
               text = vapply(d$t, function(i)
                 .resy_rule_words(d$parsed$vegtype.formulas.p[i], number)$text, character(1)),
               t = d$t, stringsAsFactors = FALSE)
  }))
  conditions <- data.frame(n = seq_along(keys), expression = keys,
                           in_a = keys %in% side$a$keys, in_b = keys %in% side$b$keys,
                           stringsAsFactors = FALSE)

  out <- list(
    sides = data.frame(side = names(side),
                       system = vapply(side, function(d) .resy_source_label(d$parsed), character(1)),
                       code = c(a, b),
                       name = vapply(side, function(d) .resy_type_description(d$parsed, d$t[1L]),
                                     character(1)),
                       rules = vapply(side, function(d) length(d$t), integer(1)),
                       row.names = NULL, stringsAsFactors = FALSE),
    rules = rules,
    conditions = conditions,
    groups = .resy_compare_groups(side$a, side$b),
    plot = NULL
  )

  if (!is.null(plot)) {
    res <- list(a = x, b = y)
    ctx <- lapply(res, .resy_plot_of, p = plot)
    verdict <- lapply(names(side), function(s) {
      held <- .resy_plot_held(res[[s]], ctx[[s]])
      choice <- unname(res[[s]]$result.classification[ctx[[s]]$id])
      v <- .resy_code_verdict(res[[s]], ctx[[s]], side[[s]]$code, held, choice)
      v$choice <- choice
      v
    })
    names(verdict) <- names(side)
    holds <- logical(nrow(rules))
    judged <- logical(nrow(rules))
    for (s in names(side)) {
      r <- rules$side == s
      holds[r] <- vapply(rules$t[r], function(i) isTRUE(res[[s]]$logi2[[i]][ctx[[s]]$n]), logical(1))
      judged[r] <- rules$t[r] == verdict[[s]]$t
    }
    out$rules$holds <- holds
    out$rules$judged <- judged
    # Column of each condition in each system; NA where the side does not use it.
    col <- lapply(side, function(d) {
      j <- match(keys, vapply(d$parsed$membership.expressions, .resy_expression_key, character(1)))
      j[!keys %in% d$keys] <- NA_integer_
      j
    })
    met <- function(s) vapply(col[[s]], function(k)
      if (is.na(k)) NA else isTRUE(res[[s]]$logi1[[k]][ctx[[s]]$n]), logical(1))
    out$conditions$met_a <- met("a")
    out$conditions$met_b <- met("b")
    out$conditions$text <- vapply(seq_along(keys), function(k) {
      s <- if (conditions$in_a[k]) "a" else "b"
      d <- side[[s]]
      .resy_describe_expression(d$parsed$membership.expressions[col[[s]][k]], d$parsed,
                                res[[s]], ctx[[s]])$text
    }, character(1))
    out$plot <- list(id = ctx$a$id,
                     a = verdict$a[c("choice", "holds", "priority", "text")],
                     b = verdict$b[c("choice", "holds", "priority", "text")])
  }
  out$rules$t <- NULL
  structure(out, class = "resy_type_comparison")
}

#' @export
print.resy_type_comparison <- function(x, ...) {
  s <- x$sides
  same_system <- identical(s$system[1L], s$system[2L])
  for (i in seq_len(nrow(s))) {
    cat(toupper(s$side[i]), "  ", s$code[i], " ", s$name[i],
        if (!same_system) paste0(" (", s$system[i], ")"), "\n", sep = "")
    r <- x$rules[x$rules$side == s$side[i], , drop = FALSE]
    for (k in seq_len(nrow(r))) {
      label <- if (nrow(r) > 1L) sprintf("Rule %d of %d", r$rule[k], nrow(r)) else "Rule"
      mark <- if (!is.null(r$judged) && nrow(r) > 1L && r$judged[k]) " <" else ""
      cat("   ", label, " (priority ", r$priority[k], "): ", r$text[k], mark, "\n", sep = "")
    }
  }
  if (same_system) cat("Expert system: ", s$system[1L], "\n", sep = "")

  cd <- x$conditions
  cat("\nConditions", if (!is.null(x$plot)) paste0(" for plot ", x$plot$id), ":\n", sep = "")
  cell <- function(used, met) {
    if (is.null(met)) return(ifelse(used, "used", ""))
    ifelse(!used, "", ifelse(met, "met", "not met"))
  }
  a <- cell(cd$in_a, cd$met_a)
  b <- cell(cd$in_b, cd$met_b)
  text <- if (is.null(cd$text)) cd$expression else cd$text
  cat(sprintf("  %-5s %-8s %-8s %s\n", "", s$code[1L], s$code[2L], ""), sep = "")
  cat(sprintf("  %-5s %-8s %-8s %s\n", paste0("[", cd$n, "]"), a, b, text), sep = "")

  g <- x$groups
  if (nrow(g)) {
    cat("\nSpecies groups:\n")
    both <- g$in_a & g$in_b
    if (any(both)) cat(strwrap(paste0("in both: ", paste(g$group[both], collapse = ", ")),
                               indent = 2, exdent = 4), sep = "\n")
    if (any(g$in_a & !both)) cat(strwrap(paste0("only ", s$code[1L], ": ",
                                                paste(g$group[g$in_a & !both], collapse = ", ")),
                                         indent = 2, exdent = 4), sep = "\n")
    if (any(g$in_b & !both)) cat(strwrap(paste0("only ", s$code[2L], ": ",
                                                paste(g$group[g$in_b & !both], collapse = ", ")),
                                         indent = 2, exdent = 4), sep = "\n")
    differ <- both & (nzchar(g$only_a) | nzchar(g$only_b))
    for (k in which(differ)) {
      cat(strwrap(paste0(g$group[k], " differs: ",
                         paste(c(if (nzchar(g$only_a[k])) paste0("only in ", toupper(s$side[1L]), ": ", g$only_a[k]),
                                 if (nzchar(g$only_b[k])) paste0("only in ", toupper(s$side[2L]), ": ", g$only_b[k])),
                               collapse = "; ")),
                  indent = 2, exdent = 4), sep = "\n")
    }
  }

  if (!is.null(x$plot)) {
    cat("\nPlot ", x$plot$id, ":\n", sep = "")
    for (k in c("a", "b")) cat("  ", s$code[s$side == k], ": ", x$plot[[k]]$text, "\n", sep = "")
  }
  invisible(x)
}

# ---- helpers ----------------------------------------------------------------

# One side of a comparison: the parsed system, the code, its rules and the
# conditions they use (as keys, in the order of their first use).
.resy_compare_side <- function(x, code, scheme) {
  p <- .resy_as_parsed(x, scheme)
  t <- which(p$vegtype.formula.names.short == code)
  if (!length(t)) {
    stop("Type ", code, " is not defined in ", .resy_source_label(p), ".", call. = FALSE)
  }
  cols <- unlist(lapply(t, function(i) .resy_rule_words(p$vegtype.formulas.p[i])$cols))
  keys <- unique(vapply(p$membership.expressions[cols], .resy_expression_key, character(1)))
  list(parsed = p, code = code, t = t, keys = unname(keys))
}

# A membership expression as compared across systems: whitespace normalised.
.resy_expression_key <- function(expression) gsub("\\s+", " ", trimws(expression))

# The species groups the conditions of either side name, with their members.
.resy_compare_groups <- function(a, b) {
  named <- function(d) {
    conds <- unique(unlist(lapply(d$keys, .resy_expression_conditions, d$parsed$conditions)))
    unique(unlist(lapply(conds, .resy_condition_groups, d$parsed$groups.names)))
  }
  members <- function(d, g) {
    i <- match(g, d$parsed$groups.names)
    if (is.na(i)) character() else sort(unique(trimws(d$parsed$groups[[i]])))
  }
  ga <- named(a)
  gb <- named(b)
  all <- unique(c(ga, gb))
  if (!length(all)) {
    return(data.frame(group = character(), in_a = logical(), in_b = logical(),
                      n_a = integer(), n_b = integer(), only_a = character(),
                      only_b = character(), stringsAsFactors = FALSE))
  }
  in_a <- all %in% ga
  in_b <- all %in% gb
  ma <- lapply(all, members, d = a)
  mb <- lapply(all, members, d = b)
  only <- function(x, y, both) ifelse(both, vapply(seq_along(x), function(k)
    paste(setdiff(x[[k]], y[[k]]), collapse = ", "), character(1)), "")
  data.frame(group = all, in_a = in_a, in_b = in_b,
             n_a = ifelse(in_a, lengths(ma), NA_integer_),
             n_b = ifelse(in_b, lengths(mb), NA_integer_),
             only_a = only(ma, mb, in_a & in_b), only_b = only(mb, ma, in_a & in_b),
             stringsAsFactors = FALSE)
}
