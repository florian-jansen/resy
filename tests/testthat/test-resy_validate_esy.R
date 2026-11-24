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

test_that(".resy_esy_extract_group_refs: extracts the groups of every group condition code", {
  expr  <- "(<#TC group1> OR <### group2> OR <#SC group3> OR <##D group4> OR <##Q group5> OR <#02 group6>)"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_setequal(refs, paste0("group", 1:6))
})

test_that(".resy_esy_extract_group_refs: header columns are not groups", {
  expr  <- "(<$$C Country EQ Italy> AND <$$N Altitude (m) GR 1500>)"
  expect_length(RESY:::.resy_esy_extract_group_refs(expr), 0L)
})

test_that(".resy_esy_extract_group_refs: names after EXCEPT may be species and are not checked", {
  expr  <- "<Fagus sylvatica GR #TC Trees EXCEPT Fagus sylvatica>"
  expect_equal(RESY:::.resy_esy_extract_group_refs(expr), "Trees")
})

test_that(".resy_esy_extract_group_refs: resolves names as the solver does", {
  # a name with spaces, a set tag, and groups joined by "|" on either side
  expr <- "(<##Q +01 Dry grassland> AND <#TC Trees|#TC Shrubs GR #TC Dwarf-shrubs|#TC Herbs>)"
  expect_setequal(RESY:::.resy_esy_extract_group_refs(expr),
                  c("+01 Dry grassland", "Trees", "Shrubs", "Dwarf-shrubs", "Herbs"))
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

test_that("resy_validate_esy: the shipped EUNIS-ESy file gets no undefined-group warning for header columns, set tags or joined groups", {
  result <- resy_validate_esy(resy_expert_path("EUNIS", "2025-10-03"), verbose = FALSE)
  expect_true(result$ok)
  undefined <- grep("Undefined group", result$warnings, value = TRUE)
  expect_false(any(grepl("Coast_EEA|DEG_LON|Country|Altitude|\\+[0-9]{2}(,|$)|\\|#TC", undefined)))
  expect_lte(length(undefined), 1L)
})

test_that("resy_validate_esy: the same system gives the same report as .json and as .txt", {
  groups <- list(`### G` = list("Sp1"), `XX Bad` = list("Sp2"))
  rules <- list(
    list(priority = "2", code = "A", description = "Fine", expression = "<#TC G GR 10>"),
    list(priority = "2", code = "A", description = "", expression = "<#TC Missing GR 10> AND"),
    list(priority = "3", code = "B", description = "No formula", expression = "")
  )
  json <- tempfile(fileext = ".json")
  txt <- tempfile(fileext = ".txt")
  on.exit(unlink(c(json, txt)))
  jsonlite::write_json(list(metadata = list(scheme = "t", version = "0"), synonyms = list(Sp1 = list()),
                            groups = groups, rules = rules), json, auto_unbox = TRUE)
  writeLines(c(
    "SECTION 1: Species aggregation", "Sp1", "SECTION 1: End",
    "SECTION 2: Species groups", "### G", "     Sp1", "XX Bad", "     Sp2", "SECTION 2: End",
    "SECTION 3: Group definitions",
    unlist(lapply(rules, function(r) c(RESY:::.resy_rule_header(r$priority, r$code, r$description), r$expression, ""))),
    "SECTION 3: End"
  ), txt)
  # A message names the place in the file and the format's word for a formula;
  # everything else is the same text.
  neutral <- function(x) sort(gsub("(rule|line) [0-9]+", "<where>", gsub("expression", "formula", x)))
  a <- resy_validate_esy(json, verbose = FALSE)
  b <- resy_validate_esy(txt, verbose = FALSE)
  expect_equal(neutral(a$errors), neutral(b$errors))
  expect_equal(neutral(a$warnings), neutral(b$warnings))
  expect_equal(a$meta[c("groups_defined", "vegtypes_defined")], b$meta[c("groups_defined", "vegtypes_defined")])
  expect_length(a$errors, 3L)
  expect_length(a$warnings, 3L)
})

test_that("resy_validate_esy: Apennine-test JSON passes validation", {
  path <- system.file(
    "extdata", "classifications", "Apennine-test", "2026-06-27", "expert.json",
    package = "RESY"
  )
  skip_if(!nzchar(path), "Apennine-test JSON not found")
  result <- resy_validate_esy(path, verbose = FALSE)
  expect_true(result$ok)
  expect_length(result$errors, 0L)
})
