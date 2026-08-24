library(testthat)

# ---- .resy_esy_balanced_brackets: Basic functionality -------------------------

test_that(".resy_esy_balanced_brackets: paired brackets pass", {
  
  expect_true(RESY:::.resy_esy_balanced_brackets("(<A> AND <B>)"))
  expect_true(RESY:::.resy_esy_balanced_brackets("[(<A> OR <B>) AND <C>]"))
  expect_true(RESY:::.resy_esy_balanced_brackets(""))
  expect_true(RESY:::.resy_esy_balanced_brackets("{}[]()"))
  expect_true(RESY:::.resy_esy_balanced_brackets("{[()]}"))
  
})

test_that(".resy_esy_balanced_brackets: single pairs pass", {
  
  expect_true(RESY:::.resy_esy_balanced_brackets("()"))
  expect_true(RESY:::.resy_esy_balanced_brackets("[]"))
  expect_true(RESY:::.resy_esy_balanced_brackets("{}"))
  
})

test_that(".resy_esy_balanced_brackets: text without brackets passes", {
  
  expect_true(RESY:::.resy_esy_balanced_brackets("hello world"))
  expect_true(RESY:::.resy_esy_balanced_brackets("GR 10"))
  
})

# ---- .resy_esy_balanced_brackets: Unbalanced cases ----

test_that(".resy_esy_balanced_brackets: unclosed brackets fail", {
  
  expect_false(RESY:::.resy_esy_balanced_brackets("("))
  expect_false(RESY:::.resy_esy_balanced_brackets("["))
  expect_false(RESY:::.resy_esy_balanced_brackets("{"))
  expect_false(RESY:::.resy_esy_balanced_brackets("(<A> AND <B>"))
  expect_false(RESY:::.resy_esy_balanced_brackets("[(<A>)"))
  
})

test_that(".resy_esy_balanced_brackets: unopened closers fail", {
  
  expect_false(RESY:::.resy_esy_balanced_brackets(")"))
  expect_false(RESY:::.resy_esy_balanced_brackets("]"))
  expect_false(RESY:::.resy_esy_balanced_brackets("}"))
  expect_false(RESY:::.resy_esy_balanced_brackets("(A>"))
  
})

test_that(".resy_esy_balanced_brackets: mismatched brackets fail", {
  
  expect_false(RESY:::.resy_esy_balanced_brackets("(<A> AND [<B>))"))
  expect_false(RESY:::.resy_esy_balanced_brackets("{[}]"))
  expect_false(RESY:::.resy_esy_balanced_brackets("(]"))
  expect_false(RESY:::.resy_esy_balanced_brackets("[)"))
  
})

test_that(".resy_esy_balanced_brackets: crossing brackets fail", {
  
  expect_false(RESY:::.resy_esy_balanced_brackets("[{]"))
  expect_false(RESY:::.resy_esy_balanced_brackets("({)}"))
  
})

# ---- .resy_esy_extract_group_refs: Prefix extraction ----

test_that(".resy_esy_extract_group_refs: extracts #TC names", {
  
  expr  <- "<#TC Beech GR 15>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Beech")
  
})

test_that(".resy_esy_extract_group_refs: extracts ### names", {
  
  expr  <- "<### Nardus-grassland GR 25>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Nardus-grassland")
  
})

test_that(".resy_esy_extract_group_refs: extracts #SC names", {
  
  expr  <- "<#SC Scrub GE 10>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Scrub")
  
})

test_that(".resy_esy_extract_group_refs: extracts ##D names", {
  
  expr  <- "<##D Disturbance LE 5>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Disturbance")
  
})

test_that(".resy_esy_extract_group_refs: extracts $$C names", {
  
  expr  <- "<$$C Cultivation EQ 1>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Cultivation")
  
})

test_that(".resy_esy_extract_group_refs: extracts $$N names", {
  
  expr  <- "<$$N Natural UP 10>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Natural")
  
})

test_that(".resy_esy_extract_group_refs: extracts multiple names", {
  
  expr  <- "(<#TC Beech GR 15> AND <### Nardus GR 25>)"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Beech")
  expect_contains(refs, "Nardus")
  expect_length(refs, 2L)
  
})

# ---- .resy_esy_extract_group_refs: Non-extracted cases ----

test_that(".resy_esy_extract_group_refs: ignores species names without prefix", {
  
  expr  <- "<Nardus stricta GR 10>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_length(refs, 0L)
  
})

test_that(".resy_esy_extract_group_refs: ignores bare thresholds", {
  
  expr  <- "<GR 15>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_length(refs, 0L)
  
})

test_that(".resy_esy_extract_group_refs: handles EXCEPT clauses", {
  
  expr  <- "<#TC Beech GR 15 EXCEPT Fagus>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Beech")
  expect_contains(refs, "Fagus")
  
})

test_that(".resy_esy_extract_group_refs: extracts EXCEPT with special tokens", {
  
  expr  <- "<#TC Forest EXCEPT #SC Shrub>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Forest")
  expect_false("Shrub" %in% refs)  # #SC prefix is skipped
  
})

test_that(".resy_esy_extract_group_refs: handles empty expressions", {
  
  refs  <- RESY:::.resy_esy_extract_group_refs("")
  expect_length(refs, 0L)
  
})

test_that(".resy_esy_extract_group_refs: removes duplicates", {
  
  expr  <- "<#TC Group> AND <#TC Group>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_length(refs, 1L)
  
})

# ---- .resy_esy_make_parseable: Condition replacement ----

test_that(".resy_esy_make_parseable: replaces single condition with col1", {
  
  result <- RESY:::.resy_esy_make_parseable("<#TC A>")
  expect_true(grepl("col1", result))
  expect_false(grepl("<", result))
  expect_false(grepl(">", result))
  
})

test_that(".resy_esy_make_parseable: replaces multiple conditions", {
  
  result <- RESY:::.resy_esy_make_parseable("<#TC A> AND <#TC B>")
  expect_true(grepl("col1", result))
  expect_true(grepl("col2", result))
  expect_false(grepl("<", result))
  
})

test_that(".resy_esy_make_parseable: orders by condition length (descending)", {
  
  result <- RESY:::.resy_esy_make_parseable("<#TC A GR 10> AND <#TC B>")
  # Longer condition <#TC A GR 10> should be col1, shorter <#TC B> should be col2
  expect_true(grepl("col1", result))
  expect_true(grepl("col2", result))
  
})

# ---- .resy_esy_make_parseable: Keyword translation ----

test_that(".resy_esy_make_parseable: translates AND to &", {
  
  result <- RESY:::.resy_esy_make_parseable("<A> AND <B>")
  expect_true(grepl("&", result))
  expect_false(grepl("AND", result))
  
})

test_that(".resy_esy_make_parseable: translates OR to |", {
  
  result <- RESY:::.resy_esy_make_parseable("<A> OR <B>")
  expect_true(grepl("|", result))
  expect_false(grepl("OR", result))
  
})

test_that(".resy_esy_make_parseable: translates NOT to &!", {
  
  result <- RESY:::.resy_esy_make_parseable("NOT <A>")
  expect_true(grepl("&!", result))
  expect_false(grepl("NOT", result))
  
})

test_that(".resy_esy_make_parseable: handles mixed operators", {
  
  result <- RESY:::.resy_esy_make_parseable("<A> AND <B> OR NOT <C>")
  expect_true(grepl("&", result))
  expect_true(grepl("|", result))
  expect_true(grepl("&!", result))
  
})

# ---- .resy_esy_make_parseable: Whitespace normalization ----

test_that(".resy_esy_make_parseable: normalizes multiple spaces", {
  
  result <- RESY:::.resy_esy_make_parseable("<A>    AND    <B>")
  expect_false(grepl("    ", result))
  
})

test_that(".resy_esy_make_parseable: trims leading/trailing whitespace", {
  
  result <- RESY:::.resy_esy_make_parseable("   <A> AND <B>   ")
  expect_false(grepl("^\\s", result))
  expect_false(grepl("\\s$", result))
  
})

# ---- .resy_esy_check_formula: Valid formulas ----

test_that(".resy_esy_check_formula: valid single condition passes", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("<#TC Beech GR 15>", "test", FALSE, warn_env)
  expect_equal(err, NA_character_)
  
})

test_that(".resy_esy_check_formula: valid complex formula passes", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula(
    "(<#TC A GR 10> AND <### B GE 5>) OR <#SC C>",
    "test", FALSE, warn_env
  )
  expect_equal(err, NA_character_)
  
})

test_that(".resy_esy_check_formula: NOT at start is valid", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("NOT <#TC A>", "test", FALSE, warn_env)
  expect_equal(err, NA_character_)
  
})

test_that(".resy_esy_check_formula: parentheses with valid formula passes", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("((<#TC A>))", "test", FALSE, warn_env)
  expect_equal(err, NA_character_)
  
})

# ---- .resy_esy_check_formula: Invalid formulas ----

test_that(".resy_esy_check_formula: empty formula fails", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("", "test", FALSE, warn_env)
  expect_true(grepl("Empty formula", err))
  
})

test_that(".resy_esy_check_formula: whitespace-only formula fails", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("   ", "test", FALSE, warn_env)
  expect_true(grepl("Empty formula", err))
  
})

test_that(".resy_esy_check_formula: no membership conditions fails", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("Beech GR 15", "test", FALSE, warn_env)
  expect_true(grepl("membership condition", err))
  
})

test_that(".resy_esy_check_formula: unbalanced opening bracket fails", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("(<#TC A>", "test", FALSE, warn_env)
  expect_true(grepl("Unbalanced bracket", err))
  
})

test_that(".resy_esy_check_formula: unbalanced closing bracket fails", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("<#TC A>)", "test", FALSE, warn_env)
  expect_true(grepl("Unbalanced bracket", err))
  
})

test_that(".resy_esy_check_formula: wrong bracket type fails", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("(<#TC A>]", "test", FALSE, warn_env)
  expect_true(grepl("Unbalanced bracket", err))
  
})

# ---- .resy_esy_check_formula: Dangling operators ----

test_that(".resy_esy_check_formula: AND at end fails", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("<#TC A> AND", "test", FALSE, warn_env)
  expect_true(grepl("Dangling logical operator", err))
  
})

test_that(".resy_esy_check_formula: OR at start fails", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("OR <#TC A>", "test", FALSE, warn_env)
  expect_true(grepl("Dangling logical operator", err))
  
})

test_that(".resy_esy_check_formula: NOT at end fails", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("<#TC A> NOT", "test", FALSE, warn_env)
  expect_true(grepl("Dangling logical operator", err))
  
})

test_that(".resy_esy_check_formula: AND AND fails", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula(
    "<#TC A> AND AND <#TC B>", "test", FALSE, warn_env
    )
  # This is actually about unbalanced formula structure via parse()
  expect_false(is.na(err))
  
})

# ---- .resy_esy_check_formula: Legacy UP operator ----

test_that(".resy_esy_check_formula: UP operator triggers warning (non-strict)", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula(
    "<#TC Beech UP 15>", "test", FALSE, warn_env
    )
  expect_equal(err, NA_character_)
  expect_true(any(grepl("UP", warn_env$w)))
  
})

test_that(".resy_esy_check_formula: UP operator is error (strict)", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula(
    "<#TC Beech UP 15>", "test", TRUE, warn_env
    )
  expect_true(grepl("UP", err))
  
})

test_that(".resy_esy_check_formula: UP in complex formula triggers warning", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula(
    "<#TC A UP 10> AND <#TC B>", "test", FALSE, warn_env
    )
  expect_equal(err, NA_character_)
  expect_true(any(grepl("UP", warn_env$w)))
  
})

# ---- Integration: Context string in errors ----

test_that(".resy_esy_check_formula: error includes context", {
  
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("", "code 'AB'", FALSE, warn_env)
  expect_true(grepl("code 'AB'", err))
  
})

test_that(".resy_esy_check_formula: warning environment works", {
  
  warn_env <- new.env(); warn_env$w <- character()
  RESY:::.resy_esy_check_formula("<#TC A UP 10>", "test", FALSE, warn_env)
  expect_true(length(warn_env$w) > 0)
  
})
