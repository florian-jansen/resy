# Shared helper functions for ESy expert file validation

#' Check that every opening bracket has a matching closer of the same type.
#'
#' @description
#' Checks that every opening bracket (`(`, `[`, `{`) in a string has a corresponding closing bracket of the same type.
#'
#' @param s A character string to check for balanced brackets.
#' @return A logical value: `TRUE` if all brackets are balanced, `FALSE` otherwise.
#' @examples
#' .resy_esy_balanced_brackets("(a + [b * {c}])") # TRUE
#' .resy_esy_balanced_brackets("(a + [b * c)")    # FALSE
#' @noRd
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

#' Rewrite a formula so it can be tested with parse(): replace <...> conditions
#' with colN tokens and translate logical keywords to R operators.
#'
#' @description
#' Rewrites a formula string so it can be tested with `parse()`:
#' replaces `<...>` conditions with `colN` tokens and translates logical keywords (`AND`, `OR`, `NOT`) to R operators (`&`, `|`, `&!`).
#'
#' @param formula A character string representing a formula, possibly containing `<...>` conditions and logical keywords.
#' @return A character string, the rewritten formula.
#' @examples
#' .resy_esy_make_parseable("<A> AND <B> OR NOT <C>")
#' # Returns: "col1 & col2 | &!col3"
#' @noRd
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

#' Extract all group names referenced inside the <...> conditions of a formula.
#' Returns a character vector of bare group names (without the prefix token).
#'
#' @description
#' Extracts all group names referenced inside the `<...>` conditions of a formula.
#' Returns a character vector of bare group names (without the prefix token).
#'
#' @param formula A character string representing a formula, possibly containing `<...>` conditions.
#' @return A character vector of unique group names.
#' @examples
#' .resy_esy_extract_group_refs("<#TC MyGroup> AND <### OtherGroup>")
#' # Returns: c("MyGroup", "OtherGroup")
#' @noRd
.resy_esy_extract_group_refs <- function(formula) {
  
  conds <- unlist(regmatches(formula, gregexpr("<[^>]+>", formula, perl = TRUE)))
  # Match prefix token then the group name (first word after the prefix)
  prefix_re <- "^(?:#TC|###|#SC|##D|##C|##Q|#\\d{2}|\\$\\$C|\\$\\$N)\\s*(\\S+)"
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
    exc <- regmatches(
      inner, gregexpr("(?<=EXCEPT\\s)\\S+", inner, perl = TRUE)
      )[[1L]]
    refs <- c(refs, exc[!grepl("^(#|\\$)", exc)])  # skip special tokens
    
  }
  unique(refs)
}

#' Validate a single formula string. Returns an error message or NA_character_.
#' 'warnings' is an environment holding a character vector so warnings can be
#' appended from inside (avoiding <<- in the main validators).
#'
#' @description
#' Validates a single formula string for syntax and structure.
#' Returns an error message as a character string if validation fails, or `NA_character_` if valid.
#'
#' @param formula A character string representing the formula to validate.
#' @param ctx A character string describing the context (used in error messages).
#' @param strict A logical: if `TRUE`, legacy operators (like `UP`) cause an error; if `FALSE`, a warning is appended to `warn_env`.
#' @param warn_env An environment containing a character vector `w` to which warnings can be appended.
#' @return A character string (error message) or `NA_character_` if the formula is valid.
#' @examples
#' warn_env <- new.env(hash = TRUE)
#' warn_env$w <- character(0)
#' .resy_esy_check_formula("<A> AND <B>", "test", TRUE, warn_env) # NA_character_
#' .resy_esy_check_formula("A AND", "test", TRUE, warn_env) # Error message
#' @noRd
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
