# Validator for ESy expert files in TXT format

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
