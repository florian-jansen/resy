library(testthat)

# ---- Shared helper tests: .resy_esy_balanced_brackets -------------------------

test_that(".resy_esy_balanced_brackets: paired brackets pass", {
  expect_true(RESY:::.resy_esy_balanced_brackets("(<A> AND <B>)"))
  expect_true(RESY:::.resy_esy_balanced_brackets("[(<A> OR <B>) AND <C>]"))
  expect_true(RESY:::.resy_esy_balanced_brackets(""))
  expect_true(RESY:::.resy_esy_balanced_brackets("{}[]()"))
})

test_that(".resy_esy_balanced_brackets: mismatched or unclosed brackets fail", {
  expect_false(RESY:::.resy_esy_balanced_brackets("(<A> AND <B>"))   # unclosed (
  expect_false(RESY:::.resy_esy_balanced_brackets("(<A> AND [<B>))")) # wrong closer
  expect_false(RESY:::.resy_esy_balanced_brackets(")"))               # closer without opener
  expect_false(RESY:::.resy_esy_balanced_brackets("[{]"))             # crossing brackets
})

# ---- Shared helper tests: .resy_esy_extract_group_refs -------------------------

test_that(".resy_esy_extract_group_refs: extracts names from #TC, ###, #SC, ##D, $$C, $$N", {
  expr  <- "(<#TC Beech-forest-trees GR 15> AND <### Nardus-grassland GR 25>)"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Beech-forest-trees")
  expect_contains(refs, "Nardus-grassland")
})

test_that(".resy_esy_extract_group_refs: ignores species names and thresholds", {
  expr  <- "<Nardus stricta GR 10>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_length(refs, 0L)
})

test_that(".resy_esy_extract_group_refs: extracts all prefix types", {
  expr  <- "(<#TC group1> OR <### group2> OR <#SC group3> OR <##D group4> OR <$$C group5> OR <$$N group6>)"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "group1")
  expect_contains(refs, "group2")
  expect_contains(refs, "group3")
  expect_contains(refs, "group4")
  expect_contains(refs, "group5")
  expect_contains(refs, "group6")
})

test_that(".resy_esy_extract_group_refs: handles EXCEPT clauses", {
  expr  <- "<#TC Beech GR 15 EXCEPT Fagus>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Beech")
  expect_contains(refs, "Fagus")
})

# ---- Shared helper tests: .resy_esy_check_formula -------------------------

test_that(".resy_esy_check_formula: valid formulas pass", {
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("<#TC Beech GR 15>", "test", FALSE, warn_env)
  expect_equal(err, NA_character_)
})

test_that(".resy_esy_check_formula: empty formula fails", {
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("", "test", FALSE, warn_env)
  expect_true(grepl("Empty formula", err))
})

test_that(".resy_esy_check_formula: missing membership conditions fails", {
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("Beech GR 15", "test", FALSE, warn_env)
  expect_true(grepl("membership condition", err))
})

test_that(".resy_esy_check_formula: unbalanced brackets fail", {
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("(<#TC Beech GR 15>", "test", FALSE, warn_env)
  expect_true(grepl("Unbalanced bracket", err))
})

test_that(".resy_esy_check_formula: dangling AND/OR/NOT fails", {
  warn_env <- new.env(); warn_env$w <- character()
  err1 <- RESY:::.resy_esy_check_formula("<#TC Beech GR 15> AND", "test", FALSE, warn_env)
  expect_true(grepl("Dangling logical operator", err1))
  
  err2 <- RESY:::.resy_esy_check_formula("OR <#TC Beech GR 15>", "test", FALSE, warn_env)
  expect_true(grepl("Dangling logical operator", err2))
})

test_that(".resy_esy_check_formula: legacy UP operator triggers warning", {
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("<#TC Beech UP 15>", "test", FALSE, warn_env)
  expect_equal(err, NA_character_)
  expect_true(any(grepl("UP", warn_env$w)))
})

test_that(".resy_esy_check_formula: legacy UP operator is error in strict mode", {
  warn_env <- new.env(); warn_env$w <- character()
  err <- RESY:::.resy_esy_check_formula("<#TC Beech UP 15>", "test", TRUE, warn_env)
  expect_true(grepl("UP", err))
})

# ---- Shared helper tests: .resy_esy_make_parseable -------------------------

test_that(".resy_esy_make_parseable: converts logical keywords", {
  result <- RESY:::.resy_esy_make_parseable("<#TC A> AND <#TC B> OR <#TC C>")
  expect_true(grepl("&", result))
  expect_true(grepl("|", result))
})

test_that(".resy_esy_make_parseable: replaces conditions with tokens", {
  result <- RESY:::.resy_esy_make_parseable("<#TC A GR 10> AND <#TC B GR 5>")
  expect_false(grepl("<", result))
  expect_false(grepl(">", result))
  expect_true(grepl("col", result))
})

# ---- Valid real files -------

test_that("resy_validate_esy: Apennine-test JSON passes validation", {
  path <- system.file(
    "extdata/classifications/Apennine-test/2026-06-27/expert.json",
    package = "RESY"
  )
  skip_if(!nzchar(path), "Apennine-test JSON not found")
  result <- resy_validate_esy(path, verbose = FALSE)
  expect_true(result$ok)
  expect_length(result$errors, 0L)
  expect_equal(result$meta$vegtypes_defined, 5L)
})

test_that("resy_validate_esy: EUNIS JSON passes validation", {
  path <- system.file(
    "extdata/classifications/EUNIS/2025-10-03/expert.json",
    package = "RESY"
  )
  skip_if(!nzchar(path), "EUNIS JSON not found")
  result <- resy_validate_esy(path, verbose = FALSE)
  expect_true(result$ok)
  expect_length(result$errors, 0L)
})
