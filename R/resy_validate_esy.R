#' Validate an expert classification file
#'
#' @description
#' Checks an ESy expert file (`.txt` or `.json`) for structural and syntactic
#' problems. Does not assess ecological correctness. The rules are:
#'
#' **Errors** (always fatal — the file cannot be imported):
#' \enumerate{
#'   \item All required sections / top-level keys must be present and, for
#'     `.txt`, in the correct order (Section 1 < 2 < 3).
#'   \item Every vegetation type must have a non-empty code with no whitespace.
#'   \item Every vegetation type must have a formula / expression.
#'   \item Every formula must contain at least one membership condition
#'     \code{<...>}.
#'   \item Brackets inside formulas must be balanced (\code{()}, \code{[]},
#'     \code{\{\}}).
#'   \item Priority must be a single character in \code{0-9}, \code{A-Z} or
#'     \code{a-z}.
#'   \item Group keys in Section 2 / \code{"groups"} must start with a
#'     recognised prefix (\code{###}, \code{##D}, \code{#TC}, \code{#SC},
#'     \code{$$C}, \code{$$N}).
#' }
#'
#' **Warnings** (errors when \code{strict = TRUE}):
#' \enumerate{
#'   \item Duplicate vegetation type codes.
#'   \item Group names referenced in formulas that are not defined.
#'   \item Dangling logical operators (\code{AND}/\code{OR}/\code{NOT} at the
#'     start or end of a formula).
#'   \item Legacy relational operator \code{UP} (deprecated in JUICE 7.0).
#'   \item For `.txt`: relational operators found outside \code{<...>} angle
#'     brackets.
#'   \item For `.json`: missing or empty \code{metadata.scheme} /
#'     \code{metadata.version}.
#'   \item Empty description for a vegetation type.
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
#' @seealso [resy_read_expert()], [resy_load_expert()],
#'   [resy_add_classification()]
#' @export
resy_validate_esy <- function(path, strict = FALSE, verbose = TRUE) {
  stopifnot(is.character(path), length(path) == 1L)
  if (!file.exists(path)) stop("File not found: ", path)

  is_json <- grepl("\\.json$", path, ignore.case = TRUE)
  result  <- if (is_json) {
    .resy_validate_esy_json(path, strict = strict)
  } else {
    .resy_validate_esy_txt(path, strict = strict)
  }

  if (isTRUE(verbose)) {
    ok <- result$ok
    ne <- length(result$errors)
    nw <- length(result$warnings)
    message("ESy validation: ",
            if (ok) "OK" else paste0("FAILED (", ne, " error(s), ", nw, " warning(s))"))
  }
  result
}


# ---- Shared helpers ---------------------------------------------------------

# Check that every opening bracket has a matching closer of the same type.
.resy_esy_balanced_brackets <- function(s) {
  pairs <- list("(" = ")", "[" = "]", "{" = "}")
  stack <- character()
  for (ch in strsplit(s, "", fixed = TRUE)[[1]]) {
    if (ch %in% names(pairs)) {
      stack <- c(stack, ch)
    } else if (ch %in% unname(pairs)) {
      if (!length(stack)) return(FALSE)
      if (!identical(pairs[[stack[length(stack)]]], ch)) return(FALSE)
      stack <- stack[-length(stack)]
    }
  }
  !length(stack)
}

# Rewrite a formula so it can be tested with parse(): replace <...> conditions
# with colN tokens and translate logical keywords to R operators.
.resy_esy_make_parseable <- function(formula) {
  f    <- gsub("\\s+", " ", trimws(formula))
  conds <- unique(unlist(regmatches(f, gregexpr("<[^>]+>", f, perl = TRUE))))
  if (length(conds)) {
    ord <- order(nchar(conds), decreasing = TRUE)
    f <- stringi::stri_replace_all_fixed(
      f, conds[ord], paste0("col", seq_along(conds))[ord],
      vectorize_all = FALSE
    )
  }
  f <- gsub("<",    "",   f, fixed = TRUE)
  f <- gsub(">",    "",   f, fixed = TRUE)
  f <- gsub("\\bAND\\b", "&",  f, perl = TRUE)
  f <- gsub("\\bOR\\b",  "|",  f, perl = TRUE)
  f <- gsub("\\bNOT\\b", "&!", f, perl = TRUE)
  trimws(gsub("\\s+", " ", f))
}

# Extract all group names referenced inside the <...> conditions of a formula.
# Returns a character vector of bare group names (without the prefix token).
.resy_esy_extract_group_refs <- function(formula) {
  conds <- unlist(regmatches(formula, gregexpr("<[^>]+>", formula, perl = TRUE)))
  # Match prefix token then the group name (first word after the prefix)
  prefix_re <- "^(?:#TC|###|#SC|##D|##C|##Q|#\\d{2})\\s+(\\S+)"
  refs <- character()
  for (cond in conds) {
    inner <- substring(cond, 2L, nchar(cond) - 1L)
    m <- regexpr(prefix_re, inner, perl = TRUE)
    if (m > 0L) {
      cap_start  <- attr(m, "capture.start")[1L]
      cap_length <- attr(m, "capture.length")[1L]
      refs <- c(refs, substring(inner, cap_start, cap_start + cap_length - 1L))
    }
  }
  # Also catch names after EXCEPT / | (pipe merges) — simple word extraction
  # for names that follow EXCEPT inside <...>
  for (cond in conds) {
    inner <- substring(cond, 2L, nchar(cond) - 1L)
    exc <- regmatches(inner, gregexpr("(?<=EXCEPT\\s)\\S+", inner, perl = TRUE))[[1L]]
    refs <- c(refs, exc[!grepl("^(#|\\$)", exc)])  # skip special tokens
  }
  unique(refs)
}

# Validate a single formula string. Returns an error message or NA_character_.
# 'warnings' is an environment holding a character vector so warnings can be
# appended from inside (avoiding <<- in the main validators).
.resy_esy_check_formula <- function(formula, ctx, strict, warn_env) {
  f <- trimws(gsub("\\s+", " ", formula))
  if (!nzchar(f))
    return(paste0("Empty formula for ", ctx))
  if (!grepl("<[^>]+>", f, perl = TRUE))
    return(paste0("No membership conditions <...> for ", ctx))
  if (!.resy_esy_balanced_brackets(f))
    return(paste0("Unbalanced brackets in formula for ", ctx, ":\n  ", f))
  if (grepl("\\b(AND|OR|NOT)\\s*$|^\\s*(AND|OR|NOT)\\b", f, perl = TRUE))
    return(paste0("Dangling logical operator in formula for ", ctx))
  if (grepl("\\bUP\\b", f, perl = TRUE)) {
    msg <- paste0("Legacy relational operator UP in formula for ", ctx)
    if (strict) return(msg) else warn_env$w <- c(warn_env$w, msg)
  }
  perr <- tryCatch(
    { parse(text = .resy_esy_make_parseable(f)); NULL },
    error = function(e) conditionMessage(e)
  )
  if (!is.null(perr))
    return(paste0("Invalid logical formula for ", ctx, ":\n  ", perr))
  NA_character_
}


# ---- TXT validator ----------------------------------------------------------

.resy_validate_esy_txt <- function(path, strict = FALSE) {
  trim    <- function(x) sub("^\\s+|\\s+$", "", x)
  norm_ws <- function(x) gsub("\\s+", " ", trim(x))
  nz      <- function(x) nzchar(trim(x))

  raw  <- readLines(path, warn = FALSE, encoding = "UTF-8")
  has_tabs <- any(grepl("\t", raw, fixed = TRUE))
  lines    <- sub("\t.*$", "", raw)

  errors   <- character()
  warnings <- character()
  warn_env <- new.env(parent = emptyenv()); warn_env$w <- character()

  is_section_end    <- function(x) grepl("^\\s*SECTION\\s+[0-9]+\\s*:\\s*End\\s*$", x, ignore.case = TRUE)
  is_section_marker <- function(x) grepl("^\\s*SECTION\\s+\\d+\\b", x, ignore.case = TRUE)

  sec1_i <- which(grepl("^\\s*SECTION\\s+1\\b", lines, ignore.case = TRUE))
  sec2_i <- which(grepl("^\\s*SECTION\\s+2\\b", lines, ignore.case = TRUE))
  sec3_i <- which(grepl("^\\s*SECTION\\s+3\\b", lines, ignore.case = TRUE))

  if (!length(sec1_i)) errors <- c(errors, "Missing SECTION 1 header")
  if (!length(sec2_i)) errors <- c(errors, "Missing SECTION 2 header")
  if (!length(sec3_i)) errors <- c(errors, "Missing SECTION 3 header")

  sec1 <- sec2 <- sec3 <- NA_integer_
  if (!length(errors)) {
    sec1 <- sec1_i[1L]; sec2 <- sec2_i[1L]; sec3 <- sec3_i[1L]
    if (!(sec1 < sec2 && sec2 < sec3))
      errors <- c(errors, "Sections are not in the correct order (expected 1 < 2 < 3)")
  }

  get_body <- function(start, end) {
    if (is.na(start) || is.na(end) || end <= start) return(character())
    lines[(start + 1L):(end - 1L)]
  }

  sec1_body <- sec2_body <- sec3_body <- character()
  if (!length(errors)) {
    sec1_body <- get_body(sec1, sec2)
    sec2_body <- get_body(sec2, sec3)
    sec3_body <- lines[(sec3 + 1L):length(lines)]
    sec4_pos  <- which(grepl("^\\s*SECTION\\s+4\\b", sec3_body, ignore.case = TRUE))
    if (length(sec4_pos)) sec3_body <- sec3_body[seq_len(sec4_pos[1L] - 1L)]
  }

  # Relational operators outside <...> in Section 3
  if (length(sec3_body)) {
    re_bad <- ">\\s*(GR|GE|LE|LR|EQ|UP)\\b\\s*([#\\$0-9.-]+)"
    bad_idx <- which(grepl(re_bad, sec3_body, perl = TRUE))
    for (k in bad_idx) {
      errors <- c(errors, sprintf(
        "[SECTION 3] Line %d: relational operator outside <...>: %s",
        sec3 + k, trim(sec3_body[k])
      ))
    }
  }

  # Section 2: group headers
  valid_prefixes <- c("###", "#TC", "#SC", "##D", "$$C", "$$N")
  group_header_re <- paste0("^\\s*(", paste(
    c("###", "#TC", "#SC", "##D", "\\$\\$C", "\\$\\$N"), collapse = "|"
  ), ")(\\s*\\+\\d{2})?\\s+(.+?)\\s*$")
  group_keys <- character()

  if (length(sec2_body)) {
    for (ln in sec2_body) {
      if (!nz(ln) || is_section_end(ln)) next
      if (grepl(group_header_re, ln, perl = TRUE)) {
        m <- regexec(group_header_re, ln, perl = TRUE)
        p <- regmatches(ln, m)[[1L]]
        name <- norm_ws(p[4L])
        if (!nzchar(name)) {
          errors <- c(errors, paste0('Empty group name in SECTION 2: "', ln, '"'))
        } else {
          group_keys <- c(group_keys, name)
        }
      } else if (!grepl("^\\s{1,}\\S", ln)) {
        if (strict)
          warnings <- c(warnings, paste0('Unexpected non-indented line in SECTION 2: "', ln, '"'))
      }
    }
  }
  group_keys <- unique(group_keys)

  # Section 3: type definitions
  header_re    <- "^\\s*(---)?\\s*([0-9A-Za-z])\\s{10}(.{5})(.*)$"
  is_hdr       <- function(x) grepl(header_re, x, perl = TRUE)
  veg_codes    <- character()

  if (length(sec3_body)) {
    i <- 1L
    while (i <= length(sec3_body)) {
      ln <- sec3_body[i]
      if (!nz(ln) || is_section_end(ln) || !is_hdr(ln)) { i <- i + 1L; next }

      m        <- regexec(header_re, ln, perl = TRUE)
      p        <- regmatches(ln, m)[[1L]]
      disabled <- nzchar(p[2L])
      code     <- norm_ws(p[4L])
      if (!nzchar(code)) {
        errors <- c(errors, paste0("Empty vegetation type code at line ", sec3 + i))
      } else {
        veg_codes <- c(veg_codes, code)
      }

      j <- i + 1L
      formula_lines <- character()
      formula_line_nos <- integer()
      while (j <= length(sec3_body)) {
        nxt <- sec3_body[j]
        if (!nz(nxt) || is_section_end(nxt)) { j <- j + 1L; next }
        if (is_hdr(nxt) || is_section_marker(nxt)) break
        formula_lines    <- c(formula_lines, nxt)
        formula_line_nos <- c(formula_line_nos, sec3 + j)
        j <- j + 1L
      }

      if (!length(formula_lines)) {
        msg <- paste0("Missing formula for code '", code, "'")
        if (strict) errors <- c(errors, msg) else warnings <- c(warnings, msg)
      } else if (!disabled) {
        combined <- paste(formula_lines, collapse = " ")
        ctx <- paste0("code '", code, "' (lines ", min(formula_line_nos),
                      "-", max(formula_line_nos), ")")

        # Group reference check
        refs <- .resy_esy_extract_group_refs(combined)
        undef <- setdiff(refs, group_keys)
        if (length(undef)) {
          msg <- paste0("Undefined group(s) in formula for ", ctx, ": ",
                        paste(undef, collapse = ", "))
          if (strict) errors <- c(errors, msg) else warnings <- c(warnings, msg)
        }

        ferr <- .resy_esy_check_formula(combined, ctx, strict, warn_env)
        if (!is.na(ferr)) errors <- c(errors, ferr)
      }
      i <- j
    }
  }

  dup <- unique(veg_codes[duplicated(veg_codes)])
  if (length(dup)) {
    msg <- paste0("Duplicate vegetation type code(s): ", paste(dup, collapse = ", "))
    if (strict) errors <- c(errors, msg) else warnings <- c(warnings, msg)
  }

  if (has_tabs) warnings <- c(warnings, "Tab characters present (only the first TSV field is used)")
  warnings <- c(warnings, warn_env$w)

  list(
    ok       = !length(errors),
    errors   = unique(errors),
    warnings = unique(warnings),
    meta     = list(
      path             = path,
      tabs_present     = has_tabs,
      groups_defined   = length(group_keys),
      vegtypes_defined = length(unique(veg_codes))
    )
  )
}


# ---- JSON validator ---------------------------------------------------------

.resy_validate_esy_json <- function(path, strict = FALSE) {
  if (!requireNamespace("jsonlite", quietly = TRUE))
    stop("Package 'jsonlite' is required to validate JSON expert files.")

  errors   <- character()
  warnings <- character()
  warn_env <- new.env(parent = emptyenv()); warn_env$w <- character()

  x <- tryCatch(
    jsonlite::read_json(path, simplifyVector = FALSE),
    error = function(e) {
      stop("Cannot parse JSON: ", conditionMessage(e), call. = FALSE)
    }
  )

  # --- Metadata (advisory)
  meta_j <- x[["metadata"]]
  if (is.null(meta_j)) {
    warnings <- c(warnings,
                  "No 'metadata' key — recommended fields: scheme, version, description")
  } else {
    if (!nzchar(as.character(meta_j[["scheme"]]  %||% "")))
      warnings <- c(warnings, "metadata.scheme is missing or empty")
    if (!nzchar(as.character(meta_j[["version"]] %||% "")))
      warnings <- c(warnings, "metadata.version is missing or empty")
  }

  # --- Required top-level keys
  required <- c("synonyms", "groups", "rules")
  missing  <- setdiff(required, names(x))
  if (length(missing)) {
    errors <- c(errors,
                paste0("Missing required top-level key(s): ",
                       paste(missing, collapse = ", ")))
    # Cannot proceed meaningfully without these
    return(list(ok = FALSE, errors = errors, warnings = warnings,
                meta = list(path = path, groups_defined = 0L,
                            vegtypes_defined = 0L)))
  }

  # --- Groups
  valid_prefixes <- c("### ", "##D ", "#TC ", "#SC ", "$$C ", "$$N ")
  groups_j  <- x[["groups"]]
  group_names <- character()

  if (!is.list(groups_j)) {
    errors <- c(errors, "'groups' must be a JSON object (key: array pairs)")
  } else {
    for (gkey in names(groups_j)) {
      has_pfx <- any(startsWith(gkey, valid_prefixes))
      if (!has_pfx) {
        errors <- c(errors, sprintf(
          "Group key %s does not start with a recognised prefix (%s)",
          dQuote(gkey),
          paste(trimws(valid_prefixes), collapse = ", ")
        ))
      } else {
        for (pfx in valid_prefixes) {
          if (startsWith(gkey, pfx)) {
            gname <- trimws(substring(gkey, nchar(pfx) + 1L))
            if (!nzchar(gname))
              errors <- c(errors, paste0("Empty group name in key: ", dQuote(gkey)))
            else
              group_names <- c(group_names, gname)
            break
          }
        }
      }
    }
  }
  group_names <- unique(group_names)

  # --- Rules
  rules_j <- x[["rules"]]
  veg_codes <- character()
  valid_prios <- c(as.character(0:9), LETTERS, letters)
  required_rule_keys <- c("priority", "code", "description", "expression")

  if (!is.list(rules_j) || length(rules_j) == 0L) {
    errors <- c(errors, "'rules' must be a non-empty array of type-definition objects")
  } else {
    for (i in seq_along(rules_j)) {
      r         <- rules_j[[i]]
      data_keys <- names(r)[!startsWith(names(r), "_")]
      missing_k <- setdiff(required_rule_keys, data_keys)
      if (length(missing_k)) {
        errors <- c(errors, sprintf("Rule %d is missing required key(s): %s",
                                    i, paste(missing_k, collapse = ", ")))
        next
      }

      prio <- as.character(r[["priority"]])
      code <- as.character(r[["code"]])
      desc <- as.character(r[["description"]])
      expr <- as.character(r[["expression"]])

      lbl <- sprintf("rule %d (%s)", i, if (nzchar(code)) dQuote(code) else "<no code>")

      # Priority
      if (!prio %in% valid_prios)
        errors <- c(errors, sprintf(
          "Invalid priority %s in %s — must be a single character in 0-9, A-Z or a-z",
          dQuote(prio), lbl
        ))

      # Code
      if (!nzchar(code)) {
        errors <- c(errors, paste0("Empty code in ", lbl))
      } else if (grepl("\\s", code)) {
        errors <- c(errors, sprintf("Code %s contains whitespace in %s", dQuote(code), lbl))
      } else {
        veg_codes <- c(veg_codes, code)
      }

      # Description
      if (!nzchar(desc)) {
        msg <- paste0("Empty description in ", lbl)
        if (strict) errors <- c(errors, msg) else warnings <- c(warnings, msg)
      }

      # Expression
      if (!nzchar(expr)) {
        errors <- c(errors, paste0("Empty expression in ", lbl))
      } else {
        # Group references
        refs  <- .resy_esy_extract_group_refs(expr)
        undef <- setdiff(refs, group_names)
        if (length(undef)) {
          msg <- sprintf("Undefined group(s) in expression for %s: %s",
                         lbl, paste(undef, collapse = ", "))
          if (strict) errors <- c(errors, msg) else warnings <- c(warnings, msg)
        }

        ferr <- .resy_esy_check_formula(expr, lbl, strict, warn_env)
        if (!is.na(ferr)) errors <- c(errors, ferr)
      }
    }
  }

  # Duplicate codes
  dup <- unique(veg_codes[duplicated(veg_codes)])
  if (length(dup)) {
    msg <- paste0("Duplicate vegetation type code(s): ", paste(dup, collapse = ", "))
    if (strict) errors <- c(errors, msg) else warnings <- c(warnings, msg)
  }

  warnings <- c(warnings, warn_env$w)

  list(
    ok       = !length(errors),
    errors   = unique(errors),
    warnings = unique(warnings),
    meta     = list(
      path             = path,
      groups_defined   = length(group_names),
      vegtypes_defined = length(unique(veg_codes))
    )
  )
}


