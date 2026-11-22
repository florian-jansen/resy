# Rewrite vegetation-type formulas as R expressions: each membership expression
# (the text inside <...>) becomes col<i>, its position in `expressions`, and the
# logical keywords become R operators ("A NOT B" is "A & !B"). Expressions are
# substituted longest first so that one containing another is replaced whole.
.resy_formula_to_r <- function(formulas, expressions) {
  if (length(expressions)) {
    o <- order(nchar(expressions), decreasing = TRUE)
    formulas <- stringi::stri_replace_all_fixed(
      formulas,
      pattern       = expressions[o],
      replacement   = paste0("col", seq_along(expressions))[o],
      vectorize_all = FALSE
    )
  }
  formulas <- gsub("[<>]", "", formulas)
  formulas <- gsub("\\bAND\\b", "&", formulas, perl = TRUE)
  formulas <- gsub("\\bOR\\b", "|", formulas, perl = TRUE)
  gsub("\\bNOT\\b", "&!", formulas, perl = TRUE)
}

# Shared expert-system formula transformation.
# Called by both the text parser (.resy_parse_expert_lines) and the
# JSON parser (.resy_parse_json). Takes raw aggs, groups, formula strings and
# formula names; returns the intermediate list consumed by .resy_build_parsed().

#' Apply solver-required formula transformations to a parsed expert system
#'
#' @description
#' Takes raw aggregations, groups, membership formulas and formula names (as
#' produced by either the text or JSON section parsers) and applies all
#' transformations needed by the solver: #T$ completion, GR NON insertion for
#' bare ##D/##C/##Q expressions, and EXCEPT completion for #SC conditions.
#' Groups combined with "|" (for example "#TC Trees|#TC Shrubs") are left as one
#' condition; the solver evaluates them on the union of the groups.
#'
#' @param aggs Named list of species aggregations (Section 1).
#' @param groups Named list of species groups (Section 2). Names must carry one
#'   of the prefixes in `.resy_group_prefixes` followed by a space.
#' @param membership.formulas Character vector of raw Section 3 formula strings.
#' @param membership.formula.names Character vector of Section 3 header lines,
#'   `"<priority><whitespace><code> <description>"`.
#' @return A list with elements `aggs`, `groups`, `membership.expressions`,
#'   `group.defs`, `formulas`, and `membership.priority`.
#' @noRd
.resy_transform_formulas <- function(aggs, groups, membership.formulas, membership.formula.names) {

  # ---- Validation
  if (any(grepl("[", membership.formulas, fixed = TRUE)))
    stop('Nested bracket "[]" is not implemented, only "()" is allowed.')
  if (any(grepl("{", membership.formulas, fixed = TRUE)))
    stop('Nested bracket "{}" is not implemented, only "()" is allowed.')

  gr <- c(.resy_group_name(names(groups)), "GE 30")
  if (any(duplicated(gr)))
    stop(paste("Duplicated group name found:", gr[duplicated(gr)]))

  # Extract initial membership expressions from the formula strings
  membership.expressions <- unlist(
    regmatches(membership.formulas,
               gregexpr("(?<=<)[^<>]+(?=>)", membership.formulas, perl = TRUE)),
    use.names = FALSE
  )

  # ---- Step 2: Complete #T$ right-hand sides ("#TC A GR #T$" becomes
  # "#TC A GR #T$ A"), for the GR and the GE operator
  for (op in c("GR", "GE")) {
    index3 <- which(grepl(paste0(op, "[[:space:]]*#T\\$[[:space:]]*$"), membership.expressions))
    if (length(index3) == 0) next
    b <- unique(membership.expressions[index3])
    a <- data.table::tstrsplit(b, op, fixed = TRUE)
    a[[1]] <- .resy_trim(a[[1]])
    for (i in seq_along(b)) {
      index4 <- which(regexpr(b[i], membership.formulas, fixed = TRUE) > 0)
      a[[1]][i] <- gsub("#TC", "#T$", a[[1]][i], fixed = TRUE)
      membership.formulas[index4] <- gsub(
        b[i],
        paste(b[i], substr(a[[1]][i], 4, nchar(a[[1]][i])), sep = ""),
        membership.formulas[index4], fixed = TRUE
      )
    }
    a2 <- data.table::tstrsplit(membership.expressions[index3], op, fixed = TRUE)
    a2[[1]] <- .resy_trim(a2[[1]])
    a2[[1]] <- gsub("#TC", "#T$", a2[[1]], fixed = TRUE)
    membership.expressions[index3] <- paste(
      membership.expressions[index3],
      substr(a2[[1]], 4, nchar(a2[[1]])),
      sep = ""
    )
  }

  # ---- Step 2C: Insert "GR NON" for bare ##D/##C/##Q expressions
  is.not.right.hand.side <-
    regexpr("GR", membership.expressions, fixed = TRUE) == -1 &
    regexpr("GE", membership.expressions, fixed = TRUE) == -1 &
    regexpr("EQ", membership.expressions, fixed = TRUE) == -1

  index9 <- suppressWarnings(
    as.numeric(substr(membership.expressions[is.not.right.hand.side], 3, 3))
  )
  a <- unique(membership.expressions[is.not.right.hand.side][is.na(index9)])

  if (length(a) > 0) {
    for (i in seq_along(a)) {
      index4 <- which(regexpr(a[i], membership.formulas, fixed = TRUE) > 0)
      membership.formulas[index4] <- gsub(
        a[i],
        paste(a[i], "GR NON", a[i], sep = " "),
        membership.formulas[index4], fixed = TRUE
      )
    }
  }
  membership.expressions[is.not.right.hand.side][is.na(index9)] <- paste(
    membership.expressions[is.not.right.hand.side][is.na(index9)],
    "GR NON",
    membership.expressions[is.not.right.hand.side][is.na(index9)],
    sep = " "
  )

  # ---- Step 3B: Add EXCEPT on right-hand sides of #SC conditions
  index3 <- grep("#SC", membership.expressions)
  a <- unique(membership.expressions[index3])
  b <- data.table::tstrsplit(a, "GR|GE|EQ", fixed = FALSE)
  if (length(b) > 0 && length(b) >= 2) {
    b[[1]] <- .resy_trim(b[[1]])
    b[[2]] <- .resy_trim(b[[2]])
    index4 <- grep("#SC", b[[2]])
    if (length(index4) > 0) {
      for (i in seq_along(index4)) {
        index6 <- grep(a[index4[i]], membership.expressions)
        membership.expressions[index6] <- paste(
          membership.expressions[index6], "EXCEPT", b[[1]][index4[i]], sep = " "
        )
        index5 <- grep(a[index4[i]], membership.formulas)
        membership.formulas[index5] <- gsub(
          a[index4[i]],
          paste(a[index4[i]], "EXCEPT", b[[1]][index4[i]], sep = " "),
          membership.formulas[index5], fixed = TRUE
        )
      }
    }
  }

  # ---- Build conditions (group.defs)
  membership.conditions2 <- unlist(strsplit(membership.expressions, " GR "))
  membership.conditions2 <- unlist(strsplit(membership.conditions2, " GE "))
  membership.conditions2 <- unlist(strsplit(membership.conditions2, " EQ "))
  membership.conditions2 <- .resy_trim(membership.conditions2)
  membership.conditions2 <- sort(unique(membership.conditions2))
  membership.conditions2 <- suppressWarnings(
    membership.conditions2[-which(!is.na(as.numeric(membership.conditions2)))]
  )

  # ---- Build priority factor
  prio <- substr(membership.formula.names, 1, 1)
  p <- factor(
    prio,
    ordered = TRUE,
    levels = c(0:9, LETTERS, letters),
    exclude = c(0:9, LETTERS, letters)[!c(0:9, LETTERS, letters) %in% prio]
  )

  names(membership.formulas) <- membership.formula.names

  list(
    aggs                 = aggs,
    groups               = groups,
    membership.expressions = membership.expressions,
    group.defs           = membership.conditions2,
    formulas             = membership.formulas,
    membership.priority  = p
  )
}
