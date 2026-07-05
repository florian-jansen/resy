# Shared expert-system formula transformation.
# Called by both the text parser (parse.classification.expert.vector) and the
# JSON parser (resy_parse_json). Takes raw aggs, groups, formula strings and
# formula names; returns the intermediate list consumed by resy_parse_expert().

#' @keywords internal
.resy_expand_side_or <- function(side) {
  side <- trimws(side)
  parts.exc <- strsplit(side, "EXCEPT", fixed = TRUE)[[1]]
  core <- trimws(parts.exc[1])
  suffix <- if (length(parts.exc) > 1) paste0(" EXCEPT ", trimws(paste(parts.exc[-1], collapse = " EXCEPT "))) else ""
  parts <- trimws(unlist(strsplit(core, "|#", fixed = TRUE), use.names = FALSE))
  parts <- parts[nzchar(parts)]
  if (length(parts) <= 1) return(side)
  pref <- regmatches(parts, regexpr("^(###|##[QCD]|#TC|#T\\$|#SC|#\\$\\$|#\\d{2}|\\$\\$[CN])(?=\\s)", parts, perl = TRUE))
  if (!all(nzchar(pref))) return(side)
  paste0(parts, suffix)
}

#' @keywords internal
.resy_expand_or_membership_expression <- function(expr) {
  m <- regexec("^(.*?)\\s+(GR|GE|EQ)\\s+(.*?)$", trimws(expr), perl = TRUE)
  parts <- regmatches(trimws(expr), m)[[1]]
  if (length(parts) != 4) return(expr)
  lhs <- .resy_expand_side_or(parts[2])
  rhs <- .resy_expand_side_or(parts[4])
  lhs <- if (length(lhs) == 1L) lhs else trimws(lhs)
  rhs <- if (length(rhs) == 1L) rhs else trimws(rhs)
  if (length(lhs) == 1L && length(rhs) == 1L) return(expr)
  atoms <- as.vector(outer(lhs, rhs, function(l, r) paste(trimws(l), parts[3], trimws(r))))
  paste(atoms, collapse = " OR ")
}

#' Apply solver-required formula transformations to a parsed expert system
#'
#' @description
#' Takes raw aggregations, groups, membership formulas and formula names (as
#' produced by either the text or JSON section parsers) and applies all
#' transformations needed by the solver: #T$ completion, GR NON insertion for
#' bare ##D/##C/##Q expressions, EXCEPT completion for #SC conditions, and
#' OR-prefix expansion.
#'
#' @param aggs Named list of species aggregations (Section 1).
#' @param groups Named list of species groups (Section 2). Names must carry the
#'   `"### "`, `"##D "`, `"$$C "` or `"$$N "` prefix.
#' @param membership.formulas Character vector of raw Section 3 formula strings.
#' @param membership.formula.names Character vector of formula name strings in
#'   the format `"<priority><10 chars padding><code> <description>"`.
#' @return A list with elements `aggs`, `groups`, `membership.expressions`,
#'   `group.defs`, `formulas`, and `membership.priority`.
#' @keywords internal
.resy_transform_formulas <- function(aggs, groups, membership.formulas, membership.formula.names) {

  # ---- Validation
  if (any(grepl("[", membership.formulas, fixed = TRUE)))
    stop('Nested bracket "[]" is not implemented, only "()" is allowed.')
  if (any(grepl("{", membership.formulas, fixed = TRUE)))
    stop('Nested bracket "{}" is not implemented, only "()" is allowed.')

  gr <- c(substr(names(groups), 5, nchar(names(groups))), "GE 30")
  if (any(duplicated(gr)))
    stop(paste("Duplicated group name found:", gr[duplicated(gr)]))

  # Extract initial membership expressions from the formula strings
  membership.expressions <- unlist(
    regmatches(membership.formulas,
               gregexpr("(?<=<)[^<>]+(?=>)", membership.formulas, perl = TRUE)),
    use.names = FALSE
  )

  # ---- Step 2A: Complete #T$ right-hand sides (GR operator)
  index3 <- which(grepl("GR[[:space:]]*#T\\$[[:space:]]*$", membership.expressions))
  if (length(index3) > 0) {
    b <- unique(membership.expressions[index3])
    a <- data.table::tstrsplit(b, "GR", fixed = TRUE)
    a[[1]] <- trim(a[[1]])
    for (i in seq_along(b)) {
      index4 <- which(regexpr(b[i], membership.formulas, fixed = TRUE) > 0)
      a[[1]][i] <- gsub("#TC", "#T$", a[[1]][i], fixed = TRUE)
      membership.formulas[index4] <- gsub(
        b[i],
        paste(b[i], substr(a[[1]][i], 4, nchar(a[[1]][i])), sep = ""),
        membership.formulas[index4], fixed = TRUE
      )
    }
    a2 <- data.table::tstrsplit(membership.expressions[index3], "GR", fixed = TRUE)
    a2[[1]] <- trim(a2[[1]])
    a2[[1]] <- gsub("#TC", "#T$", a2[[1]], fixed = TRUE)
    membership.expressions[index3] <- paste(
      membership.expressions[index3],
      substr(a2[[1]], 4, nchar(a2[[1]])),
      sep = ""
    )
  }

  # ---- Step 2B: Complete #T$ right-hand sides (GE operator)
  index3 <- which(grepl("GE[[:space:]]*#T\\$[[:space:]]*$", membership.expressions))
  if (length(index3) > 0) {
    b <- unique(membership.expressions[index3])
    a <- data.table::tstrsplit(b, "GE", fixed = TRUE)
    a[[1]] <- trim(a[[1]])
    for (i in seq_along(b)) {
      index4 <- which(regexpr(b[i], membership.formulas, fixed = TRUE) > 0)
      a[[1]][i] <- gsub("#TC", "#T$", a[[1]][i], fixed = TRUE)
      membership.formulas[index4] <- gsub(
        b[i],
        paste(b[i], substr(a[[1]][i], 4, nchar(a[[1]][i])), sep = ""),
        membership.formulas[index4], fixed = TRUE
      )
    }
    a2 <- data.table::tstrsplit(membership.expressions[index3], "GE", fixed = TRUE)
    a2[[1]] <- trim(a2[[1]])
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
    b[[1]] <- trim(b[[1]])
    b[[2]] <- trim(b[[2]])
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

  # ---- Step 4: Expand repeated-prefix OR syntax
  if (length(membership.expressions) > 0) {
    expanded <- vapply(membership.expressions,
                       .resy_expand_or_membership_expression, character(1))
    changed <- which(expanded != membership.expressions)
    if (length(changed) > 0) {
      for (i in changed) {
        membership.formulas <- gsub(
          paste0("<", membership.expressions[i], ">"),
          paste0("<", gsub(" OR ", "> OR <", expanded[i], fixed = TRUE), ">"),
          membership.formulas, fixed = TRUE
        )
      }
      membership.expressions <- unlist(
        regmatches(membership.formulas,
                   gregexpr("(?<=<)[^<>]+(?=>)", membership.formulas, perl = TRUE)),
        use.names = FALSE
      )
    }
  }

  # ---- Build conditions (group.defs)
  membership.conditions2 <- unlist(strsplit(membership.expressions, " GR "))
  membership.conditions2 <- unlist(strsplit(membership.conditions2, " GE "))
  membership.conditions2 <- unlist(strsplit(membership.conditions2, " EQ "))
  membership.conditions2 <- trim(membership.conditions2)
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
