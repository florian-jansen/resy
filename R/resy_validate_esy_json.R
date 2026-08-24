# Validator for ESy expert files in JSON format

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
