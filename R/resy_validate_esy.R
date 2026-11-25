#' Validate an expert classification file
#'
#' @description
#' Checks an ESy expert file (`.txt` or `.json`) for structural and syntactic
#' problems. Does not assess ecological correctness. Both formats are read into
#' the same parts (species groups and type definitions) and checked by the same
#' rules; only the checks of the file layout differ between them.
#'
#' **Errors** (always fatal: the file cannot be imported):
#' \enumerate{
#'   \item All required sections / top-level keys must be present and, for
#'     `.txt`, in the correct order (Section 1 < 2 < 3).
#'   \item At least one vegetation type must be defined.
#'   \item Every vegetation type must have a non-empty code with no whitespace.
#'   \item Every vegetation type must have a formula / expression.
#'   \item Every formula must contain at least one membership condition
#'     \code{<...>}.
#'   \item Brackets inside formulas must be balanced (\code{()}, \code{[]},
#'     \code{\{\}}).
#'   \item A formula must not start or end with a logical operator
#'     (\code{AND}/\code{OR}/\code{NOT}).
#'   \item Priority must be a single character in \code{0-9}, \code{A-Z} or
#'     \code{a-z}.
#'   \item Group keys in Section 2 / \code{"groups"} must start with a
#'     recognised prefix (\code{###}, \code{##D}, \code{##Q}, \code{##C},
#'     \code{$$C}, \code{$$N}) followed by a name.
#'   \item For `.txt`: no relational operator outside \code{<...>} angle
#'     brackets.
#'   \item For `.json`: every rule has the keys \code{priority}, \code{code},
#'     \code{description} and \code{expression}.
#' }
#'
#' **Warnings** (errors when \code{strict = TRUE}):
#' \enumerate{
#'   \item Duplicate vegetation type codes.
#'   \item Species groups referenced in formulas that are not defined. Groups
#'     are resolved the way the classifier resolves them; header columns
#'     (\code{$$C}, \code{$$N}) and the names after \code{EXCEPT}, which may be
#'     single species, are not checked.
#'   \item Legacy relational operator \code{UP} (deprecated in JUICE 7.0).
#'   \item Empty description for a vegetation type.
#' }
#'
#' **Notes** (warnings also when \code{strict = TRUE}):
#' \enumerate{
#'   \item For `.txt`: tab characters (only the text before the first tab of a
#'     line is used).
#'   \item For `.json`: missing or empty \code{metadata.scheme} /
#'     \code{metadata.version}.
#' }
#'
#' @param path Path to a `.txt` or `.json` expert file.
#' @param strict Logical; if `TRUE`, treat warnings as errors.
#' @param verbose Logical; if `TRUE` (default), print a one-line summary.
#' @return A list with:
#'   \describe{
#'     \item{`ok`}{`TRUE` when no errors were found.}
#'     \item{`errors`}{Character vector of error messages.}
#'     \item{`warnings`}{Character vector of warning messages.}
#'     \item{`meta`}{Named list: `path`, and counts of groups and vegetation
#'       types defined.}
#'   }
#' @examples
#' # Validate a .txt file
#' result <- resy_validate_esy(
#' system.file("extdata", "example_mini_expert_file.txt", package = "RESY"
#' ), strict = FALSE)
#' if (!result$ok) print(result$errors)
#' @seealso [resy_read_expert()], [resy_load_expert()],
#'   [resy_add_classification()]
#' @export
resy_validate_esy <- function(path, strict = FALSE, verbose = TRUE) {

  stopifnot(is.character(path), length(path) == 1L)
  if (!file.exists(path)) stop("File not found: ", path)

  parts  <- if (.resy_is_json(path)) .resy_esy_read_json(path) else .resy_esy_read_txt(path)
  result <- .resy_esy_check_parts(parts, path, strict = strict)

  if (isTRUE(verbose)) .resy_report_message("ESy validation", result)
  result

}


# ---- Reports ----------------------------------------------------------------

# Summary list returned by the validators and checkers: `ok` when there are no
# errors, the unique errors and warnings, and a `meta` list.
.resy_report <- function(errors, warnings, meta = list()) {

  list(
    ok = !length(errors), errors = unique(errors), warnings = unique(warnings),
    meta = meta
    )

}

# Summary of a report: "<label>: OK", or the error and warning counts followed
# by the first error.
.resy_report_message <- function(label, report) {

  if (report$ok) return(message(label, ": OK"))
  message(label, ": FAILED (", length(report$errors), " error(s), ",
          length(report$warnings), " warning(s))\n  ", report$errors[1])

}


# ---- Reading a file into its parts ------------------------------------------
# A reader returns what the checks below need, whatever the format:
#   errors, warnings  problems of the file layout, found while reading
#   complete          FALSE when the layout is too broken to read the parts
#   groups            the group keys as written (prefix, space, name)
#   rules             one list per type definition: priority, code,
#                     description, expression, `where` (its place in the file)
#                     and `disabled` (TRUE for a type switched off with "---")
#   words             what the format calls a formula and the place of the
#                     type definitions, for the messages
#   meta              format-specific entries of the report's `meta`

.resy_esy_parts <- function(errors = character(), warnings = character(),
                            complete = TRUE, groups = character(),
                            rules = list(), words, meta = list()) {

  list(errors = errors, warnings = warnings, complete = complete,
       groups = groups, rules = rules, words = words, meta = meta)

}

# A `.txt` expert file: Section 2 group headers and Section 3 type definitions.
.resy_esy_read_txt <- function(path) {

  nz <- function(x) nzchar(.resy_trim(x))
  words <- c(formula = "formula", rules = "SECTION 3")

  raw      <- readLines(path, warn = FALSE, encoding = "UTF-8")
  has_tabs <- any(grepl("\t", raw, fixed = TRUE))
  lines    <- sub("\t.*$", "", raw)
  meta     <- list(tabs_present = has_tabs)
  warnings <- if (has_tabs)
    "Tab characters present (only the first TSV field is used)" else character()

  is_section_end    <- function(x)
    grepl("^\\s*SECTION\\s+[0-9]+\\s*:\\s*End\\s*$", x, ignore.case = TRUE)
  is_section_marker <- function(x)
    grepl("^\\s*SECTION\\s+\\d+\\b", x, ignore.case = TRUE)

  start <- lapply(1:3, function(n) .resy_section_rows(lines, n))
  errors <- sprintf("Missing SECTION %d header", which(!lengths(start)))
  if (!length(errors)) {
    start <- vapply(start, `[`, integer(1), 1L)
    if (is.unsorted(start, strictly = TRUE))
      errors <- "Sections are not in the correct order (expected 1 < 2 < 3)"
  }
  if (length(errors))
    return(.resy_esy_parts(errors, warnings, complete = FALSE, words = words,
                           meta = meta))

  sec2_body <- lines[seq.int(start[2] + 1L, length.out = start[3] - start[2] - 1L)]
  sec3_body <- lines[seq.int(start[3] + 1L, length.out = length(lines) - start[3])]
  sec4_pos  <- .resy_section_rows(sec3_body, 4)
  if (length(sec4_pos)) sec3_body <- sec3_body[seq_len(sec4_pos[1L] - 1L)]

  # Relational operators outside <...> in Section 3
  re_bad <- ">\\s*(GR|GE|LE|LR|EQ|UP)\\b\\s*([#\\$0-9.-]+)"
  bad <- which(grepl(re_bad, sec3_body, perl = TRUE))
  errors <- sprintf("[SECTION 3] Line %d: relational operator outside <...>: %s",
                    start[3] + bad, .resy_trim(sec3_body[bad]))

  # Section 2: a group header starts in the first column; member lines are
  # indented.
  is_key <- nz(sec2_body) & !is_section_end(sec2_body) & !grepl("^\\s", sec2_body)
  groups <- sec2_body[is_key]

  # Section 3: a type definition is a header line (priority character,
  # whitespace, code, description; "---" in front disables the type) followed
  # by the lines of its formula. A line holding a priority character alone is
  # a header without a code.
  # The formula of a type runs from its header to the next header or section
  # marker; blank lines and section ends in between are left out.
  head     <- .resy_definition_header(sub("^\\s*(---)?\\s*", "", sec3_body))
  skip     <- !nz(sec3_body) | is_section_end(sec3_body)
  is_hdr   <- !skip & !is.na(head$priority)
  stops    <- which(is_hdr | (!skip & is_section_marker(sec3_body)))
  ends     <- c(stops, length(sec3_body) + 1L)
  disabled <- grepl("^\\s*---", sec3_body)

  rules <- lapply(which(is_hdr), function(i) {
    end   <- ends[findInterval(i, stops) + 1L]
    lines <- seq.int(i + 1L, length.out = end - i - 1L)
    list(
      priority    = head$priority[i],
      code        = head$code[i],
      description = head$description[i],
      expression  = paste(sec3_body[lines[!skip[lines]]], collapse = " "),
      where       = paste("line", start[3] + i),
      disabled    = disabled[i]
    )
  })

  .resy_esy_parts(errors, warnings, groups = groups, rules = rules,
                  words = words, meta = meta)

}

# A `.json` expert file: the keys of "groups" and the objects of "rules".
.resy_esy_read_json <- function(path) {

  words <- c(formula = "expression", rules = "'rules'")

  x <- tryCatch(
    jsonlite::read_json(path, simplifyVector = FALSE),
    error = function(e) {
      stop("Cannot parse JSON: ", conditionMessage(e), call. = FALSE)
    }
  )

  # Metadata (advisory)
  meta_j <- x[["metadata"]]
  warnings <- if (is.null(meta_j)) {
    "No 'metadata' key; recommended fields: scheme, version, description"
  } else {
    c(scheme = "metadata.scheme is missing or empty",
      version = "metadata.version is missing or empty")[
        !vapply(c("scheme", "version"), function(k)
          nzchar(as.character(meta_j[[k]] %||% "")), logical(1))]
  }
  warnings <- unname(warnings)

  missing <- setdiff(.resy_json_required, names(x))
  if (!any(.resy_json_taxonomy %in% names(x)))
    missing <- c(missing, "synonyms or backbone")
  if (length(missing))
    return(.resy_esy_parts(
      paste0("Missing required top-level key(s): ", paste(missing, collapse = ", ")),
      warnings, complete = FALSE, words = words
    ))

  errors <- character()
  groups <- character()
  if (is.list(x[["groups"]])) {
    groups <- names(x[["groups"]]) %||% character()
  } else {
    errors <- c(errors, "'groups' must be a JSON object (key: array pairs)")
  }

  rules_j <- if (is.list(x[["rules"]])) x[["rules"]] else list()
  rules <- list()
  for (i in seq_along(rules_j)) {

    r <- rules_j[[i]]
    missing_k <- .resy_json_missing_rule_keys(r)
    if (length(missing_k)) {
      errors <- c(errors, sprintf("Rule %d is missing required key(s): %s",
                                  i, paste(missing_k, collapse = ", ")))
      next
    }
    rules[[length(rules) + 1L]] <- list(
      priority    = as.character(r[["priority"]]),
      code        = as.character(r[["code"]]),
      description = as.character(r[["description"]]),
      expression  = as.character(r[["expression"]]),
      where       = paste("rule", i),
      disabled    = FALSE
    )

  }
  # A file whose rules all lack keys has said so; "no types" would repeat it.
  if (length(rules_j) && !length(rules))
    return(.resy_esy_parts(errors, warnings, complete = FALSE, words = words))

  .resy_esy_parts(errors, warnings, groups = groups, rules = rules, words = words)

}


# ---- Checking the parts -----------------------------------------------------

# The report on the parts of an expert file (see the readers above). Every
# check that does not depend on the file format is made here, once.
.resy_esy_check_parts <- function(parts, path, strict = FALSE) {

  log <- new.env(parent = emptyenv())
  log$errors   <- parts$errors
  log$warnings <- parts$warnings
  log$w        <- character()
  error <- function(...) log$errors <- c(log$errors, paste0(...))
  soft  <- function(...) {
    if (strict) error(...) else log$warnings <- c(log$warnings, paste0(...))
  }
  report <- function(n_groups, n_types) {
    .resy_report(log$errors, c(log$warnings, log$w), meta = c(
      list(path = path), parts$meta,
      list(groups_defined = n_groups, vegtypes_defined = n_types)
    ))
  }
  if (!parts$complete) return(report(0L, 0L))

  formula_word <- parts$words[["formula"]]

  # --- Groups: a recognised prefix followed by a name
  group_names <- character()
  for (key in parts$groups) {

    if (!substr(key, 1, 3) %in% .resy_group_prefixes) {
      error(sprintf('Group "%s" does not start with a recognised prefix (%s)',
                    key, paste(.resy_group_prefixes, collapse = ", ")))
      next
    }
    name <- .resy_esy_group_names(key)
    if (nzchar(name)) group_names <- c(group_names, name) else
      error(sprintf('Empty group name: "%s"', key))

  }
  group_names <- unique(group_names)

  # --- Type definitions
  if (!length(parts$rules))
    error(parts$words[["rules"]], " defines no vegetation types")

  valid_prios <- c(as.character(0:9), LETTERS, letters)

  field <- function(name)
    vapply(parts$rules, function(r) as.character(r[[name]])[1L], character(1))
  code     <- field("code")
  priority <- field("priority")
  expr     <- field("expression")
  disabled <- vapply(parts$rules, function(r) isTRUE(r$disabled), logical(1))
  label    <- sprintf("%s (%s)", field("where"),
                      ifelse(nzchar(code), dQuote(code, FALSE), "<no code>"))
  code_ok  <- nzchar(code) & !grepl("\\s", code)
  no_text  <- !nzchar(field("description"))

  # The formulas of the types in use are checked together, in one pass.
  checked <- which(!disabled & nzchar(.resy_trim(expr)))
  refs    <- .resy_esy_group_refs_list(expr[checked])
  formula <- .resy_esy_check_formulas(expr[checked], label[checked], strict)

  for (i in seq_along(parts$rules)) {

    if (!priority[i] %in% valid_prios)
      error(sprintf(
        "Invalid priority %s in %s: must be a single character in 0-9, A-Z or a-z",
        dQuote(priority[i], FALSE), label[i]
      ))

    if (!nzchar(code[i])) {
      error("Empty vegetation type code in ", label[i])
    } else if (!code_ok[i]) {
      error(sprintf("Code %s contains whitespace in %s", dQuote(code[i], FALSE), label[i]))
    }

    if (disabled[i]) next

    if (no_text[i]) soft("Empty description in ", label[i])

    k <- match(i, checked)
    if (is.na(k)) {
      error("Empty ", formula_word, " in ", label[i])
      next
    }

    undef <- setdiff(refs[[k]], group_names)
    if (length(undef))
      soft(sprintf("Undefined group(s) in %s for %s: %s", formula_word, label[i],
                   paste(undef, collapse = ", ")))

    if (!is.na(formula$warning[k])) log$w <- c(log$w, formula$warning[k])
    if (!is.na(formula$error[k])) error(formula$error[k])

  }

  veg_codes <- code[code_ok]
  dup <- unique(veg_codes[duplicated(veg_codes)])
  if (length(dup))
    soft("Duplicate vegetation type code(s): ", paste(dup, collapse = ", "))

  report(length(group_names), length(unique(veg_codes)))

}


# ---- Formulas and groups ----------------------------------------------------

# Check that every opening bracket has a matching closer of the same type.
# One value per string. The brackets of a string match when removing every
# adjacent pair "()", "[]", "{}" again and again leaves none.
.resy_esy_balanced_brackets <- function(s) {

  left <- gsub("[^][(){}]", "", s, perl = TRUE)
  repeat {
    fewer <- gsub("()", "", gsub("[]", "", gsub("{}", "", left, fixed = TRUE),
                                 fixed = TRUE), fixed = TRUE)
    if (identical(fewer, left)) break
    left <- fewer
  }

  !nzchar(left)

}

# Membership expressions of a formula: the text inside each <...>.
.resy_esy_expressions <- function(formula) {

  as.character(unlist(.resy_esy_expressions_list(formula), use.names = FALSE))

}

# The membership expressions of each formula, one character vector per formula.
.resy_esy_expressions_list <- function(formulas) {

  regmatches(formulas, gregexpr("(?<=<)[^<>]+(?=>)", formulas, perl = TRUE))

}

# Rewrite formulas so they can be tested with parse(). The membership
# expressions of a formula are numbered within that formula.
.resy_esy_make_parseable <- function(formula) {

  f <- gsub("\\s+", " ", trimws(formula))
  f <- .resy_formula_to_r(f, lapply(.resy_esy_expressions_list(f), unique))
  trimws(gsub("\\s+", " ", f))

}

# Group names referenced by the membership expressions of a formula, resolved
# the way the solver resolves them: each side of a comparison that starts with
# a group condition code names one group, or several joined by "|". The part
# after EXCEPT may name single species and is not checked.
.resy_esy_extract_group_refs <- function(formula) {

  unique(as.character(unlist(.resy_esy_group_refs_list(formula), use.names = FALSE)))

}

# The same for several formulas: one character vector of group names each.
.resy_esy_group_refs_list <- function(formulas) {

  flat <- function(x) as.character(unlist(x, use.names = FALSE))

  ex    <- .resy_esy_expressions_list(formulas)
  id    <- rep.int(seq_along(formulas), lengths(ex))
  sides <- strsplit(flat(ex), "\\s+(GR|GE|EQ|LE|LR|UP)\\s+", perl = TRUE)
  id    <- rep.int(id, lengths(sides))
  sides <- trimws(sub("^NON\\s+", "", sub("\\s+EXCEPT\\s.*$", "", trimws(flat(sides)))))
  keep  <- grepl("^(###|##[QCD]|#TC|#SC|#T\\$|#[0-9]{2})\\s", sides)
  names <- .resy_membership_parts_list(sides[keep])
  id    <- rep.int(id[keep], lengths(names))
  names <- gsub("\\s+", " ", flat(names))

  unname(lapply(split(names, factor(id, levels = seq_along(formulas))), unique))

}

# Group names defined by Section 2 keys (prefix, space, name), whitespace
# normalised; keys without a known prefix give no name.
.resy_esy_group_names <- function(keys) {

  keys <- keys[substr(keys, 1, 3) %in% .resy_group_prefixes]
  gsub("\\s+", " ", trimws(.resy_group_name(keys)))

}

# Validate a single formula string. Returns an error message or NA_character_.
# 'warnings' is an environment holding a character vector so warnings can be
# appended from inside (avoiding <<- in the main validators).
.resy_esy_check_formula <- function(formula, ctx, strict, warn_env) {

  res <- .resy_esy_check_formulas(formula, ctx, strict)
  if (!is.na(res$warning)) warn_env$w <- c(warn_env$w, res$warning)
  res$error

}

# Validate several formulas, `ctx` naming the place of each. Returns the first
# error of each formula and its warning, NA_character_ where there is none.
.resy_esy_check_formulas <- function(formulas, ctx, strict) {

  f       <- trimws(gsub("\\s+", " ", formulas))
  error   <- rep(NA_character_, length(f))
  warning <- error
  first   <- function(error, found, msg) {
    new <- is.na(error) & found
    error[new] <- msg[new]
    error
  }

  error <- first(error, !nzchar(f), paste0("Empty formula for ", ctx))
  error <- first(error, !grepl("<[^>]+>", f, perl = TRUE),
                 paste0("No membership conditions <...> for ", ctx))
  error <- first(error, !.resy_esy_balanced_brackets(f),
                 paste0("Unbalanced brackets in formula for ", ctx, ":\n  ", f))
  error <- first(error,
                 grepl("\\b(AND|OR|NOT)\\s*$|^\\s*(AND|OR|NOT)\\b", f, perl = TRUE),
                 paste0("Dangling logical operator in formula for ", ctx))

  up  <- is.na(error) & grepl("\\bUP\\b", f, perl = TRUE)
  msg <- paste0("Legacy relational operator UP in formula for ", ctx)
  if (strict) error[up] <- msg[up] else warning[up] <- msg[up]

  open <- which(is.na(error))
  code <- .resy_esy_make_parseable(f[open])
  for (k in seq_along(open)) {
    perr <- tryCatch({ parse(text = code[k]); NULL },
                     error = function(e) conditionMessage(e))
    if (!is.null(perr))
      error[open[k]] <- paste0("Invalid logical formula for ", ctx[open[k]], ":\n  ", perr)
  }

  list(error = error, warning = warning)

}
